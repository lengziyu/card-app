import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/data/card_comment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'loads the feature configuration and safe public comment model',
    () async {
      late http.Request request;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'enabled': true,
              'writeEnabled': true,
              'moderationRequired': false,
              'total': 1,
              'nextCursor': 'next-page',
              'items': [
                {
                  'id': 'comment-1',
                  'cardId': 'bybit',
                  'body': '境外消费体验稳定。',
                  'status': 'published',
                  'likeCount': 8,
                  'liked': true,
                  'isMine': false,
                  'createdAt': '2026-09-01T08:00:00.000Z',
                  'author': {
                    'displayName': '认真卡友',
                    'avatarUrl': '/api/uploads/user-avatars/avatar.jpg',
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

      final result = await CardCommentRepository(
        client,
        accessTokenProvider: () async => 'session-token',
      ).load('bybit', sort: 'helpful', limit: 12);

      expect(request.method, 'GET');
      expect(request.url.path, '/api/cards/bybit/comments');
      expect(request.url.queryParameters['sort'], 'helpful');
      expect(request.url.queryParameters['limit'], '12');
      expect(request.headers['authorization'], 'Bearer session-token');
      expect(result.enabled, isTrue);
      expect(result.writeEnabled, isTrue);
      expect(result.moderationRequired, isFalse);
      expect(result.total, 1);
      expect(result.nextCursor, 'next-page');
      expect(result.items.single.author.displayName, '认真卡友');
      expect(
        result.items.single.author.avatarUrl,
        'https://example.test/api/uploads/user-avatars/avatar.jpg',
      );
      expect(result.items.single.likeCount, 8);
      expect(result.items.single.liked, isTrue);
    },
  );

  test('creates a pending comment with account authentication', () async {
    late http.Request request;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'item': {
              'id': 'comment-2',
              'cardId': 'bybit',
              'body': '退款到账用了三个工作日。',
              'status': 'pending',
              'likeCount': 0,
              'liked': false,
              'isMine': true,
              'createdAt': '2026-09-02T00:00:00.000Z',
              'author': {'displayName': '卡友'},
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    final result = await CardCommentRepository(
      client,
      accessTokenProvider: () async => 'session-token',
    ).create('bybit', '退款到账用了三个工作日。');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/cards/bybit/comments');
    expect(request.headers['authorization'], 'Bearer session-token');
    expect(jsonDecode(request.body), {'body': '退款到账用了三个工作日。'});
    expect(result.pending, isTrue);
    expect(result.isMine, isTrue);
  });

  test(
    'legacy comment config keeps moderation enabled during rollout',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'enabled': true,
              'writeEnabled': true,
              'total': 0,
              'items': const [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);

      final result = await CardCommentRepository(client).load('bybit');

      expect(result.moderationRequired, isTrue);
    },
  );

  test(
    'like endpoint sends desired state instead of a non-idempotent toggle',
    () async {
      late http.Request request;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({'id': 'comment-3', 'liked': true, 'likeCount': 9}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final result = await CardCommentRepository(
        client,
        accessTokenProvider: () async => 'session-token',
      ).setLiked('comment-3', true);

      expect(request.method, 'PUT');
      expect(request.url.path, '/api/comments/comment-3/like');
      expect(jsonDecode(request.body), {'liked': true});
      expect(result.liked, isTrue);
      expect(result.likeCount, 9);
    },
  );

  test(
    'persists a blocked author and filters their comments locally',
    () async {
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
                  'id': 'comment-blocked',
                  'cardId': 'bybit',
                  'body': '需要被屏蔽的内容',
                  'status': 'published',
                  'likeCount': 0,
                  'liked': false,
                  'isMine': false,
                  'createdAt': '2026-09-02T00:00:00.000Z',
                  'author': {
                    'displayName': '不友善用户',
                    'blockingKey': 'server-pseudonymous-author-key',
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
      final repository = CardCommentRepository(client);

      final firstLoad = await repository.load('bybit');
      expect(firstLoad.items, hasLength(1));

      await repository.blockAuthor(firstLoad.items.single);
      final blocked = await repository.blockedAuthors();
      final secondLoad = await repository.load('bybit');

      expect(blocked.single.displayName, '不友善用户');
      expect(secondLoad.items, isEmpty);

      await repository.unblockAuthor(blocked.single.key);
      expect((await repository.load('bybit')).items, hasLength(1));

      await repository.hideReportedComment('comment-blocked');
      expect((await repository.load('bybit')).items, isEmpty);
    },
  );
}
