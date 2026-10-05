import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/data/local_card_details.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The public client that consumes a card detail.
///
/// Invite codes and invite links are sensitive display fields. The API uses
/// this value to apply the separately reviewed Android, iOS, and H5 switches
/// before it returns either field.
enum PublicContentPlatform {
  android('android'),
  ios('ios'),
  h5('h5');

  const PublicContentPlatform(this.apiValue);

  final String apiValue;

  static PublicContentPlatform get current {
    if (kIsWeb) return h5;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => h5,
    };
  }
}

class RemoteCardDetailRepository {
  RemoteCardDetailRepository(
    this._apiClient, {
    PublicContentPlatform? contentPlatform,
  }) : _contentPlatform = contentPlatform ?? PublicContentPlatform.current;

  final ApiClient _apiClient;
  final PublicContentPlatform _contentPlatform;
  final Map<String, Future<CardDetail>> _cache = {};

  Future<CardDetail> detailFor(
    CardSummary card, {
    bool force = false,
    Locale? locale,
  }) {
    final cacheKey =
        '${card.id}:${locale?.languageCode ?? 'zh'}:${_contentPlatform.apiValue}';
    if (force) _cache.remove(cacheKey);
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final request = _load(card, locale: locale);
    _cache[cacheKey] = request;
    request.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_cache[cacheKey], request)) _cache.remove(cacheKey);
      },
    );
    return request;
  }

  Future<CardDetail> _load(CardSummary card, {Locale? locale}) async {
    if (card.isGlobalAccount) {
      try {
        return await _loadGlobalAccount(card, locale: locale);
      } catch (_) {
        // Curated global-account records are bundled with the app while the
        // independent public endpoint is populated incrementally.
        return const LocalCardDetailRepository().detailFor(card);
      }
    }
    final response = jsonObject(
      await _apiClient.get(
        '/api/cards/${Uri.encodeComponent(card.id)}',
        query: {
          'platform': _contentPlatform.apiValue,
          if (locale != null) 'locale': locale.toLanguageTag(),
        },
        headers: locale == null
            ? null
            : {'accept-language': locale.toLanguageTag()},
      ),
    );
    final detail = jsonObject(response['detail'], label: '卡片详情');
    final kyc = detail['kycFact'] is Map<String, dynamic>
        ? detail['kycFact'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final payment = detail['paymentSupport'] is Map<String, dynamic>
        ? detail['paymentSupport'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final chinaKyc = detail['chinaKyc'] is Map<String, dynamic>
        ? detail['chinaKyc'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final openingRequirement = detail['openingRequirement'] is Map
        ? Map<String, dynamic>.from(detail['openingRequirement'] as Map)
        : const <String, dynamic>{};
    final todeyFacts = detail['todeyFacts'] is Map<String, dynamic>
        ? detail['todeyFacts'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final content = _contentFromBenefits(
      jsonList(detail['benefits'] ?? const [], label: '卡片权益'),
      locale: locale,
    );
    final fees = _normalizedFees(
      _feesWithTodeyFacts(
        jsonList(detail['fees'] ?? const [], label: '卡片费用'),
        todeyFacts,
      ),
      locale: locale,
    );
    final note = _localizedText(detail, 'note', locale);
    return CardDetail(
      cardId: card.id,
      tags: _localizedList(detail, 'tags', locale)
          .map((value) => _displayTag(value.toString(), locale))
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      region: _displayPublicText(
        _localizedText(
          detail,
          'region',
          locale,
          fallback: _localizedText(kyc, 'regions', locale, fallback: '以官网为准'),
        ),
        locale,
      ),
      funding: _displayPublicText(
        _localizedText(detail, 'funding', locale, fallback: '以官网为准'),
        locale,
      ),
      availability: _displayPublicText(
        _localizedText(detail, 'speed', locale, fallback: '以官方开放状态为准'),
        locale,
      ),
      features: content.features,
      rules: content.rules,
      fees: fees,
      kycNote: _localizedText(
        kyc,
        'detail',
        locale,
        fallback: _localizedText(
          kyc,
          'documentNote',
          locale,
          fallback: '身份材料要求以官方申请流程为准。',
        ),
      ),
      paymentChannels: {
        if (_truthy(payment['applePay'])) PaymentChannel.applePay,
        if (_truthy(payment['googlePay'])) PaymentChannel.googlePay,
        if (_truthy(payment['wechatPay'])) PaymentChannel.wechatPay,
        if (_truthy(payment['alipay'])) PaymentChannel.alipay,
      },
      sourceLabel: [
        card.sourceUrl == null ? '' : '官方来源',
        detail['referenceInfo'] is Map
            ? _localizedText(
                Map<String, dynamic>.from(detail['referenceInfo'] as Map),
                'sourceName',
                locale,
              )
            : '',
      ].where((value) => value.isNotEmpty).join(' · '),
      note: note.isEmpty ? '费用与权益请以官网最新规则为准。' : note,
      rating: _positiveDouble(detail['rating']),
      reviewCount: _positiveInt(detail['reviews']),
      chinaKyc: chinaKyc.isEmpty ? null : _chinaKycFromJson(chinaKyc, locale),
      openingRequirements: openingRequirement.isEmpty
          ? null
          : _openingRequirementsFromJson(openingRequirement, locale),
      inviteCode: _nullableText(detail['inviteCode']),
      inviteUrl: _nullableText(detail['inviteUrl']),
    );
  }

  CardOpeningRequirements _openingRequirementsFromJson(
    Map<String, dynamic> value,
    Locale? locale,
  ) {
    final requirements = value['requirements'] is Map
        ? Map<String, dynamic>.from(value['requirements'] as Map)
        : const <String, dynamic>{};
    OpeningRequirementState state(String key) {
      return switch (requirements[key]?.toString()) {
        'required' => OpeningRequirementState.required,
        'notRequired' => OpeningRequirementState.notRequired,
        _ => OpeningRequirementState.unknown,
      };
    }

    return CardOpeningRequirements(
      states: {
        OpeningRequirementKind.inviteCode: state('inviteCode'),
        OpeningRequirementKind.idCard: state('idCard'),
        OpeningRequirementKind.passport: state('passport'),
        OpeningRequirementKind.overseasAddressProof: state(
          'overseasAddressProof',
        ),
        OpeningRequirementKind.overseasPhone: state('overseasPhone'),
      },
      summary: _localizedText(value, 'summary', locale),
      note: _localizedText(value, 'note', locale),
      sourceName: _nullableText(value['sourceName']) ?? '',
      checkedAt: DateTime.tryParse(value['checkedAt']?.toString() ?? ''),
    );
  }

  Future<CardDetail> _loadGlobalAccount(
    CardSummary card, {
    Locale? locale,
  }) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/global-accounts/${Uri.encodeComponent(card.id)}',
        query: {if (locale != null) 'locale': locale.toLanguageTag()},
        headers: locale == null
            ? null
            : {'accept-language': locale.toLanguageTag()},
      ),
    );
    final detail = jsonObject(response['detail'], label: '全球账户详情');
    final chinaKyc = detail['chinaKyc'] is Map
        ? jsonObject(detail['chinaKyc'], label: '中国 KYC')
        : const <String, dynamic>{};
    final features = jsonList(detail['features'] ?? const [], label: '账户能力');
    final fees = jsonList(detail['fees'] ?? const [], label: '账户费用');
    final currencies =
        jsonList(detail['supportedCurrencies'] ?? const [], label: '支持币种')
            .map((value) => value.toString().trim().toUpperCase())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    String localized(Map<String, dynamic> value, String field) {
      return _localizedText(value, field, locale);
    }

    return CardDetail(
      cardId: card.id,
      tags: ['全球账户', ...currencies.take(4)],
      region: localized(detail, 'regions').isEmpty
          ? '以官网为准'
          : localized(detail, 'regions'),
      funding: localized(detail, 'funding').isEmpty
          ? '以官网为准'
          : localized(detail, 'funding'),
      availability: localized(detail, 'availability').isEmpty
          ? '以官方开放状态为准'
          : localized(detail, 'availability'),
      features: features
          .map((value) {
            final item = jsonObject(value, label: '账户能力');
            return DetailFeature(
              icon: switch (item['icon']?.toString()) {
                'shield' => DetailFeatureIcon.shield,
                'payments' => DetailFeatureIcon.payments,
                'globe' => DetailFeatureIcon.globe,
                _ => DetailFeatureIcon.wallet,
              },
              text: localized(item, 'text'),
            );
          })
          .toList(growable: false),
      fees: fees
          .map((value) {
            final item = jsonObject(value, label: '账户费用');
            return FeeLine(
              label: localized(item, 'label'),
              value: localized(item, 'value'),
            );
          })
          .toList(growable: false),
      kycNote: localized(chinaKyc, 'documentSummary').isEmpty
          ? '身份材料要求以官方申请流程为准。'
          : localized(chinaKyc, 'documentSummary'),
      paymentChannels: const <PaymentChannel>{},
      supportedCurrencies: List.unmodifiable(currencies),
      sourceLabel: [
        detail['sourceName']?.toString() ?? '',
        detail['lastVerifiedAt'] == null
            ? ''
            : "核验于 ${detail['lastVerifiedAt']}",
      ].where((value) => value.isNotEmpty).join(' · '),
      note: localized(detail, 'safeguarding').isEmpty
          ? '本页仅整理公开资料，申请和可用功能以官方流程为准。'
          : localized(detail, 'safeguarding'),
      chinaKyc: chinaKyc.isEmpty
          ? null
          : _chinaKycFromJson({
              ...chinaKyc,
              'documentSummary': localized(chinaKyc, 'documentSummary'),
              'note': localized(chinaKyc, 'note'),
            }, locale),
    );
  }

  /// The public API has historically returned booleans here, while the
  /// reviewed card records use an object so that each payment capability can
  /// retain its source and verification date. Treat only an explicit
  /// `supported` status as enabled; conditional and unknown support must not
  /// be promoted to a definitive badge.
  bool _truthy(Object? value) {
    if (value == true || value == 1 || value == 'true') return true;
    if (value is! Map) return false;
    return value['status']?.toString().trim().toLowerCase() == 'supported';
  }

  double? _positiveDouble(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _positiveInt(Object? value) {
    final parsed = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  _DetailContent _contentFromBenefits(
    List<Object?> rawBenefits, {
    Locale? locale,
  }) {
    const ruleIcons = <String, DetailFeatureIcon>{
      '入金方式': DetailFeatureIcon.wallet,
      '适用场景': DetailFeatureIcon.globe,
      '返现规则': DetailFeatureIcon.payments,
      '返现限制': DetailFeatureIcon.payments,
      '返现发放': DetailFeatureIcon.wallet,
      '储蓄 APY': DetailFeatureIcon.payments,
      'Funding': DetailFeatureIcon.wallet,
      'Use cases': DetailFeatureIcon.globe,
      'Cashback rules': DetailFeatureIcon.payments,
      'Cashback limits': DetailFeatureIcon.payments,
      'Cashback payout': DetailFeatureIcon.wallet,
      'Savings APY': DetailFeatureIcon.payments,
    };
    final features = <DetailFeature>[];
    final rules = <DetailRule>[];
    for (final value in rawBenefits) {
      final item = jsonObject(value, label: '权益');
      final rawText = _localizedText(item, 'text', locale);
      if (rawText.isEmpty) continue;
      final separator = rawText.indexOf(RegExp('：|:'));
      final label = separator < 0 ? '' : rawText.substring(0, separator).trim();
      final ruleIcon = ruleIcons[label];
      if (ruleIcon != null) {
        rules.add(
          DetailRule(
            label: label,
            value: _displayPublicText(rawText.substring(separator + 1), locale),
            icon: ruleIcon,
          ),
        );
        continue;
      }
      features.add(
        DetailFeature(
          icon: switch (item['icon']?.toString()) {
            'shield' => DetailFeatureIcon.shield,
            'market' || 'payments' => DetailFeatureIcon.payments,
            'grid' || 'plane' => DetailFeatureIcon.globe,
            _ => DetailFeatureIcon.wallet,
          },
          text: _displayPublicText(rawText, locale),
        ),
      );
    }
    return _DetailContent(features: features, rules: rules);
  }

  List<Object?> _feesWithTodeyFacts(
    List<Object?> fees,
    Map<String, dynamic> todeyFacts,
  ) {
    final result = List<Object?>.from(fees);
    void addOrReplace(String label, Object? rawValue) {
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) return;
      final index = result.indexWhere((entry) {
        final item = entry is Map ? entry : const <Object?, Object?>{};
        return item['label']?.toString().trim() == label;
      });
      final item = <String, String>{'label': label, 'value': value};
      if (index >= 0) {
        final existing = result[index];
        final existingValue = existing is Map
            ? existing['value']?.toString().trim() ?? ''
            : '';
        if (existingValue.isEmpty || existingValue.contains('官网')) {
          result[index] = item;
        }
      } else {
        result.add(item);
      }
    }

    addOrReplace('开卡费', todeyFacts['registerFee']);
    addOrReplace('年费', todeyFacts['annualFee']);
    addOrReplace('外汇费', todeyFacts['fxFee']);
    return result;
  }

  List<FeeLine> _normalizedFees(List<Object?> rawFees, {Locale? locale}) {
    final selected = <String, _FeeCandidate>{};
    for (final value in rawFees) {
      final item = jsonObject(value, label: '费用');
      final rawLabel = _localizedText(item, 'label', locale);
      final rawValue = _localizedText(item, 'value', locale);
      if (rawLabel.isEmpty || rawValue.isEmpty) continue;
      final imported = rawLabel.startsWith('Ranked+');
      final label = _feeLabel(rawLabel);
      final parts = rawValue.split('；');
      final candidate = _FeeCandidate(
        line: FeeLine(
          label: label,
          value: _displayPublicText(parts.first, locale),
          note: parts.length < 2
              ? null
              : _displayPublicText(parts.skip(1).join('；'), locale),
        ),
        priority: imported ? 2 : 1,
      );
      final previous = selected[label];
      if (previous == null || candidate.priority >= previous.priority) {
        selected[label] = candidate;
      }
    }
    const order = <String>['开卡费', '年费', '月费', '充值手续费', '外汇费', '取现手续费'];
    final lines = selected.values.map((candidate) => candidate.line).toList();
    lines.sort((left, right) {
      final leftIndex = order.indexOf(left.label);
      final rightIndex = order.indexOf(right.label);
      final rankedLeft = leftIndex < 0 ? order.length : leftIndex;
      final rankedRight = rightIndex < 0 ? order.length : rightIndex;
      return rankedLeft == rankedRight
          ? left.label.compareTo(right.label)
          : rankedLeft.compareTo(rankedRight);
    });
    return List.unmodifiable(lines);
  }

  String _feeLabel(String rawLabel) {
    final label = rawLabel.replaceFirst(RegExp(r'^Ranked\+\s*'), '').trim();
    return switch (label) {
      '月费起' => '月费',
      'ATM 取现费' => '取现手续费',
      _ => label,
    };
  }

  String _displayTag(String rawTag, Locale? locale) {
    final tag = rawTag.trim();
    if (tag.startsWith('Ranked+')) {
      final tier = tag
          .replaceFirst(RegExp(r'^Ranked\+\s*'), '')
          .replaceFirst(RegExp(r'级$'), '')
          .trim();
      return tier.isEmpty ? '' : '评级：$tier';
    }
    if (tag == 'KYC：Full') return 'KYC：完整验证';
    if (tag == 'KYC：Minimal') return 'KYC：简化验证';
    return _displayPublicText(tag, locale);
  }

  String _displayPublicText(String raw, Locale? locale) {
    // Escaped line breaks can arrive in any localized API field. Normalize
    // transport artifacts before choosing whether language conversion is
    // needed so English and other locales never render a literal "\\n".
    final text = raw.replaceAll(r'\n', '\n').replaceAll('\ufeff', '').trim();
    // The device locale is already represented by a server translation when
    // available. The small built-in converter only exists to keep the Chinese
    // experience readable for legacy English-only records; applying it to
    // Japanese, Korean, etc. would corrupt a valid remote translation.
    return locale?.languageCode == 'zh' || locale == null
        ? _translatePublicText(text)
        : text;
  }

  String _translatePublicText(String raw) {
    var text = raw.replaceAll('Ranked+ 可用性：', '可用性：').trim();
    const exact = <String, String>{
      r'One time $10 activation fee for virtual card, and $100 for physical card.':
          r'虚拟卡一次性激活费 $10；实体卡一次性激活费 $100。',
      'Refers to the crypto conversion rate.': '适用于加密资产兑换汇率。',
      r'Monthly ATM Withdrawal Limits ≤ 10,000 USD : 2%\nMonthly ATM Withdrawal Limits > 10,000 USD : 3%':
          r'每月 ATM 取现不超过 10,000 USD：2%；超过 10,000 USD：3%。',
      'Core: 0-0.5%\nLuxe: 0-0.25%\nPinnacle: 0%\nVIP: 0%':
          'Core：0–0.5%\nLuxe：0–0.25%\nPinnacle：0%\nVIP：0%',
      r'All ATM withdrawals incur 2% fee; daily limit $250 USD, max 3 attempts per 24h':
          r'每日 ATM 取现限额 $250 USD，24 小时最多 3 次。',
      'Excludes: ATM withdrawals, P2P transfers, FX transactions, tax payments, gift cards, money orders, gambling, crypto transactions, wire transfers, balance transfers, cash advances':
          '不计入返现：ATM 取现、P2P 转账、外汇交易、税款、礼品卡、汇票、博彩、加密资产交易、电汇、余额转移及现金预借。',
      '• Lite: 2% cashback (max \$250 per month)\n  • Core: 3% base cashback + 5% AI cashback\n  • Platinum: 4% cashback + 10% AI cashback (max \$1,000 per month)':
          '• Lite：2% 返现（每月最高 \$250）\n• Core：基础 3% 返现 + 5% AI 返现\n• Platinum：4% 返现 + 10% AI 返现（每月最高 \$1,000）',
      r'• Lite: 2% cashback (max $250 per month)': r'• Lite：2% 返现（每月最高 $250）',
      'XPL (Plasma native token)': 'XPL（Plasma 原生代币）',
      '1% on non-USD transactions (cross-border fee: 0%)':
          '非 USD 交易收取 1%；跨境手续费为 0%。',
      'ATM withdrawals not supported (as of March 30, 2026)':
          '暂不支持 ATM 取现（截至 2026 年 3 月 30 日）。',
      'Daily crypto spending': '日常加密资产消费',
      'Earning yield / APY': '收益 / 年化收益率',
      'Travel spending': '旅行消费',
    };
    final direct = exact[text];
    if (direct != null) return direct;
    const replacements = <String, String>{
      'Bank transfer': '银行转账',
      'Crypto': '加密资产',
      'cashback': '返现',
      'APY': '年化收益率',
      'UP TO ': '最高 ',
      'GLOBAL': '全球',
      'VIRTUAL CARD': '虚拟卡',
      'PHYSICAL CARD': '实体卡',
      'FREE': '免费',
      'NO ANNUAL FEE': '免年费',
    };
    for (final replacement in replacements.entries) {
      text = text.replaceAll(replacement.key, replacement.value);
    }
    return text;
  }

  ChinaKycInfo _chinaKycFromJson(Map<String, dynamic> json, Locale? locale) =>
      ChinaKycInfo(
        status: switch (json['status']?.toString().trim().toLowerCase()) {
          'available' || 'eligible' || 'supported' => ChinaKycStatus.available,
          'restricted' ||
          'review' ||
          'conditional' => ChinaKycStatus.restricted,
          'unavailable' ||
          'ineligible' ||
          'unsupported' => ChinaKycStatus.unavailable,
          _ => ChinaKycStatus.unknown,
        },
        documentSummary: _localizedText(
          json,
          'documentSummary',
          locale,
          fallback: _localizedText(
            json,
            'documents',
            locale,
            fallback: '以官方申请流程展示为准',
          ),
        ),
        note: _localizedText(json, 'note', locale, fallback: '地区与证件资格可能随规则调整。'),
        sourceUrl: json['sourceUrl']?.toString() ?? '',
        checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? ''),
      );

  String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Public content may be delivered either through the requested `locale`
  /// response or as bilingual fields during the API migration. Prefer the
  /// requested translation, but never replace a real source value with a
  /// generic UI placeholder when a legacy record has not been migrated yet.
  String _localizedText(
    Map<String, dynamic> value,
    String field,
    Locale? locale, {
    String fallback = '',
  }) {
    final language = _translationLocale(locale);
    final translations = value['translations'];
    final translated = translations is Map && translations[language] is Map
        ? Map<String, dynamic>.from(translations[language] as Map)[field]
        : null;
    final preferred = language == 'zh'
        ? value['${field}Zh'] ?? value['${field}_zh']
        : translated ??
              (language == 'zh-Hant'
                  ? value['${field}Zh'] ?? value['${field}_zh']
                  : language == 'en'
                  ? value['${field}En'] ?? value['${field}_en']
                  : null);
    final resolved = preferred ?? value[field];
    final text = resolved?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<Object?> _localizedList(
    Map<String, dynamic> value,
    String field,
    Locale? locale,
  ) {
    final language = _translationLocale(locale);
    final translations = value['translations'];
    final translated = translations is Map && translations[language] is Map
        ? Map<String, dynamic>.from(translations[language] as Map)[field]
        : null;
    final preferred = language == 'zh'
        ? value['${field}Zh'] ?? value['${field}_zh']
        : translated ??
              (language == 'zh-Hant'
                  ? value['${field}Zh'] ?? value['${field}_zh']
                  : language == 'en'
                  ? value['${field}En'] ?? value['${field}_en']
                  : null);
    return jsonList(preferred ?? value[field] ?? const [], label: '详情$field');
  }

  String _translationLocale(Locale? locale) {
    if (locale == null) return 'zh';
    if (locale.languageCode == 'zh' &&
        (locale.countryCode == 'HK' || locale.countryCode == 'TW')) {
      return 'zh-Hant';
    }
    return locale.languageCode;
  }
}

class _DetailContent {
  const _DetailContent({required this.features, required this.rules});

  final List<DetailFeature> features;
  final List<DetailRule> rules;
}

class _FeeCandidate {
  const _FeeCandidate({required this.line, required this.priority});

  final FeeLine line;
  final int priority;
}
