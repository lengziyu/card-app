import 'dart:async';
import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/presentation/ranking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('renders live ranking groups without an unbounded height error', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/rankings' => {
            'groups': [
              {
                'id': 'legendary',
                'name': '夯',
                'cardIds': ['etherfi', 'redotpay'],
              },
            ],
          },
          '/api/stablecoins' => {
            'history': {'30d': <num>[]},
            'assets': <Object?>[],
            'chains': <Object?>[],
          },
          '/api/card-metrics' => {'items': <Object?>[]},
          '/api/articles' => {'items': <Object?>[]},
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankingPage(
            cards: localCardCatalog,
            onOpenCard: (_) {},
            onOpenArticle: (_) {},
            repository: RemoteRankingRepository(client),
            enableRemoteData: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking-live')), findsOneWidget);
    expect(find.byKey(const Key('rank-card-etherfi-core')), findsOneWidget);
    expect(find.byKey(const Key('rank-card-redotpay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-articles')));
    await tester.pumpAndSettle();
    final newsTab = find.byKey(const Key('article-tab-news'));
    final benefitTab = find.byKey(const Key('article-tab-benefit'));
    final openCardTab = find.byKey(const Key('article-tab-openCard'));
    expect(newsTab, findsOneWidget);
    expect(benefitTab, findsOneWidget);
    expect(openCardTab, findsOneWidget);
    expect(tester.getSize(newsTab).height, 30);
    expect(
      tester.getTopLeft(benefitTab).dx - tester.getTopRight(newsTab).dx,
      closeTo(10, .1),
    );

    await tester.tap(benefitTab);
    await tester.pumpAndSettle();
    expect(find.text('暂无福利'), findsOneWidget);
    expect(find.byKey(const Key('article-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('article-empty-glow')), findsOneWidget);
    expect(tester.takeException(), isNull);
    client.close();
  });

  testWidgets('article loading keeps tabs stable and reserves cover geometry', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final articlesReady = Completer<void>();
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/api/articles') {
          await articlesReady.future;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'slug': 'stable-layout',
                  'category': 'news',
                  'title': '资讯列表稳定布局',
                  'summary': '封面加载前后保持同一个画框尺寸。',
                  'coverImageUrl': '/images/wide-cover.jpg',
                  'tags': ['体验'],
                  'publishedAt': '2026-07-20T00:00:00.000Z',
                  'viewCount': 12,
                  'likeCount': 3,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final body = switch (request.url.path) {
          '/api/rankings' => {'groups': <Object?>[]},
          '/api/stablecoins' => {
            'history': {'30d': <num>[]},
            'assets': <Object?>[],
            'chains': <Object?>[],
          },
          '/api/card-metrics' => {'items': <Object?>[]},
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankingPage(
            cards: localCardCatalog,
            onOpenCard: (_) {},
            onOpenArticle: (_) {},
            repository: RemoteRankingRepository(client),
            enableRemoteData: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ranking-tab-articles')));
    await tester.pump(const Duration(milliseconds: 400));

    final newsTab = find.byKey(const Key('article-tab-news'));
    expect(newsTab, findsOneWidget);
    expect(find.byKey(const Key('article-list-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('article-skeleton-card-0')), findsOneWidget);
    final tabTopBeforeLoad = tester.getTopLeft(newsTab).dy;

    articlesReady.complete();
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(const Key('article-list-skeleton')), findsNothing);
    expect(find.byKey(const Key('article-live-list')), findsOneWidget);
    expect(tester.getTopLeft(newsTab).dy, closeTo(tabTopBeforeLoad, .1));
    final cover = find.byKey(const Key('article-cover-frame-stable-layout'));
    expect(cover, findsOneWidget);
    final coverSize = tester.getSize(cover);
    expect(coverSize.width / coverSize.height, closeTo(16 / 9, .01));
    expect(tester.takeException(), isNull);
    client.close();
  });
}
