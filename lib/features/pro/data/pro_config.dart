import 'package:cardfi/features/pro/domain/pro_models.dart';

abstract final class ProConfig {
  static const referralProgramEnabled = bool.fromEnvironment(
    'ENABLE_PRO_REFERRALS',
    defaultValue: true,
  );

  static const billingEnabled = bool.fromEnvironment(
    'ENABLE_PRO_BILLING',
    defaultValue: false,
  );

  static const monthlyProductId = String.fromEnvironment(
    'PRO_MONTHLY_PRODUCT_ID',
    defaultValue: 'cn.lengziyu.cardapp.pro.monthly',
  );

  static const yearlyProductId = String.fromEnvironment(
    'PRO_YEARLY_PRODUCT_ID',
    defaultValue: 'cn.lengziyu.cardapp.pro.yearly',
  );

  /// The lifetime storefront is compiled into a release only after both store
  /// products and the server verifier have passed preflight. Keeping this off
  /// preserves the existing monthly/yearly production experience.
  static const lifetimeEnabled = bool.fromEnvironment(
    'ENABLE_PRO_LIFETIME',
    defaultValue: false,
  );

  static const lifetimeProductId = String.fromEnvironment(
    'PRO_LIFETIME_PRODUCT_ID',
    defaultValue: 'cn.lengziyu.cardapp.pro.lifetime',
  );

  static const verifyPath = String.fromEnvironment(
    'PRO_VERIFY_PATH',
    defaultValue: '/api/pro/verify',
  );

  static const configurationPath = String.fromEnvironment(
    'PRO_CONFIG_PATH',
    defaultValue: '/api/pro/config',
  );

  static const entitlementPath = String.fromEnvironment(
    'PRO_ENTITLEMENT_PATH',
    defaultValue: '/api/pro/entitlement',
  );

  static const workspacePath = String.fromEnvironment(
    'PRO_WORKSPACE_PATH',
    defaultValue: '/api/pro/workspace',
  );

  static const billAnalysisPath = String.fromEnvironment(
    'PRO_BILL_ANALYSIS_PATH',
    defaultValue: '/api/pro/bill-analysis',
  );

  static const billAnalysisV2Path = String.fromEnvironment(
    'PRO_BILL_ANALYSIS_V2_PATH',
    defaultValue: '/api/pro/bill-analysis-v2',
  );

  /// Client-side half of the bill-history rollout gate. The server keeps an
  /// independent switch and remains authoritative.
  static const billHistoryEnabled = bool.fromEnvironment(
    'ENABLE_BILL_HISTORY',
    defaultValue: true,
  );

  static const billRecordsPath = String.fromEnvironment(
    'PRO_BILL_RECORDS_PATH',
    defaultValue: '/api/pro/bill-records',
  );

  /// Default-off visual rollout for the native receipt-printer result reveal.
  /// Recognition, persistence, and the legacy result cards remain unchanged.
  static const billReceiptPrinterEnabled = bool.fromEnvironment(
    'ENABLE_BILL_RECEIPT_PRINTER',
    defaultValue: false,
  );

  static const applicationAssistantPath = String.fromEnvironment(
    'PRO_APPLICATION_ASSISTANT_PATH',
    defaultValue: '/api/pro/application-assistant',
  );

  static const manageSubscriptionUrl = String.fromEnvironment(
    'PRO_MANAGE_SUBSCRIPTION_URL',
    defaultValue: '',
  );

  static const termsUrl = String.fromEnvironment(
    'PRO_TERMS_URL',
    defaultValue: '',
  );

  static const privacyUrl = String.fromEnvironment(
    'PRO_PRIVACY_URL',
    defaultValue: '',
  );

  static const showDiagnostics = bool.fromEnvironment(
    'SHOW_PRO_DIAGNOSTICS',
    defaultValue: false,
  );

  static const offers = <ProOffer>[
    ProOffer(
      plan: ProPlan.monthly,
      productId: monthlyProductId,
      title: '月度 Pro',
      periodLabel: '按月自动续费',
    ),
    ProOffer(
      plan: ProPlan.yearly,
      productId: yearlyProductId,
      title: '年度 Pro',
      periodLabel: '按年自动续费',
    ),
    if (lifetimeEnabled)
      ProOffer(
        plan: ProPlan.lifetime,
        productId: lifetimeProductId,
        title: '永久 Pro',
        periodLabel: '一次购买，永久解锁',
      ),
  ];
}
