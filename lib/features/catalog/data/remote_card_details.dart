import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/data/local_card_details.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:flutter/widgets.dart';

class RemoteCardDetailRepository {
  RemoteCardDetailRepository(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, Future<CardDetail>> _cache = {};

  Future<CardDetail> detailFor(
    CardSummary card, {
    bool force = false,
    Locale? locale,
  }) {
    final cacheKey = '${card.id}:${locale?.languageCode ?? 'zh'}';
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
        // Wise is the bundled rollout preview. Keep its verified local detail
        // usable while the independent global-account API is being deployed.
        if (card.id == 'wise-account') {
          return const LocalCardDetailRepository().detailFor(card);
        }
        rethrow;
      }
    }
    final response = jsonObject(
      await _apiClient.get('/api/cards/${Uri.encodeComponent(card.id)}'),
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
    final benefits = jsonList(detail['benefits'] ?? const [], label: '卡片权益');
    final fees = jsonList(detail['fees'] ?? const [], label: '卡片费用');
    return CardDetail(
      cardId: card.id,
      tags: jsonList(
        detail['tags'] ?? const [],
        label: '详情标签',
      ).map((value) => value.toString()).toList(growable: false),
      region:
          detail['region']?.toString() ?? kyc['regions']?.toString() ?? '以官网为准',
      funding: detail['funding']?.toString() ?? '以官网为准',
      availability: detail['speed']?.toString() ?? '以官方开放状态为准',
      features: benefits
          .map((value) {
            final item = jsonObject(value, label: '权益');
            return DetailFeature(
              icon: switch (item['icon']?.toString()) {
                'shield' => DetailFeatureIcon.shield,
                'market' => DetailFeatureIcon.payments,
                'grid' => DetailFeatureIcon.globe,
                _ => DetailFeatureIcon.wallet,
              },
              text: item['text']?.toString() ?? '',
            );
          })
          .toList(growable: false),
      fees: fees
          .map((value) {
            final item = jsonObject(value, label: '费用');
            return FeeLine(
              label: item['label']?.toString() ?? '',
              value: item['value']?.toString() ?? '',
            );
          })
          .toList(growable: false),
      kycNote:
          kyc['detailZh']?.toString() ??
          kyc['documentNoteZh']?.toString() ??
          '身份材料要求以官方申请流程为准。',
      paymentChannels: {
        if (_truthy(payment['applePay'])) PaymentChannel.applePay,
        if (_truthy(payment['googlePay'])) PaymentChannel.googlePay,
        if (_truthy(payment['wechatPay'])) PaymentChannel.wechatPay,
        if (_truthy(payment['alipay'])) PaymentChannel.alipay,
      },
      sourceLabel: [
        card.sourceUrl == null ? '' : '官方来源',
        detail['referenceInfo'] is Map
            ? (detail['referenceInfo'] as Map)['sourceName']?.toString() ?? ''
            : '',
      ].where((value) => value.isNotEmpty).join(' · '),
      note: detail['note']?.toString() ?? '费用与权益请以官网最新规则为准。',
      chinaKyc: chinaKyc.isEmpty ? null : _chinaKycFromJson(chinaKyc),
      inviteCode: _nullableText(detail['inviteCode']),
      inviteUrl: _nullableText(detail['inviteUrl']),
    );
  }

  Future<CardDetail> _loadGlobalAccount(
    CardSummary card, {
    Locale? locale,
  }) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/global-accounts/${Uri.encodeComponent(card.id)}',
      ),
    );
    final detail = jsonObject(response['detail'], label: '全球账户详情');
    final chinaKyc = detail['chinaKyc'] is Map
        ? jsonObject(detail['chinaKyc'], label: '中国 KYC')
        : const <String, dynamic>{};
    final features = jsonList(detail['features'] ?? const [], label: '账户能力');
    final fees = jsonList(detail['fees'] ?? const [], label: '账户费用');
    final currencies = jsonList(
      detail['supportedCurrencies'] ?? const [],
      label: '支持币种',
    ).map((value) => value.toString()).where((value) => value.isNotEmpty);
    final useChinese = locale == null || locale.languageCode == 'zh';
    String localized(Map<String, dynamic> value, String field) {
      final preferred = useChinese ? '${field}Zh' : '${field}En';
      final fallback = useChinese ? '${field}En' : '${field}Zh';
      return value[preferred]?.toString() ?? value[fallback]?.toString() ?? '';
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
            }),
    );
  }

  bool _truthy(Object? value) => value == true || value == 1 || value == 'true';

  ChinaKycInfo _chinaKycFromJson(Map<String, dynamic> json) => ChinaKycInfo(
    status: switch (json['status']?.toString().trim().toLowerCase()) {
      'available' || 'eligible' || 'supported' => ChinaKycStatus.available,
      'restricted' || 'review' || 'conditional' => ChinaKycStatus.restricted,
      'unavailable' ||
      'ineligible' ||
      'unsupported' => ChinaKycStatus.unavailable,
      _ => ChinaKycStatus.unknown,
    },
    documentSummary:
        json['documentSummary']?.toString() ??
        json['documents']?.toString() ??
        '以官方申请流程展示为准',
    note: json['note']?.toString() ?? '地区与证件资格可能随规则调整。',
    sourceUrl: json['sourceUrl']?.toString() ?? '',
    checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? ''),
  );

  String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
