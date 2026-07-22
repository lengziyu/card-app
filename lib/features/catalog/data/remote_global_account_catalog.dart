import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';

class RemoteGlobalAccountCatalogRepository implements CardCatalogRepository {
  RemoteGlobalAccountCatalogRepository(this._apiClient);

  final ApiClient _apiClient;
  List<CardSummary>? _cache;
  Future<List<CardSummary>>? _inFlight;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    if (!force && _inFlight != null) return _inFlight!;
    final request = _load();
    _inFlight = request;
    try {
      final accounts = await request;
      _cache = accounts;
      return accounts;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<List<CardSummary>> _load() async {
    final response = jsonObject(await _apiClient.get('/api/global-accounts'));
    return jsonList(response['items'], label: '全球账户列表')
        .map((value) => _fromJson(jsonObject(value, label: '全球账户')))
        .toList(growable: false);
  }

  CardSummary _fromJson(Map<String, dynamic> json) {
    final coverPath = json['coverImageSrc']?.toString().trim() ?? '';
    final logoPath = json['logoImageSrc']?.toString().trim() ?? '';
    final colors = json['coverColors'] is List
        ? json['coverColors'] as List
        : const [];
    return CardSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名全球账户',
      issuer: json['provider']?.toString() ?? '',
      category: CardCategory.bankAccount,
      label:
          json['taglineZh']?.toString() ??
          json['taglineEn']?.toString() ??
          '多币种账户',
      tint: _parseColor(colors.isEmpty ? null : colors.first.toString()),
      coverImageUrl: coverPath.isEmpty
          ? null
          : _apiClient.resolve(coverPath).toString(),
      logoImageUrl: logoPath.isEmpty
          ? null
          : _apiClient.resolve(logoPath).toString(),
      sourceUrl: json['sourceUrl']?.toString(),
      kind: CatalogItemKind.globalAccount,
    );
  }

  int _parseColor(String? source) {
    final hex = (source ?? '').replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return 0xFF5D7C63;
    return hex.length == 6 ? 0xFF000000 | value : value;
  }
}

class RemoteMarketCatalogRepository implements CardCatalogRepository {
  factory RemoteMarketCatalogRepository({
    required CardCatalogRepository cards,
    required CardCatalogRepository globalAccounts,
  }) => RemoteMarketCatalogRepository._(cards, globalAccounts);

  RemoteMarketCatalogRepository._(this._cards, this._globalAccounts);

  final CardCatalogRepository _cards;
  final CardCatalogRepository _globalAccounts;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async {
    final results = await Future.wait([
      _loadSafely(_cards, force: force),
      _loadSafely(_globalAccounts, force: force),
    ]);
    final cardsResult = results[0];
    final accountsResult = results[1];

    // Cards and global accounts are intentionally maintained by independent
    // endpoints. A rollout or outage in one directory must not hide data from
    // the other directory. Keep the bundled preview for only the failed
    // section; if both endpoints fail, surface the network error normally.
    if (cardsResult.items == null && accountsResult.items == null) {
      Error.throwWithStackTrace(cardsResult.error!, cardsResult.stackTrace!);
    }

    final cards =
        cardsResult.items ??
        localCardCatalog.where((item) => !item.isGlobalAccount).toList();
    final accounts =
        accountsResult.items ??
        localCardCatalog.where((item) => item.isGlobalAccount).toList();
    final seen = <String>{};
    return [
      ...cards,
      ...accounts,
    ].where((item) => seen.add(item.id)).toList(growable: false);
  }

  Future<_CatalogLoadResult> _loadSafely(
    CardCatalogRepository repository, {
    required bool force,
  }) async {
    try {
      return _CatalogLoadResult.items(await repository.loadCards(force: force));
    } catch (error, stackTrace) {
      return _CatalogLoadResult.error(error, stackTrace);
    }
  }
}

class _CatalogLoadResult {
  const _CatalogLoadResult.items(this.items) : error = null, stackTrace = null;

  const _CatalogLoadResult.error(this.error, this.stackTrace) : items = null;

  final List<CardSummary>? items;
  final Object? error;
  final StackTrace? stackTrace;
}
