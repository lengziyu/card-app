import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';

class RemoteCardCatalogRepository implements CardCatalogRepository {
  RemoteCardCatalogRepository(this._apiClient);

  final ApiClient _apiClient;
  List<CardSummary>? _cache;
  Future<List<CardSummary>>? _inFlight;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final pending = _inFlight;
    if (!force && pending != null) return pending;
    final request = _fetchCards();
    _inFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<List<CardSummary>> _fetchCards() async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/cards',
        query: const {'offset': 0, 'limit': 500},
      ),
    );
    final remoteCards = jsonList(response['items'], label: '卡片列表')
        .map((item) => _cardFromJson(jsonObject(item, label: '卡片')))
        .toList(growable: false);
    _cache = remoteCards;
    return remoteCards;
  }

  CardSummary _cardFromJson(Map<String, dynamic> json) {
    final categoryLabel = json['category']?.toString() ?? '';
    final imagePath = json['cardImageSrc']?.toString() ?? '';
    final coverPath =
        json['coverImageSrc']?.toString() ??
        json['accountCoverImageSrc']?.toString() ??
        '';
    final logoPath = json['logoImageSrc']?.toString() ?? '';
    return CardSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名卡片',
      issuer: json['issuer']?.toString() ?? '',
      category: switch (categoryLabel.toLowerCase()) {
        'u卡' || 'u 卡' || 'ucard' => CardCategory.uCard,
        '信用卡' || 'credit' => CardCategory.creditCard,
        '借记卡' || 'debit' => CardCategory.debitCard,
        _ => CardCategory.bankAccount,
      },
      label: [
        json['suffix']?.toString() ?? '',
        json['meta']?.toString() ?? '',
      ].where((value) => value.isNotEmpty).join(' · '),
      tint: _parseColor(json['surfaceColor']?.toString()),
      imageUrl: imagePath.isEmpty
          ? null
          : _apiClient.resolve(imagePath).toString(),
      coverImageUrl: coverPath.isEmpty
          ? null
          : _apiClient.resolve(coverPath).toString(),
      logoImageUrl: logoPath.isEmpty
          ? null
          : _apiClient.resolve(logoPath).toString(),
      sourceUrl: json['sourceUrl']?.toString(),
      kycDocuments: {
        for (final value
            in json['kycDocuments'] is List
                ? json['kycDocuments'] as List
                : const [])
          if (value.toString().toLowerCase().contains('passport'))
            KycDocument.passport
          else if (value.toString().toLowerCase().contains('id'))
            KycDocument.idCard,
      },
      kycSummary: json['kycSummary']?.toString() ?? '',
      cashbackRate: json['cashbackRate']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      isNew: _isNew(json['launchTimestamp'], json['createdAt']),
      kind: _kindFromJson(json['catalogKind'] ?? json['productKind']),
    );
  }

  CatalogItemKind _kindFromJson(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'globalaccount' ||
      'global_account' ||
      'global account' ||
      '全球账户' => CatalogItemKind.globalAccount,
      _ => CatalogItemKind.card,
    };
  }

  int _parseColor(String? source) {
    final hex = (source ?? '').replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return 0xFF6B78FF;
    return hex.length == 6 ? 0xFF000000 | value : value;
  }

  bool _isNew(Object? timestamp, Object? createdAt) {
    final milliseconds = timestamp is num
        ? timestamp.toInt()
        : DateTime.tryParse(
            createdAt?.toString() ?? '',
          )?.millisecondsSinceEpoch;
    if (milliseconds == null) return false;
    return DateTime.now().millisecondsSinceEpoch - milliseconds <
        const Duration(days: 45).inMilliseconds;
  }
}
