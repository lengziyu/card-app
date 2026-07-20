import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';

class RemoteCardDetailRepository {
  RemoteCardDetailRepository(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, Future<CardDetail>> _cache = {};

  Future<CardDetail> detailFor(CardSummary card, {bool force = false}) {
    if (force) _cache.remove(card.id);
    return _cache.putIfAbsent(card.id, () => _load(card));
  }

  Future<CardDetail> _load(CardSummary card) async {
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
      inviteCode: _nullableText(detail['inviteCode']),
      inviteUrl: _nullableText(detail['inviteUrl']),
    );
  }

  bool _truthy(Object? value) => value == true || value == 1 || value == 'true';

  String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
