import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/data/remote_card_catalog.dart';
import 'package:cardfi/features/catalog/data/remote_card_details.dart';
import 'package:cardfi/features/catalog/data/remote_global_account_catalog.dart';
import 'package:cardfi/features/catalog/data/remote_catalog_settings.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/ranking/data/remote_ranking_repository.dart';
import 'package:cardfi/features/ranking/domain/ranking_data.dart';
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
                'kycSummary': '护照',
                'cashbackRate': '2%',
                'updatedAt': '2026-07-21T12:24:41.776Z',
              },
            ],
          },
          '/api/global-accounts' => {
            'items': [
              {
                'id': 'wise-account',
                'name': 'Wise Account',
                'provider': 'Wise',
                'accountType': 'multiCurrency',
                'taglineZh': '多币种持有 · 收款 · 换汇',
                'coverImageSrc': '/accounts/wise.webp',
                'logoImageSrc': '/accounts/wise-logo.webp',
                'coverColors': ['#9FE870', '#163300'],
                'supportedCurrencies': ['GBP', 'EUR', 'USD'],
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
    expect(card.kycSummary, '护照');
    expect(card.cashbackRate, '2%');
    expect(card.updatedAt, DateTime.utc(2026, 7, 21, 12, 24, 41, 776));
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').isGlobalAccount,
      isTrue,
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').coverImageUrl,
      'https://example.test/accounts/wise.webp',
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').chinaKycStatus,
      'available',
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').logoImageUrl,
      'https://example.test/accounts/wise-logo.webp',
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').transferCurrencies,
      ['EUR', 'GBP', 'USD'],
    );
    expect(
      cards.singleWhere((card) => card.id == 'wise-account').isCryptoRelated,
      isFalse,
    );
    expect(cards.where((card) => card.isGlobalAccount).map((card) => card.id), [
      'wise-account',
    ]);
    expect(cards.where((card) => card.id == 'wise-account'), hasLength(1));
    expect(await settings.loadHomeDefaultCardIds(), ['card-1']);
    expect(await settings.loadListCardOrder(), ['card-2', 'card-1']);
    client.close();
  });

  test('maps a crypto platform as a crypto-related global account', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path != '/api/global-accounts') {
          throw StateError('Unexpected request: ${request.url}');
        }
        return _jsonResponse({
          'items': [
            {
              'id': 'kraken',
              'name': 'Kraken',
              'provider': 'Kraken',
              'accountType': 'cryptoPlatform',
              'taglineZh': '加密资产平台',
              'coverColors': ['#5741D9'],
            },
          ],
        });
      }),
    );

    final account = (await RemoteGlobalAccountCatalogRepository(
      client,
    ).loadCards()).single;
    expect(account.isCryptoRelated, isTrue);
    expect(account.accountType, 'cryptoPlatform');
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
        containsAll([
          'card-1',
          'wise-account',
          'revolut-personal-account',
          'payoneer-account',
          'airwallex-global-account',
          'worldfirst-world-account',
        ]),
      );
      client.close();
    },
  );

  test('keeps a card and global account that share an ID', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/cards' => {
            'items': [
              {
                'id': 'wirex',
                'name': 'Wirex Card',
                'issuer': 'Wirex',
                'category': 'U卡',
              },
            ],
          },
          '/api/global-accounts' => {
            'items': [
              {
                'id': 'wirex',
                'name': 'Wirex Account',
                'provider': 'Wirex',
                'accountType': 'cryptoIntegratedAccount',
              },
            ],
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return _jsonResponse(body);
      }),
    );

    final items = await RemoteMarketCatalogRepository(
      cards: RemoteCardCatalogRepository(client),
      globalAccounts: RemoteGlobalAccountCatalogRepository(client),
    ).loadCards();

    expect(items.where((item) => item.id == 'wirex'), hasLength(2));
    expect(
      items.where((item) => item.id == 'wirex').map((item) => item.kind),
      containsAll([CatalogItemKind.card, CatalogItemKind.globalAccount]),
    );
    client.close();
  });

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
    expect(detail.supportedCurrencies, ['EUR', 'GBP', 'USD']);
    final english = await RemoteCardDetailRepository(
      client,
    ).detailFor(account, locale: const Locale('en'));
    expect(english.region, 'Available to mainland China residents');
    expect(english.features.single.text, contains('Receive account details'));
    client.close();
  });

  test(
    'uses bundled global-account detail while its endpoint is absent',
    () async {
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
        id: 'airwallex-global-account',
        name: 'Airwallex Global Account',
        issuer: 'Airwallex',
        category: CardCategory.bankAccount,
        label: '企业账户 · 全球收款',
        tint: 0xFF4B3DAA,
        kind: CatalogItemKind.globalAccount,
      );

      final detail = await RemoteCardDetailRepository(
        client,
      ).detailFor(account);

      expect(detail.cardId, 'airwallex-global-account');
      expect(detail.chinaKyc?.status, ChinaKycStatus.restricted);
      expect(detail.sourceLabel, contains('Airwallex 官方产品页'));
      client.close();
    },
  );

  test('maps a remote card detail', () async {
    Uri? requestedUri;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse({
          'item': {'id': 'card-1'},
          'detail': {
            'rating': 4.3,
            'reviews': 420,
            'tags': ['返现', 'Ranked+ D级'],
            'region': '全球',
            'funding': 'USDC',
            'speed': '开放申请',
            'benefits': [
              {'icon': 'shield', 'text': '安全权益'},
              {'icon': 'wallet', 'text': '入金方式：Crypto、Bank transfer'},
              {
                'icon': 'market',
                'text': r'返现限制：• Lite: 2% cashback (max $250 per month)',
              },
            ],
            'fees': [
              {'label': '年费', 'value': '按官网'},
              {
                'label': 'Ranked+ 月费起',
                'value':
                    r'$0.00；One time $10 activation fee for virtual card, and $100 for physical card.',
              },
              {
                'label': 'Ranked+ ATM 取现费',
                'value':
                    r'2%；All ATM withdrawals incur 2% fee; daily limit $250 USD, max 3 attempts per 24h',
              },
            ],
            'kycFact': {'detailZh': '需要护照'},
            'openingRequirement': {
              'requirements': {
                'inviteCode': 'notRequired',
                'idCard': 'notRequired',
                'passport': 'required',
                'overseasAddressProof': 'required',
                'overseasPhone': 'unknown',
              },
              'summaryZh': '护照 + 海外证明',
              'summaryEn': 'Passport + overseas proof',
              'sourceName': '官方帮助中心',
              'checkedAt': '2026-08-10',
            },
            'paymentSupport': {
              'applePay': {'status': 'supported'},
              'googlePay': {'status': 'conditional'},
            },
            'todeyFacts': {
              'registerFee': 'FREE',
              'annualFee': 'NO ANNUAL FEE',
              'fxFee': '0%',
              'description': 'A sourced card overview.',
              'fetchedAt': '2026-07-25T00:00:00.000Z',
            },
            'chinaKyc': {
              'status': 'restricted',
              'documentSummary': '护照与地址证明以流程为准',
              'note': '功能需按中国大陆居住地核验',
              'sourceUrl': 'https://example.test/china-kyc',
              'checkedAt': '2026-07-22T00:00:00.000Z',
            },
          },
        });
      }),
    );
    const card = CardSummary(
      id: 'card-1',
      name: 'Card One',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: '',
      tint: 0xFF112233,
    );

    final detail = await RemoteCardDetailRepository(
      client,
      contentPlatform: PublicContentPlatform.android,
    ).detailFor(card);

    expect(detail.rating, 4.3);
    expect(detail.reviewCount, 420);
    expect(detail.region, '全球');
    expect(detail.features.single.text, '安全权益');
    expect(detail.tags, contains('评级：D'));
    expect(detail.tags.join(), isNot(contains('Ranked+')));
    expect(detail.rules, hasLength(2));
    expect(detail.rules.first.value, '加密资产、银行转账');
    expect(detail.rules.last.value, r'• Lite：2% 返现（每月最高 $250）');
    expect(detail.fees.singleWhere((fee) => fee.label == '年费').value, '免年费');
    expect(detail.fees.singleWhere((fee) => fee.label == '开卡费').value, '免费');
    expect(detail.fees.singleWhere((fee) => fee.label == '月费').value, r'$0.00');
    expect(
      detail.fees.singleWhere((fee) => fee.label == '月费').note,
      r'虚拟卡一次性激活费 $10；实体卡一次性激活费 $100。',
    );
    expect(
      detail.fees.singleWhere((fee) => fee.label == '取现手续费').note,
      r'每日 ATM 取现限额 $250 USD，24 小时最多 3 次。',
    );
    expect(detail.note, isNot(contains('A sourced card overview.')));
    expect(detail.sourceLabel, isNot(contains('TODEY')));
    expect(detail.paymentChannels, contains(PaymentChannel.applePay));
    expect(detail.paymentChannels, isNot(contains(PaymentChannel.googlePay)));
    expect(detail.chinaKyc?.status, ChinaKycStatus.restricted);
    expect(detail.chinaKyc?.checkedAt, DateTime.utc(2026, 7, 22));
    expect(detail.openingRequirements?.summary, '护照 + 海外证明');
    expect(
      detail.openingRequirements?.stateFor(OpeningRequirementKind.passport),
      OpeningRequirementState.required,
    );
    expect(
      detail.openingRequirements?.stateFor(
        OpeningRequirementKind.overseasPhone,
      ),
      OpeningRequirementState.unknown,
    );
    expect(requestedUri?.queryParameters['platform'], 'android');
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

  test('requests and consumes English card and article content', () async {
    final requestedLocales = <String?>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedLocales.add(request.url.queryParameters['locale']);
        expect(request.headers['accept-language'], 'en-US');
        return switch (request.url.path) {
          '/api/cards/card-en' => _jsonResponse({
            'detail': {
              'tags': ['返现'],
              'tagsEn': ['Cashback'],
              'region': '全球',
              'regionEn': r'Worldwide\nAvailability varies by region.',
              'funding': '加密资产',
              'fundingEn': 'Crypto assets',
              'speed': '开放申请',
              'speedEn': 'Applications open',
              'benefits': [
                {
                  'icon': 'market',
                  'text': '返现规则：按等级',
                  'textEn': 'Cashback rules: By tier',
                },
              ],
              'fees': [
                {
                  'label': '年费',
                  'labelEn': 'Annual fee',
                  'value': '免费',
                  'valueEn': 'Free',
                },
              ],
              'kycFact': {
                'detailZh': '以流程为准',
                'detailEn': 'Check the application flow.',
              },
              'note': '以官网为准',
              'noteEn': 'Check the official website.',
            },
          }),
          '/api/articles' => _jsonResponse({
            'items': [
              {
                'slug': 'english-article',
                'category': 'news',
                'title': '中文标题',
                'titleEn': 'English title',
                'summary': '中文摘要',
                'summaryEn': 'English summary',
                'rawContent': '中文正文',
                'rawContentEn': 'English body',
                'tags': ['资讯'],
                'tagsEn': ['News'],
              },
            ],
          }),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );
    addTearDown(client.close);
    const locale = Locale('en', 'US');
    const card = CardSummary(
      id: 'card-en',
      name: 'Card',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: '',
      tint: 0xFF112233,
    );

    final detail = await RemoteCardDetailRepository(
      client,
    ).detailFor(card, locale: locale);
    final article = (await RemoteRankingRepository(
      client,
    ).loadArticles(locale: locale)).single.article;

    expect(detail.region, 'Worldwide\nAvailability varies by region.');
    expect(detail.funding, 'Crypto assets');
    expect(detail.availability, 'Applications open');
    expect(detail.tags, ['Cashback']);
    expect(detail.rules.single.value, 'By tier');
    expect(detail.fees.single.label, 'Annual fee');
    expect(detail.fees.single.value, 'Free');
    expect(article.title, 'English title');
    expect(article.summary, 'English summary');
    expect(article.markdown, 'English body');
    expect(article.tags, ['News']);
    expect(requestedLocales, everyElement('en-US'));
  });

  test(
    'consumes a non-English translations map without English fallback',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.queryParameters['locale'], 'ja');
          expect(request.headers['accept-language'], 'ja');
          return switch (request.url.path) {
            '/api/cards/card-ja' => _jsonResponse({
              'detail': {
                'region': '全球',
                'benefits': [
                  {
                    'icon': 'shield',
                    'text': '中文权益',
                    'translations': {
                      'ja': {'text': '日本語の特典'},
                    },
                  },
                ],
                'fees': const [],
                'translations': {
                  'ja': {
                    'tags': ['キャッシュバック'],
                    'region': '世界中で利用可能',
                    'funding': '暗号資産',
                    'speed': '申請受付中',
                    'note': '公式サイトをご確認ください。',
                  },
                },
              },
            }),
            '/api/articles' => _jsonResponse({
              'items': [
                {
                  'slug': 'ja-article',
                  'category': 'news',
                  'title': '中文标题',
                  'summary': '中文摘要',
                  'rawContent': '中文正文',
                  'tags': ['资讯'],
                  'translations': {
                    'ja': {
                      'title': '日本語のタイトル',
                      'summary': '日本語の概要',
                      'rawContent': '日本語の本文',
                      'tags': ['ニュース'],
                    },
                  },
                },
              ],
            }),
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
        }),
      );
      addTearDown(client.close);
      const card = CardSummary(
        id: 'card-ja',
        name: 'Card',
        issuer: 'Issuer',
        category: CardCategory.uCard,
        label: '',
        tint: 0xFF112233,
      );

      final detail = await RemoteCardDetailRepository(
        client,
      ).detailFor(card, locale: const Locale('ja'));
      final article = (await RemoteRankingRepository(
        client,
      ).loadArticles(locale: const Locale('ja'))).single.article;

      expect(detail.region, '世界中で利用可能');
      expect(detail.tags, ['キャッシュバック']);
      expect(detail.features.single.text, '日本語の特典');
      expect(article.title, '日本語のタイトル');
      expect(article.markdown, '日本語の本文');
      expect(article.tags, ['ニュース']);
    },
  );

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
              'items': List.generate(
                21,
                (index) => {
                  'id': 'user-${index + 1}',
                  'displayName': '卡友${index + 1}号',
                  'avatarUrl': '/avatars/user-${index + 1}.png',
                  'monthlyActivityScore': 92 - index,
                  'totalContributionScore': 1330 - index,
                  'acceptedContributions': 18,
                  'activeDays': 23,
                  'membershipTier': index == 0 ? 'pro' : 'free',
                  'isCurrentUser': index == 0,
                },
              ),
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
      final rankedUsers = (await repository.loadUserRankings()).items;
      expect(rankedUsers, hasLength(20));
      final rankedUser = rankedUsers.singleWhere((item) => item.id == 'user-1');
      expect(rankedUser.displayName, '卡友1号');
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

  test('maps reviewed community tips from the public article feed', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => _jsonResponse({
          'items': [
            {
              'slug': 'tip-one',
              'category': 'community-tip',
              'title': '支付技巧',
              'summary': '经过审核的用户经验。',
              'rawContent': '## 操作步骤',
              'author': '匿名卡友',
              'verifiedLabel': '2026-07-26 基础核验',
              'publishedAt': '2026-07-26T00:00:00.000Z',
            },
          ],
        }),
      ),
    );
    addTearDown(client.close);

    final item = (await RemoteRankingRepository(client).loadArticles()).single;

    expect(item.category, ArticleFeedCategory.communityTip);
    expect(item.article.isCommunityTip, isTrue);
    expect(item.article.author, '匿名卡友');
    expect(item.article.verifiedLabel, '2026-07-26 基础核验');
  });
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
