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
    this.transferCurrencies = const <String>[],
    this.receivingMethods = const <String>[],
    this.chinaKycStatus = 'unknown',
    this.kycSummary = '',
    this.cashbackRate = '',
    this.updatedAt,
    this.isNew = false,
    this.kind = CatalogItemKind.card,
    this.accountType = '',
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

  /// Currencies advertised for transfers in the global-account directory.
  /// This is intentionally summary data: full availability remains in detail.
  final List<String> transferCurrencies;

  /// Provider-advertised ways to fund or receive into a global account.
  /// Values are normalized API identifiers such as `ach`, `wire`, or `crypto`.
  final List<String> receivingMethods;

  /// Mainland-China onboarding status curated by the provider record.
  /// `unknown` means the public sources do not confirm eligibility.
  final String chinaKycStatus;
  final String kycSummary;
  final String cashbackRate;
  final DateTime? updatedAt;
  final bool isNew;
  final CatalogItemKind kind;

  /// Provider-curated account classification from the global-account API.
  ///
  /// This remains a string because providers introduce new account types. The
  /// client only uses the crypto prefix for a clear, conservative disclosure.
  final String accountType;

  bool get isGlobalAccount => kind == CatalogItemKind.globalAccount;

  bool get isCryptoRelated =>
      isGlobalAccount && accountType.trim().toLowerCase().startsWith('crypto');

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
