enum ProPlan { monthly, yearly }

extension ProPlanCopy on ProPlan {
  String get label => switch (this) {
    ProPlan.monthly => '月度 Pro',
    ProPlan.yearly => '年度 Pro',
  };

  String get periodLabel => switch (this) {
    ProPlan.monthly => '按月自动续费',
    ProPlan.yearly => '按年自动续费',
  };
}

enum ProEntitlementStatus {
  free,
  pending,
  active,
  gracePeriod,
  billingRetry,
  expired,
  revoked,
  error,
}

extension ProEntitlementStatusCopy on ProEntitlementStatus {
  String get label => switch (this) {
    ProEntitlementStatus.free => '未开通',
    ProEntitlementStatus.pending => '等待确认',
    ProEntitlementStatus.active => '已生效',
    ProEntitlementStatus.gracePeriod => '宽限期',
    ProEntitlementStatus.billingRetry => '扣款重试中',
    ProEntitlementStatus.expired => '已到期',
    ProEntitlementStatus.revoked => '已撤销',
    ProEntitlementStatus.error => '状态异常',
  };
}

class ProEntitlement {
  const ProEntitlement({
    required this.status,
    this.plan,
    this.expiresAt,
    this.autoRenewing = false,
    bool? accessGranted,
  }) : accessGranted =
           accessGranted ??
           (status == ProEntitlementStatus.active ||
               status == ProEntitlementStatus.gracePeriod ||
               status == ProEntitlementStatus.billingRetry);

  const ProEntitlement.free()
    : status = ProEntitlementStatus.free,
      plan = null,
      expiresAt = null,
      autoRenewing = false,
      accessGranted = false;

  final ProEntitlementStatus status;
  final ProPlan? plan;
  final DateTime? expiresAt;
  final bool autoRenewing;
  final bool accessGranted;

  bool get isActive => accessGranted;
}

class ProOffer {
  const ProOffer({
    required this.plan,
    required this.productId,
    required this.title,
    required this.periodLabel,
    this.price,
    this.currencyCode,
    this.available = false,
  });

  final ProPlan plan;
  final String productId;
  final String title;
  final String periodLabel;
  final String? price;
  final String? currencyCode;
  final bool available;

  ProOffer copyWith({
    String? title,
    String? periodLabel,
    String? price,
    String? currencyCode,
    bool? available,
  }) => ProOffer(
    plan: plan,
    productId: productId,
    title: title ?? this.title,
    periodLabel: periodLabel ?? this.periodLabel,
    price: price ?? this.price,
    currencyCode: currencyCode ?? this.currencyCode,
    available: available ?? this.available,
  );
}

class ProVerificationResult {
  const ProVerificationResult({required this.valid, required this.entitlement});

  final bool valid;
  final ProEntitlement entitlement;
}

class ProServiceConfiguration {
  const ProServiceConfiguration({
    required this.enabled,
    required this.monthlyProductId,
    required this.yearlyProductId,
    required this.appStoreEnabled,
    required this.googlePlayEnabled,
  });

  const ProServiceConfiguration.disabled()
    : enabled = false,
      monthlyProductId = null,
      yearlyProductId = null,
      appStoreEnabled = false,
      googlePlayEnabled = false;

  final bool enabled;
  final String? monthlyProductId;
  final String? yearlyProductId;
  final bool appStoreEnabled;
  final bool googlePlayEnabled;

  bool matchesProducts({required String monthly, required String yearly}) =>
      monthlyProductId == monthly && yearlyProductId == yearly;

  bool canLoadEntitlements({required String monthly, required String yearly}) =>
      enabled && matchesProducts(monthly: monthly, yearly: yearly);
}
