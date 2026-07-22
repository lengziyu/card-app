import 'package:card_app/features/catalog/domain/card_summary.dart';

enum DetailFeatureIcon { wallet, shield, payments, globe }

enum PaymentChannel {
  applePay('Apple Pay'),
  googlePay('Google Pay'),
  wechatPay('微信支付'),
  alipay('支付宝');

  const PaymentChannel(this.label);

  final String label;
}

enum ChinaKycStatus {
  available('可申请 · 需验证'),
  restricted('受限 · 需个案核验'),
  unavailable('暂不支持'),
  unknown('暂未核验');

  const ChinaKycStatus(this.label);

  final String label;
}

/// Mainland-China onboarding facts for a global account.
///
/// This is deliberately separate from generic KYC documents: a provider can
/// accept an applicant in China while imposing currency, transfer, or document
/// restrictions that cannot be expressed by a simple passport/ID-card badge.
class ChinaKycInfo {
  const ChinaKycInfo({
    required this.status,
    required this.documentSummary,
    required this.note,
    required this.sourceUrl,
    this.checkedAt,
  });

  final ChinaKycStatus status;
  final String documentSummary;
  final String note;
  final String sourceUrl;
  final DateTime? checkedAt;
}

class DetailFeature {
  const DetailFeature({required this.icon, required this.text});

  final DetailFeatureIcon icon;
  final String text;
}

class FeeLine {
  const FeeLine({required this.label, required this.value});

  final String label;
  final String value;
}

class CardDetail {
  const CardDetail({
    required this.cardId,
    required this.tags,
    required this.region,
    required this.funding,
    required this.availability,
    required this.features,
    required this.fees,
    required this.kycNote,
    required this.paymentChannels,
    required this.sourceLabel,
    required this.note,
    this.chinaKyc,
    this.inviteCode,
    this.inviteUrl,
  });

  final String cardId;
  final List<String> tags;
  final String region;
  final String funding;
  final String availability;
  final List<DetailFeature> features;
  final List<FeeLine> fees;
  final String kycNote;
  final Set<PaymentChannel> paymentChannels;
  final String sourceLabel;
  final String note;
  final ChinaKycInfo? chinaKyc;
  final String? inviteCode;
  final String? inviteUrl;
}

abstract interface class CardDetailRepository {
  CardDetail detailFor(CardSummary card);
}
