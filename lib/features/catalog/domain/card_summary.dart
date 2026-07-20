enum CardCategory {
  uCard('U 卡'),
  creditCard('信用卡'),
  debitCard('借记卡'),
  bankAccount('银行账户');

  const CardCategory(this.label);

  final String label;

  bool get isUCard => this == CardCategory.uCard;
}

enum KycDocument {
  idCard('身份证'),
  passport('护照');

  const KycDocument(this.label);

  final String label;
}

enum CardNetwork { visa, mastercard, other }

class CardSummary {
  const CardSummary({
    required this.id,
    required this.name,
    required this.issuer,
    required this.category,
    required this.label,
    required this.tint,
    this.assetPath,
    this.imageUrl,
    this.logoImageUrl,
    this.sourceUrl,
    this.kycDocuments = const <KycDocument>{},
    this.isNew = false,
  });

  final String id;
  final String name;
  final String issuer;
  final CardCategory category;
  final String label;
  final int tint;
  final String? assetPath;
  final String? imageUrl;
  final String? logoImageUrl;
  final String? sourceUrl;
  final Set<KycDocument> kycDocuments;
  final bool isNew;

  CardNetwork get network {
    final normalized = label.toLowerCase();
    if (normalized.contains('visa')) return CardNetwork.visa;
    if (normalized.contains('mastercard') ||
        RegExp(r'(^|\W)mc($|\W)').hasMatch(normalized)) {
      return CardNetwork.mastercard;
    }
    return CardNetwork.other;
  }

  bool matches(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return <String>[
      name,
      issuer,
      category.label,
      label,
      ...kycDocuments.map((document) => document.label),
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}

abstract interface class CardCatalogRepository {
  Future<List<CardSummary>> loadCards({bool force = false});
}
