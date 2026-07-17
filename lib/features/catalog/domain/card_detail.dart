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
}

abstract interface class CardDetailRepository {
  CardDetail detailFor(CardSummary card);
}
