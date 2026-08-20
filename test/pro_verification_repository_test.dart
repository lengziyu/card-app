import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/pro_verification_repository.dart';
import 'package:cardfi/features/pro/domain/pro_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  test('loads platform readiness and product ids before purchase', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/pro/config');
        return _jsonResponse({
          'enabled': true,
          'stores': {'appStore': true, 'googlePlay': false},
          'products': {
            'monthly': 'cn.lengziyu.cardapp.pro.monthly',
            'yearly': 'cn.lengziyu.cardapp.pro.yearly',
          },
        });
      }),
    );

    final configuration = await ProVerificationRepository(
      client,
    ).loadConfiguration();

    expect(configuration.enabled, isTrue);
    expect(configuration.appStoreEnabled, isTrue);
    expect(configuration.googlePlayEnabled, isFalse);
    expect(
      configuration.canLoadEntitlements(
        monthly: 'cn.lengziyu.cardapp.pro.monthly',
        yearly: 'cn.lengziyu.cardapp.pro.yearly',
      ),
      isTrue,
    );
    expect(
      configuration.matchesProducts(
        monthly: 'cn.lengziyu.cardapp.pro.monthly',
        yearly: 'cn.lengziyu.cardapp.pro.yearly',
      ),
      isTrue,
    );
    client.close();
  });

  test(
    'sends the opaque store proof to the authenticated verification API',
    () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'valid': true,
            'entitlement': {
              'status': 'grace_period',
              'plan': 'yearly',
              'expiresAt': '2027-07-20T00:00:00Z',
              'autoRenewing': true,
              'accessGranted': true,
            },
          });
        }),
      );
      final purchase = PurchaseDetails(
        purchaseID: 'transaction-1',
        productID: 'cn.lengziyu.cardapp.pro.yearly',
        verificationData: PurchaseVerificationData(
          localVerificationData: 'must-not-be-sent',
          serverVerificationData: 'opaque-proof',
          source: 'app_store',
        ),
        transactionDate: '1784486400000',
        status: PurchaseStatus.purchased,
      );

      final result = await ProVerificationRepository(
        client,
      ).verify(purchase: purchase, accessToken: 'short-lived-token');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/pro/verify');
      expect(captured.headers['authorization'], 'Bearer short-lived-token');
      expect(body['serverVerificationData'], 'opaque-proof');
      expect(body['localVerificationData'], isNull);
      expect(result.valid, isTrue);
      expect(result.entitlement.status, ProEntitlementStatus.gracePeriod);
      expect(result.entitlement.isActive, isTrue);
      expect(result.entitlement.plan, ProPlan.yearly);
      client.close();
    },
  );

  test('loads revoked entitlement without granting Pro access', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/pro/entitlement');
        expect(request.headers['authorization'], 'Bearer account-token');
        return _jsonResponse({
          'entitlement': {
            'status': 'revoked',
            'plan': 'monthly',
            'accessGranted': false,
          },
        });
      }),
    );

    final entitlement = await ProVerificationRepository(
      client,
    ).loadEntitlement(accessToken: 'account-token');

    expect(entitlement.status, ProEntitlementStatus.revoked);
    expect(entitlement.isActive, isFalse);
    expect(entitlement.plan, ProPlan.monthly);
    client.close();
  });

  test('never grants an entitlement past its server expiry', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => _jsonResponse({
          'entitlement': {
            'status': 'active',
            'plan': 'yearly',
            'expiresAt': '2020-01-01T00:00:00Z',
            'accessGranted': true,
          },
        }),
      ),
    );

    final entitlement = await ProVerificationRepository(
      client,
    ).loadEntitlement(accessToken: 'account-token');

    expect(entitlement.status, ProEntitlementStatus.active);
    expect(entitlement.isActive, isFalse);
    client.close();
  });
}

http.Response _jsonResponse(Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
