enum CardCategory {
  uCard('U 卡'),
  creditCard('信用卡'),
  debitCard('借记卡'),
  bankAccount('银行账户');

  const CardCategory(this.label);

  final String label;

  bool get isUCard => this == CardCategory.uCard;
}

/// A directory entry can describe a card or a non-card financial product.
///
/// Keep this separate from [CardCategory]: a provider may offer a card beside
/// its account, but a global account is still not something users add to their
/// personal card wallet.
enum CatalogItemKind { card, globalAccount }

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
    this.coverImageUrl,
    this.logoImageUrl,
    this.sourceUrl,
    this.kycDocuments = const <KycDocument>{},
    this.isNew = false,
    this.kind = CatalogItemKind.card,
  });

  final String id;
  final String name;
  final String issuer;
  final CardCategory category;
  final String label;
  final int tint;
  final String? assetPath;
  final String? imageUrl;
  final String? coverImageUrl;
  final String? logoImageUrl;
  final String? sourceUrl;
  final Set<KycDocument> kycDocuments;
  final bool isNew;
  final CatalogItemKind kind;

  bool get isGlobalAccount => kind == CatalogItemKind.globalAccount;

  bool get isAddableToCardWallet => kind == CatalogItemKind.card;

  String get directoryTypeLabel => isGlobalAccount ? '全球账户' : category.label;

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
