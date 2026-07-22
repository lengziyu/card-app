import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/data/remote_card_catalog.dart';
import 'package:card_app/features/catalog/data/remote_card_details.dart';
import 'package:card_app/features/catalog/data/remote_global_account_catalog.dart';
import 'package:card_app/features/catalog/data/remote_catalog_settings.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/domain/ranking_data.dart';
import 'package:flutter/widgets.dart';
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
                'coverImageSrc': '/covers/one.webp',
                'kycDocuments': ['passport'],
              },
            ],
          },
          '/api/global-accounts' => {
            'items': [
              {
                'id': 'wise-account',
                'name': 'Wise Account',
                'provider': 'Wise',
                'taglineZh': '多币种持有 · 收款 · 换汇',
                'coverImageSrc': '/accounts/wise.webp',
                'coverColors': ['#9FE870', '#163300'],
                'chinaKycStatus': 'available',
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

    final cards = await RemoteMarketCatalogRepository(
      cards: RemoteCardCatalogRepository(client),
      globalAccounts: RemoteGlobalAccountCatalogRepository(client),
    ).loadCards();
    final settings = RemoteCatalogSettingsRepository(client);

    final card = cards.firstWhere((card) => card.id == 'card-1');
    expect(card.category, CardCategory.uCard);
    expect(card.imageUrl, 'https://example.test/cards/one.webp');
    expect(card.coverImageUrl, 'https://example.test/covers/one.webp');
    expect(card.kycDocuments, contains(KycDocument.passport));
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').isGlobalAccount,
      isTrue,
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').coverImageUrl,
      'https://example.test/accounts/wise.webp',
    );
    expect(await settings.loadHomeDefaultCardIds(), ['card-1']);
    expect(await settings.loadListCardOrder(), ['card-2', 'card-1']);
    client.close();
  });

  test(
    'keeps cards available when the global account endpoint is absent',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/cards') {
            return _jsonResponse({
              'items': [
                {
                  'id': 'card-1',
                  'name': 'Card One',
                  'issuer': 'Issuer',
                  'category': 'U卡',
                },
              ],
            });
          }
          return http.Response(
            jsonEncode({'message': 'Not found'}),
            404,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final items = await RemoteMarketCatalogRepository(
        cards: RemoteCardCatalogRepository(client),
        globalAccounts: RemoteGlobalAccountCatalogRepository(client),
      ).loadCards();

      expect(
        items.map((item) => item.id),
        containsAll(['card-1', 'wise-account']),
      );
      client.close();
    },
  );

  test('still reports a load error when both market endpoints fail', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final repository = RemoteMarketCatalogRepository(
      cards: RemoteCardCatalogRepository(client),
      globalAccounts: RemoteGlobalAccountCatalogRepository(client),
    );

    await expectLater(repository.loadCards(), throwsA(isA<Exception>()));
    client.close();
  });

  test('maps a remote global account detail', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => _jsonResponse({
          'item': {'id': 'wise-account'},
          'detail': {
            'supportedCurrencies': ['GBP', 'EUR', 'USD'],
            'regionsZh': '中国大陆可持有账户',
            'regionsEn': 'Available to mainland China residents',
            'fundingZh': '银行转账',
            'fundingEn': 'Bank transfer',
            'availabilityZh': '按居住地开放',
            'availabilityEn': 'Availability depends on residence',
            'features': [
              {
                'icon': 'globe',
                'textZh': '可按币种取得收款账户信息',
                'textEn': 'Receive account details for eligible currencies',
              },
            ],
            'fees': [
              {
                'labelZh': '账户月费',
                'labelEn': 'Monthly fee',
                'valueZh': '以官网为准',
                'valueEn': 'See official pricing',
              },
            ],
            'chinaKyc': {
              'status': 'available',
              'documentSummaryZh': '以申请流程为准',
              'documentSummaryEn': 'Follow the application flow',
              'noteZh': '中国大陆可申请',
              'noteEn': 'Mainland China residents may apply',
              'sourceUrl': 'https://example.test/kyc',
              'checkedAt': '2026-07-22',
            },
            'sourceName': 'Wise 官方帮助中心',
            'lastVerifiedAt': '2026-07-22',
          },
        }),
      ),
    );
    const account = CardSummary(
      id: 'wise-account',
      name: 'Wise Account',
      issuer: 'Wise',
      category: CardCategory.bankAccount,
      label: '多币种账户',
      tint: 0xFF9FE870,
      kind: CatalogItemKind.globalAccount,
    );

    final detail = await RemoteCardDetailRepository(client).detailFor(account);

    expect(detail.region, '中国大陆可持有账户');
    expect(detail.features.single.icon, DetailFeatureIcon.globe);
    expect(detail.chinaKyc?.status, ChinaKycStatus.available);
    expect(detail.tags, contains('GBP'));
    final english = await RemoteCardDetailRepository(
      client,
    ).detailFor(account, locale: const Locale('en'));
    expect(english.region, 'Available to mainland China residents');
    expect(english.features.single.text, contains('Receive account details'));
    client.close();
  });

  test('uses the bundled Wise detail while its endpoint is absent', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Not found'}),
          404,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    const account = CardSummary(
      id: 'wise-account',
      name: 'Wise Account',
      issuer: 'Wise',
      category: CardCategory.bankAccount,
      label: '多币种账户',
      tint: 0xFF9FE870,
      kind: CatalogItemKind.globalAccount,
    );

    final detail = await RemoteCardDetailRepository(client).detailFor(account);

    expect(detail.cardId, 'wise-account');
    expect(detail.chinaKyc?.status, ChinaKycStatus.available);
    expect(detail.sourceLabel, contains('Wise 官方帮助中心'));
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
            'chinaKyc': {
              'status': 'restricted',
              'documentSummary': '护照与地址证明以流程为准',
              'note': '功能需按中国大陆居住地核验',
              'sourceUrl': 'https://example.test/china-kyc',
              'checkedAt': '2026-07-22T00:00:00.000Z',
            },
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
    expect(detail.chinaKyc?.status, ChinaKycStatus.restricted);
    expect(detail.chinaKyc?.checkedAt, DateTime.utc(2026, 7, 22));
    client.close();
  });

  test('retries a card detail after a failed request', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'code': 'TEMPORARY', 'message': '稍后重试'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return _jsonResponse({
          'detail': {
            'tags': <String>[],
            'benefits': <Object>[],
            'fees': <Object>[],
          },
        });
      }),
    );
    const card = CardSummary(
      id: 'card-retry',
      name: 'Retry Card',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: '',
      tint: 0xFF112233,
    );
    final repository = RemoteCardDetailRepository(client);

    await expectLater(repository.detailFor(card), throwsA(isA<Exception>()));
    final detail = await repository.detailFor(card);

    expect(detail.cardId, card.id);
    expect(requestCount, 2);
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
                  'cardIds': ['etherfi'],
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
                  'image': '/icons/usdt.png',
                },
              ],
              'chains': [
                {
                  'name': 'Ethereum',
                  'value': r'$1B',
                  'share': 100,
                  'image': '/icons/ethereum.png',
                  'color': '#6F7CF9',
                },
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
                  'logo': 'logo-etherfi',
                  'sevenDayDepositVolume': 7,
                  'thirtyDayDepositVolume': 30,
                  'totalDepositVolume': 100,
                  'onchainTransactionCount': 9,
                  'activeAddressCount': 8,
                },
              ],
            },
            '/api/user-rankings' => {
              'periodLabel': '本月',
              'methodology': '贡献活跃度；会员不加分',
              'updatedAt': '2026-07-22T00:00:00.000Z',
              'items': [
                {
                  'id': 'user-1',
                  'displayName': '卡友一号',
                  'avatarUrl': '/avatars/user-1.png',
                  'monthlyActivityScore': 92,
                  'totalContributionScore': 1330,
                  'acceptedContributions': 18,
                  'activeDays': 23,
                  'membershipTier': 'pro',
                  'isCurrentUser': true,
                },
              ],
            },
            '/api/articles' || '/api/articles/news-one' => {
              'items': request.url.path == '/api/articles'
                  ? [_articleJson]
                  : null,
              'item': request.url.path == '/api/articles/news-one'
                  ? {
                      ..._articleJson,
                      'rawContent': '被压平的纯文本',
                      'bodyHtml':
                          '<h2>第一节</h2><p>第一段<strong>重点</strong></p>'
                          '<p><img src="/body/image.jpg" alt="示意图" /></p>',
                    }
                  : null,
            },
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
          return _jsonResponse(body);
        }),
      );
      final repository = RemoteRankingRepository(client);

      expect((await repository.loadRankings()).single.cardIds, [
        'etherfi-core',
      ]);
      final stablecoins = await repository.loadStablecoins();
      expect(stablecoins.assets.single.id, '1');
      expect(stablecoins.assets.single.chains, isEmpty);
      expect(
        stablecoins.assets.single.imageUrl,
        'https://example.test/icons/usdt.png',
      );
      expect(
        stablecoins.chains.single.imageUrl,
        'https://example.test/icons/ethereum.png',
      );
      expect((await repository.loadStablecoinDetail('1')).history, [1, 2, 3]);
      final metric = (await repository.loadMetrics()).items.single;
      expect(metric.total, 100);
      expect(metric.logo, 'logo-etherfi');
      final rankedUser = (await repository.loadUserRankings()).items.single;
      expect(rankedUser.displayName, '卡友一号');
      expect(rankedUser.avatarUrl, 'https://example.test/avatars/user-1.png');
      expect(rankedUser.isPro, isTrue);
      expect(rankedUser.isCurrentUser, isTrue);
      final article = (await repository.loadArticles()).single;
      expect(article.article.id, 'news-one');
      expect(article.coverImageUrl, 'https://example.test/covers/news.jpg');
      expect(
        article.article.coverImageUrl,
        'https://example.test/covers/news.jpg',
      );
      expect(article.category, ArticleFeedCategory.news);
      final detail = (await repository.loadArticle('news-one')).article;
      expect(detail.markdown, contains('## 第一节'));
      expect(detail.markdown, contains('**重点**'));
      expect(detail.markdown, contains('https://example.test/body/image.jpg'));
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
  'coverImageUrl': '/covers/news.jpg',
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
