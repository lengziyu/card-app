import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/domain/ranking_data.dart';

class RemoteRankingRepository {
  RemoteRankingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RankingGroup>> loadRankings() async {
    final response = jsonObject(await _apiClient.get('/api/rankings'));
    return jsonList(response['groups'], label: '排行榜')
        .map((value) {
          final json = jsonObject(value, label: '排行榜分组');
          return RankingGroup(
            id: json['id']?.toString() ?? '',
            name: json['name']?.toString() ?? '',
            description: json['description']?.toString() ?? '',
            cardIds: jsonList(
              json['cardIds'] ?? const [],
              label: '卡片编号',
            ).map((id) => id.toString()).toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<StablecoinDashboard> loadStablecoins() async {
    final json = jsonObject(await _apiClient.get('/api/stablecoins'));
    final history = jsonObject(json['history'], label: '趋势');
    return StablecoinDashboard(
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      totalMarketCap: json['totalMarketCap']?.toString() ?? '—',
      totalVolume: json['totalVolume']?.toString() ?? '—',
      trackedAssets: (json['trackedAssets'] as num?)?.toInt() ?? 0,
      history: jsonList(history['30d'] ?? const [], label: '30 天趋势')
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false),
      assets: jsonList(json['assets'] ?? const [], label: '稳定币')
          .map((value) {
            final item = jsonObject(value, label: '稳定币');
            return StablecoinAsset(
              id: item['id']?.toString() ?? '',
              symbol: item['symbol']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              marketCap: item['marketCap']?.toString() ?? '—',
              dominance: (item['dominancePct'] as num?)?.toDouble() ?? 0,
              color: _parseColor(item['color']?.toString()),
            );
          })
          .toList(growable: false),
      chains: jsonList(json['chains'] ?? const [], label: '网络')
          .map((value) {
            final item = jsonObject(value, label: '网络');
            return StablecoinChain(
              name: item['name']?.toString() ?? '',
              value: item['value']?.toString() ?? '—',
              share: (item['share'] as num?)?.toDouble() ?? 0,
            );
          })
          .toList(growable: false),
    );
  }

  Future<CardMetricsDashboard> loadMetrics() async {
    final json = jsonObject(await _apiClient.get('/api/card-metrics'));
    return CardMetricsDashboard(
      source: json['source']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      methodology: json['methodology']?.toString() ?? '',
      items: jsonList(json['items'] ?? const [], label: '数据榜')
          .map((value) {
            final item = jsonObject(value, label: '数据项');
            return CardMetric(
              id: item['id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              cardId: item['cardId']?.toString(),
              logoText: item['logoText']?.toString() ?? '',
              sevenDay: item['sevenDayDepositVolume'] as num? ?? 0,
              thirtyDay: item['thirtyDayDepositVolume'] as num? ?? 0,
              total: item['totalDepositVolume'] as num? ?? 0,
              transactions: item['onchainTransactionCount'] as num? ?? 0,
              addresses: item['activeAddressCount'] as num? ?? 0,
            );
          })
          .toList(growable: false),
    );
  }

  Future<StablecoinDetail> loadStablecoinDetail(String id) async {
    final json = jsonObject(await _apiClient.get('/api/stablecoins/$id'));
    return StablecoinDetail(
      id: json['id']?.toString() ?? id,
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      history: jsonList(json['history'] ?? const [], label: '供应趋势')
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Future<List<ArticleFeedItem>> loadArticles() async {
    final json = jsonObject(await _apiClient.get('/api/articles'));
    return jsonList(json['items'] ?? const [], label: '文章列表')
        .map((value) => _articleFromJson(jsonObject(value, label: '文章')))
        .toList(growable: false);
  }

  Future<ArticleFeedItem> loadArticle(String slug) async {
    final json = jsonObject(await _apiClient.get('/api/articles/$slug'));
    return _articleFromJson(jsonObject(json['item'], label: '文章详情'));
  }

  Future<void> recordArticleView(String slug) async {
    await _apiClient.post('/api/articles/$slug/view');
  }

  Future<void> likeArticle(String slug) async {
    await _apiClient.post('/api/articles/$slug/like');
  }

  ArticleFeedItem _articleFromJson(Map<String, dynamic> json) {
    final slug = json['slug']?.toString() ?? '';
    final raw = json['rawContent']?.toString() ?? '';
    final paragraphs = raw
        .split(RegExp(r'\n\s*\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final category = switch (json['category']?.toString()) {
      'news' => '行业资讯',
      'benefit' => '权益指南',
      _ => '开卡攻略',
    };
    final coverPath = json['coverImageUrl']?.toString() ?? '';
    return ArticleFeedItem(
      slug: slug,
      article: LocalArticle(
        // 远端文章的详情、浏览和点赞接口均以 slug 定位。
        id: slug,
        category: category,
        title: json['title']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        body: paragraphs.isEmpty
            ? [json['summary']?.toString() ?? '']
            : paragraphs,
        tags: jsonList(
          json['tags'] ?? const [],
          label: '文章标签',
        ).map((value) => value.toString()).toList(growable: false),
        publishedLabel: _dateLabel(json['publishedAt']?.toString()),
        relatedCardIds: jsonList(
          json['relatedCardIds'] ?? const [],
          label: '相关卡片',
        ).map((value) => value.toString()).toList(growable: false),
      ),
      coverImageUrl: coverPath.isEmpty
          ? null
          : _apiClient.resolve(coverPath).toString(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  String _dateLabel(String? source) {
    final date = DateTime.tryParse(source ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _parseColor(String? source) {
    final hex = (source ?? '').replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return 0xFF6B78FF;
    return hex.length == 6 ? 0xFF000000 | value : value;
  }
}
