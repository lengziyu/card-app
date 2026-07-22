import 'package:card_app/features/pro/domain/pro_models.dart';

abstract final class ProConfig {
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
  ];
}
