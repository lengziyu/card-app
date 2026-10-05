import 'package:cardfi/features/catalog/domain/card_summary.dart';

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

enum OpeningRequirementState { required, notRequired, unknown }

enum OpeningRequirementKind {
  inviteCode('邀请码'),
  idCard('身份证'),
  passport('护照'),
  overseasAddressProof('海外证明'),
  overseasPhone('海外手机号');

  const OpeningRequirementKind(this.label);

  final String label;
}

/// Published onboarding requirements maintained by the admin console.
///
/// These values describe whether an item is required during application. They
/// do not expose the actual invite code or invite URL, which remain controlled
/// by the separate public-content switches.
class CardOpeningRequirements {
  const CardOpeningRequirements({
    required this.states,
    this.summary = '',
    this.note = '',
    this.sourceName = '',
    this.checkedAt,
  });

  final Map<OpeningRequirementKind, OpeningRequirementState> states;
  final String summary;
  final String note;
  final String sourceName;
  final DateTime? checkedAt;

  OpeningRequirementState stateFor(OpeningRequirementKind kind) =>
      states[kind] ?? OpeningRequirementState.unknown;
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

/// A long-form usage, cashback, or funding rule shown outside the compact
/// benefit-card grid so that its content can wrap naturally.
class DetailRule {
  const DetailRule({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final DetailFeatureIcon icon;
}

class FeeLine {
  const FeeLine({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;
}

class CardDetail {
  const CardDetail({
    required this.cardId,
    required this.tags,
    required this.region,
    required this.funding,
    required this.availability,
    required this.features,
    this.rules = const [],
    required this.fees,
    required this.kycNote,
    required this.paymentChannels,
    required this.sourceLabel,
    required this.note,
    this.rating,
    this.reviewCount,
    this.supportedCurrencies = const [],
    this.chinaKyc,
    this.openingRequirements,
    this.inviteCode,
    this.inviteUrl,
  });

  final String cardId;
  final List<String> tags;
  final String region;
  final String funding;
  final String availability;
  final List<DetailFeature> features;
  final List<DetailRule> rules;
  final List<FeeLine> fees;
  final String kycNote;
  final Set<PaymentChannel> paymentChannels;
  final String sourceLabel;
  final String note;

  /// Public rating summary curated with the card detail. A missing value means
  /// the source does not publish enough information to display a score.
  final double? rating;
  final int? reviewCount;
  final List<String> supportedCurrencies;
  final ChinaKycInfo? chinaKyc;
  final CardOpeningRequirements? openingRequirements;
  final String? inviteCode;
  final String? inviteUrl;
}

abstract interface class CardDetailRepository {
  CardDetail detailFor(CardSummary card);
}
