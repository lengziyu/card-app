import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';

class RemoteGlobalAccountCatalogRepository implements CardCatalogRepository {
  RemoteGlobalAccountCatalogRepository(this._apiClient);

  final ApiClient _apiClient;
  List<CardSummary>? _cache;
  Future<List<CardSummary>>? _inFlight;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    if (!force && _inFlight != null) return _inFlight!;
    final request = _load(force: force);
    _inFlight = request;
    try {
      final accounts = await request;
      _cache = accounts;
      return accounts;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<List<CardSummary>> _load({required bool force}) async {
    // The API intentionally permits a short shared-cache window. A user who
    // explicitly pulls to refresh expects newly published accounts right away.
    final response = jsonObject(
      await _apiClient.get(
        '/api/global-accounts',
        query: force
            ? {'refresh': DateTime.now().microsecondsSinceEpoch}
            : null,
      ),
    );
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
    // Older API records expose this as `supportedCurrencies`. Treat that as
    // the transfer list until the directory has an explicitly curated field.
    final transferCurrencies = _stringList(
      json['transferCurrencies'] ?? json['supportedCurrencies'],
    );
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
      transferCurrencies: transferCurrencies,
      receivingMethods: _stringList(json['receivingMethods'], uppercase: false),
      chinaKycStatus: json['chinaKycStatus']?.toString().trim() ?? 'unknown',
      kind: CatalogItemKind.globalAccount,
      accountType: json['accountType']?.toString() ?? '',
    );
  }

  List<String> _stringList(dynamic value, {bool uppercase = true}) {
    if (value is! List) return const [];
    final items = <String>[];
    for (final item in value) {
      final normalized = item.toString().trim();
      final value = uppercase
          ? normalized.toUpperCase()
          : normalized.toLowerCase();
      if (value.isNotEmpty && !items.contains(value)) items.add(value);
    }
    items.sort();
    return List.unmodifiable(items);
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
    // A successful directory response is authoritative. The bundled entries
    // are a preview for an unavailable endpoint only, never extra published
    // accounts that bypass the admin-managed directory.
    final accounts =
        accountsResult.items ??
        localCardCatalog
            .where((item) => item.isGlobalAccount)
            .toList(growable: false);
    // A provider can publish both a card and a separate global-account
    // profile under the same ID (for example, Wirex). They belong in
    // different market directories, so only deduplicate exact duplicates
    // within the same catalog kind.
    final seen = <String>{};
    return [...cards, ...accounts]
        .where((item) => seen.add('${item.kind.name}:${item.id}'))
        .toList(growable: false);
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
