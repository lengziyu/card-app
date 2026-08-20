import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/domain/pro_models.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class ProVerificationRepository {
  const ProVerificationRepository(this._client);

  final ApiClient _client;

  Future<ProServiceConfiguration> loadConfiguration() async {
    final response = jsonObject(
      await _client.get(ProConfig.configurationPath),
      label: 'Pro 配置响应',
    );
    final products = response['products'];
    final stores = response['stores'];
    return ProServiceConfiguration(
      enabled: response['enabled'] == true,
      monthlyProductId: products is Map<String, dynamic>
          ? products['monthly']?.toString()
          : null,
      yearlyProductId: products is Map<String, dynamic>
          ? products['yearly']?.toString()
          : null,
      appStoreEnabled:
          stores is Map<String, dynamic> && stores['appStore'] == true,
      googlePlayEnabled:
          stores is Map<String, dynamic> && stores['googlePlay'] == true,
    );
  }

  Future<ProVerificationResult> verify({
    required PurchaseDetails purchase,
    required String accessToken,
  }) async {
    final response = jsonObject(
      await _client.post(
        ProConfig.verifyPath,
        headers: {'authorization': 'Bearer $accessToken'},
        body: {
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
          'source': purchase.verificationData.source,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
        },
      ),
      label: 'Pro 验单响应',
    );
    return ProVerificationResult(
      valid: response['valid'] == true,
      entitlement: _entitlementFrom(response['entitlement']),
    );
  }

  Future<ProEntitlement> loadEntitlement({required String accessToken}) async {
    final response = jsonObject(
      await _client.get(
        ProConfig.entitlementPath,
        headers: {'authorization': 'Bearer $accessToken'},
      ),
      label: 'Pro 权益响应',
    );
    return _entitlementFrom(response['entitlement'] ?? response);
  }

  ProEntitlement _entitlementFrom(Object? source) {
    if (source is! Map<String, dynamic>) {
      return const ProEntitlement.free();
    }
    final status = switch (source['status']?.toString()) {
      'active' => ProEntitlementStatus.active,
      'pending' => ProEntitlementStatus.pending,
      'gracePeriod' || 'grace_period' => ProEntitlementStatus.gracePeriod,
      'billingRetry' || 'billing_retry' => ProEntitlementStatus.billingRetry,
      'expired' => ProEntitlementStatus.expired,
      'revoked' => ProEntitlementStatus.revoked,
      'error' => ProEntitlementStatus.error,
      _ => ProEntitlementStatus.free,
    };
    final plan = switch (source['plan']?.toString()) {
      'monthly' => ProPlan.monthly,
      'yearly' => ProPlan.yearly,
      _ => null,
    };
    final expiresAt = DateTime.tryParse(source['expiresAt']?.toString() ?? '');
    final explicitAccess = source['accessGranted'];
    final withinAccessWindow =
        expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc());
    final inferredAccess =
        (status == ProEntitlementStatus.active ||
            status == ProEntitlementStatus.gracePeriod ||
            status == ProEntitlementStatus.billingRetry) &&
        withinAccessWindow;
    return ProEntitlement(
      status: status,
      plan: plan,
      expiresAt: expiresAt,
      autoRenewing: source['autoRenewing'] == true,
      accessGranted: explicitAccess is bool
          ? explicitAccess && withinAccessWindow
          : inferredAccess,
    );
  }
}
