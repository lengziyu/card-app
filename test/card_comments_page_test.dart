import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/data/card_comment_repository.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/presentation/card_comments_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('preview disappears completely when comments are disabled', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': false,
            'writeEnabled': false,
            'total': 0,
            'items': const [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardCommentPreview(
            card: localCardCatalog.first,
            repository: CardCommentRepository(client),
            signedIn: false,
            onLoginRequired: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-comment-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview shows useful fields and opens the dedicated page', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': true,
            'total': 1,
            'items': [
              {
                'id': 'comment-1',
                'cardId': localCardCatalog.first.id,
                'body': '线下支付成功率不错。',
                'status': 'published',
                'likeCount': 6,
                'liked': false,
                'isMine': false,
                'createdAt': '2026-09-01T08:00:00.000Z',
                'author': {'displayName': '真实用户'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardCommentPreview(
            card: localCardCatalog.first,
            repository: CardCommentRepository(client),
            signedIn: true,
            onLoginRequired: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('卡友讨论'), findsOneWidget);
    expect(find.text('线下支付成功率不错。'), findsOneWidget);
    expect(find.text('有帮助 6'), findsOneWidget);
    await tester.tap(find.byKey(const Key('card-comments-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-comments-page')), findsOneWidget);
    expect(
      find.byKey(Key('card-comment-artwork-${localCardCatalog.first.id}')),
      findsOneWidget,
    );
    expect(find.text('1 条公开评论'), findsOneWidget);
    expect(find.byKey(const Key('card-comment-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only rollout does not expose write interactions', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': false,
            'total': 1,
            'items': [
              {
                'id': 'comment-readonly',
                'cardId': localCardCatalog.first.id,
                'body': '只读灰度评论。',
                'status': 'published',
                'likeCount': 2,
                'liked': false,
                'isMine': false,
                'createdAt': '2026-09-01T08:00:00.000Z',
                'author': {'displayName': '只读用户'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: true,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('只读灰度评论。'), findsOneWidget);
    expect(find.byKey(const Key('card-comment-input')), findsNothing);
    expect(find.text('有帮助 2'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets(
    'initial failure renders a retry state without breaking the card',
    (tester) async {
      AppColors.configure(Brightness.light);
      var requests = 0;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          requests += 1;
          if (requests == 1) {
            return http.Response(
              jsonEncode({'code': 'TEMPORARY', 'message': '暂时不可用'}),
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'enabled': true,
              'writeEnabled': false,
              'total': 0,
              'items': const [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: CardCommentsPage(
            card: localCardCatalog.first,
            repository: CardCommentRepository(client),
            signedIn: false,
            onLoginRequired: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂时无法加载评论'), findsOneWidget);
      expect(find.byKey(const Key('card-comments-retry')), findsOneWidget);
      expect(find.text(localCardCatalog.first.name), findsOneWidget);

      await tester.tap(find.byKey(const Key('card-comments-retry')));
      await tester.pumpAndSettle();
      expect(find.text('还没有公开评论'), findsOneWidget);
      expect(requests, 2);
    },
  );

  testWidgets('comment page follows the app English locale', (tester) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': false,
            'total': 0,
            'items': const [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [AppLocalizations.delegate],
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: false,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community discussion'), findsOneWidget);
    expect(find.text('0 public comments'), findsOneWidget);
    expect(find.text('No public comments yet'), findsOneWidget);
  });

  testWidgets('comment page stays usable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppColors.configure(Brightness.dark);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': true,
            'total': 1,
            'items': [
              {
                'id': 'comment-narrow',
                'cardId': localCardCatalog.first.id,
                'body': '这是一条用于验证窄屏、大字号和深色主题布局的较长评论内容。',
                'status': 'pending',
                'likeCount': 128,
                'liked': false,
                'isMine': true,
                'createdAt': '2026-09-01T08:00:00.000Z',
                'author': {'displayName': '一位名字比较长的真实用户'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: true,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 条公开评论'), findsOneWidget);
    expect(find.text('最有帮助'), findsOneWidget);
    expect(find.byKey(const Key('card-comment-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the composer when pre-publication moderation is off', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'item': {
                'id': 'comment-published',
                'cardId': localCardCatalog.first.id,
                'body': '默认直接公开的真实体验。',
                'status': 'published',
                'likeCount': 0,
                'liked': false,
                'isMine': true,
                'createdAt': '2026-09-02T08:00:00.000Z',
                'author': {'displayName': '卡友'},
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': true,
            'moderationRequired': false,
            'total': 0,
            'items': const [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: true,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-comment-input')), findsNothing);
    expect(find.byKey(const Key('comment-safety-center')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks an author and manages the block in the safety center', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': true,
            'moderationRequired': true,
            'total': 1,
            'items': [
              {
                'id': 'comment-to-block',
                'cardId': localCardCatalog.first.id,
                'body': '不想再看到该作者的内容。',
                'status': 'published',
                'likeCount': 0,
                'liked': false,
                'isMine': false,
                'createdAt': '2026-09-02T08:00:00.000Z',
                'author': {
                  'displayName': '待屏蔽用户',
                  'blockingKey': 'safe-public-blocking-key',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: true,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('屏蔽该用户'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '屏蔽'));
    await tester.pumpAndSettle();

    expect(find.text('不想再看到该作者的内容。'), findsNothing);
    await tester.tap(find.byKey(const Key('comment-safety-center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comment-safety-sheet')), findsOneWidget);
    expect(find.text('待屏蔽用户'), findsOneWidget);
    expect(find.text('取消屏蔽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reporting immediately hides the reported comment', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    var reportRequests = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/reports')) {
          reportRequests += 1;
          return http.Response(
            jsonEncode({'message': '举报已提交'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'enabled': true,
            'writeEnabled': true,
            'moderationRequired': true,
            'total': 1,
            'items': [
              {
                'id': 'comment-to-report',
                'cardId': localCardCatalog.first.id,
                'body': '包含需要举报的内容。',
                'status': 'published',
                'likeCount': 0,
                'liked': false,
                'isMine': false,
                'createdAt': '2026-09-02T08:00:00.000Z',
                'author': {
                  'displayName': '被举报用户',
                  'blockingKey': 'reported-author-key',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: CardCommentsPage(
          card: localCardCatalog.first,
          repository: CardCommentRepository(client),
          signedIn: true,
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报评论'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('骚扰或不友善内容'));
    await tester.pumpAndSettle();

    expect(reportRequests, 1);
    expect(find.text('包含需要举报的内容。'), findsNothing);
    expect(find.text('举报已提交，已隐藏这条评论'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
