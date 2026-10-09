enum ToolKind {
  bin('卡 BIN 查询', '按卡名或 BIN 查看发卡机构与地区', '/api/runtime/admin-cards'),
  requirements('U 卡对比', '对比开卡条件、费率与支付支持', '/api/u-card-opening-requirements'),
  noKyc('无需 KYC 卡', '查看免认证卡片、适用范围与风险', '/api/no-kyc-cards'),
  addressProof('地址证明', '查看地址证明指南与适用范围', '/api/address-proofs'),
  internationalSim('境外手机卡', '查看申请、激活与保号条件', '/api/international-sims'),
  sms('接码平台', '查看号码服务、费用与隐私方式', '/api/sms-platforms');

  const ToolKind(this.title, this.description, this.path);
  final String title;
  final String description;
  final String path;
  bool get hasAvailability =>
      this == noKyc || this == internationalSim || this == sms;
}

class ToolAvailability {
  const ToolAvailability({
    required this.enabled,
    this.count = 0,
    this.failed = false,
  });
  final bool enabled;
  final int count;
  final bool failed;
}

/// Public H5 records retain their original field names. Only explicitly selected
/// fields are rendered; account, invitation and administration fields are unused.
class ToolRecord {
  ToolRecord(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  final Map<String, dynamic> data;
  String value(String key) => data[key]?.toString().trim() ?? '';
  String get id => value('id');
  String localized(String key, {required bool chinese}) =>
      value('$key${chinese ? 'Zh' : 'En'}').isNotEmpty
      ? value('$key${chinese ? 'Zh' : 'En'}')
      : value('${key}Zh').isNotEmpty
      ? value('${key}Zh')
      : value('${key}En');
  Map<String, dynamic> object(String key) =>
      data[key] is Map ? Map<String, dynamic>.from(data[key] as Map) : const {};
  List<String> strings(String key) => data[key] is List
      ? (data[key] as List).map((item) => item.toString()).toList()
      : const [];
  List<ToolRecord> records(String key) => data[key] is List
      ? (data[key] as List)
            .whereType<Map>()
            .map((item) => ToolRecord(Map<String, dynamic>.from(item)))
            .toList()
      : const [];
  String title(ToolKind kind, {required bool chinese}) => switch (kind) {
    ToolKind.bin || ToolKind.sms => value('name'),
    ToolKind.requirements => localized('displayName', chinese: chinese),
    ToolKind.noKyc => localized('name', chinese: chinese),
    ToolKind.addressProof => value('title'),
    ToolKind.internationalSim =>
      value('productName').isNotEmpty
          ? value('productName')
          : value('provider'),
  };
  String summary(ToolKind kind, {required bool chinese}) => switch (kind) {
    ToolKind.bin => value('issuer'),
    ToolKind.requirements => _requirementsSummary(chinese),
    ToolKind.noKyc => localized('description', chinese: chinese),
    ToolKind.addressProof => value('summary'),
    _ => localized('summary', chinese: chinese),
  };

  String _requirementsSummary(bool chinese) {
    final copy = localized('summary', chinese: chinese);
    // Free-form H5 summaries may contain rewards. This endpoint does not carry
    // the App's separately reviewed invitation-display switches.
    if (!RegExp(
      r'邀请码|推荐码|邀请奖励|referral|invite|reward',
      caseSensitive: false,
    ).hasMatch(copy)) {
      return copy;
    }
    final labels = <String, String>{
      'idCard': chinese ? '身份证' : 'National ID',
      'passport': chinese ? '护照' : 'Passport',
      'overseasAddressProof': chinese ? '海外地址证明' : 'Overseas proof of address',
      'overseasPhone': chinese ? '海外手机号' : 'Overseas phone number',
    };
    return labels.entries
        .where((entry) => object('requirements')[entry.key] == 'required')
        .map((entry) => entry.value)
        .join(' · ');
  }
}

class ToolCollection {
  const ToolCollection({
    required this.items,
    this.updatedAt = '',
    this.sourceName = '',
    this.sourceUrl = '',
    this.sourceAvailable = true,
  });
  final List<ToolRecord> items;
  final String updatedAt;
  final String sourceName;
  final String sourceUrl;
  final bool sourceAvailable;
}

/// Tool APIs do not expose the independently reviewed invitation switches used
/// by card details. Never surface their referral fields or tracked URLs.
Uri? publicToolUri(String value, {Uri? base}) {
  final raw = Uri.tryParse(value.trim());
  if (raw == null || value.trim().isEmpty) return null;
  final uri = base?.resolveUri(raw) ?? raw;
  if (!{'https', 'http'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final query = <String, List<String>>{};
  for (final entry in uri.queryParametersAll.entries) {
    if (RegExp(
      r'^(utm_|ref|referrer|referral|affiliate|aff|invite|tracking|promo)',
      caseSensitive: false,
    ).hasMatch(entry.key)) {
      continue;
    }
    query[entry.key] = entry.value;
  }
  if (!uri.hasQuery) return uri;
  if (query.isEmpty) {
    return Uri.parse(uri.toString().replaceFirst(RegExp(r'\?[^#]*'), ''));
  }
  return uri.replace(queryParameters: query);
}

String cleanToolText(String text) => text.replaceAllMapped(
  RegExp(r'https?://[^\s<>"\)\(\[\]]+'),
  (match) => publicToolUri(match[0]!)?.toString() ?? '',
);
