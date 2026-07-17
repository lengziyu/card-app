import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/data/remote_card_catalog.dart';
import 'package:card_app/features/catalog/data/remote_card_details.dart';
import 'package:card_app/features/catalog/data/remote_catalog_settings.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('maps the remote catalog, ordering and home configuration', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/cards' => {
            'items': [
              {
                'id': 'card-1',
                'name': 'Card One',
                'issuer': 'Issuer',
                'category': 'U卡',
                'suffix': 'VISA',
                'surfaceColor': '#112233',
                'cardImageSrc': '/cards/one.webp',
                'kycDocuments': ['passport'],
              },
            ],
          },
          '/api/home-default-cards' => {
            'cardIds': ['card-1'],
          },
          '/api/list-card-order' => {
            'cardIds': ['card-2', 'card-1'],
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return _jsonResponse(body);
      }),
    );

    final cards = await RemoteCardCatalogRepository(client).loadCards();
    final settings = RemoteCatalogSettingsRepository(client);

    expect(cards.single.id, 'card-1');
    expect(cards.single.category, CardCategory.uCard);
    expect(cards.single.imageUrl, 'https://example.test/cards/one.webp');
    expect(cards.single.kycDocuments, contains(KycDocument.passport));
    expect(await settings.loadHomeDefaultCardIds(), ['card-1']);
    expect(await settings.loadListCardOrder(), ['card-2', 'card-1']);
    client.close();
  });

  test('maps a remote card detail', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => _jsonResponse({
          'item': {'id': 'card-1'},
          'detail': {
            'tags': ['返现'],
            'region': '全球',
            'funding': 'USDC',
            'speed': '开放申请',
            'benefits': [
              {'icon': 'shield', 'text': '安全权益'},
            ],
            'fees': [
              {'label': '年费', 'value': '0'},
            ],
            'kycFact': {'detailZh': '需要护照'},
            'paymentSupport': {'applePay': true},
          },
        }),
      ),
    );
    const card = CardSummary(
      id: 'card-1',
      name: 'Card One',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: '',
      tint: 0xFF112233,
    );

    final detail = await RemoteCardDetailRepository(client).detailFor(card);

    expect(detail.region, '全球');
    expect(detail.features.single.text, '安全权益');
    expect(detail.fees.single.value, '0');
    client.close();
  });

  test(
    'maps rankings, dashboards, articles and public article writes',
    () async {
      final postedPaths = <String>[];
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            postedPaths.add(request.url.path);
            return _jsonResponse(const <String, Object?>{});
          }
          final body = switch (request.url.path) {
            '/api/rankings' => {
              'groups': [
                {
                  'id': 'popular',
                  'name': '热门',
                  'description': '公开排行',
                  'cardIds': ['card-1'],
                },
              ],
            },
            '/api/stablecoins' => {
              'sourceLabel': 'DefiLlama',
              'updatedAt': '2026-07-17T00:00:00.000Z',
              'totalMarketCap': r'$1B',
              'totalVolume': r'$2M',
              'trackedAssets': 1,
              'history': {
                '30d': [1, 2],
              },
              'assets': [
                {
                  'id': '1',
                  'symbol': 'USDT',
                  'name': 'Tether',
                  'marketCap': r'$1B',
                  'dominancePct': 90,
                  'color': '#22B99A',
                },
              ],
              'chains': [
                {'name': 'Ethereum', 'value': r'$1B', 'share': 100},
              ],
            },
            '/api/stablecoins/1' => {
              'id': '1',
              'name': 'Tether',
              'symbol': 'USDT',
              'history': [1, 2, 3],
              'updatedAt': '2026-07-17T00:00:00.000Z',
            },
            '/api/card-metrics' => {
              'source': 'paymentscan',
              'methodology': '公开口径',
              'items': [
                {
                  'id': 'metric-1',
                  'name': 'Card One',
                  'cardId': 'card-1',
                  'sevenDayDepositVolume': 7,
                  'thirtyDayDepositVolume': 30,
                  'totalDepositVolume': 100,
                  'onchainTransactionCount': 9,
                  'activeAddressCount': 8,
                },
              ],
            },
            '/api/articles' || '/api/articles/news-one' => {
              'items': request.url.path == '/api/articles'
                  ? [_articleJson]
                  : null,
              'item': request.url.path == '/api/articles/news-one'
                  ? {..._articleJson, 'rawContent': '第一段\n\n第二段'}
                  : null,
            },
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
          return _jsonResponse(body);
        }),
      );
      final repository = RemoteRankingRepository(client);

      expect((await repository.loadRankings()).single.cardIds, ['card-1']);
      expect((await repository.loadStablecoins()).assets.single.id, '1');
      expect((await repository.loadStablecoinDetail('1')).history, [1, 2, 3]);
      expect((await repository.loadMetrics()).items.single.total, 100);
      expect((await repository.loadArticles()).single.article.id, 'news-one');
      expect((await repository.loadArticle('news-one')).article.body, [
        '第一段',
        '第二段',
      ]);
      await repository.recordArticleView('news-one');
      await repository.likeArticle('news-one');
      expect(postedPaths, [
        '/api/articles/news-one/view',
        '/api/articles/news-one/like',
      ]);
      client.close();
    },
  );
}

const _articleJson = <String, Object?>{
  'id': 'article-id',
  'slug': 'news-one',
  'title': '文章',
  'summary': '摘要',
  'category': 'news',
  'tags': ['行业'],
  'relatedCardIds': ['card-1'],
  'publishedAt': '2026-07-17T00:00:00.000Z',
  'viewCount': 2,
  'likeCount': 1,
};

http.Response _jsonResponse(Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
