import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/profile/data/remote_user_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads and saves authenticated card, article and feedback data',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (request.method == 'GET' && path == '/api/user/card-state') {
            return _json({
              'myCardIds': ['redotpay'],
              'favoriteIds': ['bybit'],
              'recentIds': ['redotpay'],
            });
          }
          if (request.method == 'GET' && path == '/api/user/article-state') {
            return _json({
              'favoriteArticleIds': ['guide-one'],
            });
          }
          if (request.method == 'GET' && path == '/api/user/submissions') {
            return _json({
              'items': [
                {
                  'id': 'sub-1',
                  'category': 'correction',
                  'description': '这张卡片的费用资料已经变化。',
                  'createdAt': '2026-07-23T00:00:00.000Z',
                  'updatedAt': '2026-07-24T02:00:00.000Z',
                  'status': 'in_review',
                  'statusMessage': '正在核对官方费用页面。',
                  'adminReply': '感谢反馈，资料团队正在复核。',
                  'repliedAt': '2026-07-24T02:00:00.000Z',
                },
              ],
            });
          }
          if (request.method == 'POST' && path == '/api/submissions/messages') {
            return _json({
              'id': 'sub-2',
              'category': 'message',
              'description': '第二条建议。',
              'createdAt': '2026-07-23T01:00:00.000Z',
            }, status: 201);
          }
          return _json({});
        }),
      );
      addTearDown(client.close);
      final repository = RemoteUserDataRepository(
        client,
        accessTokenProvider: () async => 'access-token',
      );

      final cardState = await repository.loadCardState();
      final articles = await repository.loadArticleFavorites();
      final submissions = await repository.loadSubmissions();
      await repository.saveCardState(cardState);
      await repository.saveArticleFavorites(articles);
      final created = await repository.createSubmission(
        const LocalSubmissionDraft(
          category: LocalSubmissionCategory.message,
          description: '第二条建议。',
        ),
      );

      expect(cardState.addedCardIds, ['redotpay']);
      expect(articles, ['guide-one']);
      expect(submissions.single.id, 'sub-1');
      expect(submissions.single.status, LocalSubmissionStatus.reviewing);
      expect(submissions.single.statusNote, '正在核对官方费用页面。');
      expect(submissions.single.adminReply, '感谢反馈，资料团队正在复核。');
      expect(
        submissions.single.lastActivityAt,
        DateTime.parse('2026-07-24T02:00:00.000Z'),
      );
      expect(created.id, 'sub-2');
      expect(created.status, LocalSubmissionStatus.received);
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer access-token',
        ),
        isTrue,
      );
      expect(
        requests.map((request) => request.url.path),
        containsAll([
          '/api/user/card-state',
          '/api/user/article-state',
          '/api/user/submissions',
          '/api/submissions/messages',
        ]),
      );
    },
  );

  test(
    'does not send personal data without a verified-session token',
    () async {
      final client = ApiClient(baseUrl: 'https://example.test');
      addTearDown(client.close);
      final repository = RemoteUserDataRepository(
        client,
        accessTokenProvider: () async => null,
      );

      await expectLater(
        repository.loadCardState,
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'UNAUTHORIZED',
          ),
        ),
      );
    },
  );

  test('uses the captured token instead of a later account token', () async {
    String? authorization;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        authorization = request.headers['authorization'];
        return _json({
          'myCardIds': <String>[],
          'favoriteIds': <String>[],
          'recentIds': <String>[],
        });
      }),
    );
    addTearDown(client.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'new-account-token',
    );

    await repository.loadCardState(accessToken: 'captured-account-token');

    expect(authorization, 'Bearer captured-account-token');
  });

  test('submits a free-form community experience for moderation', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return _json({
          'id': 'tip-1',
          'category': 'tip',
          'subject': '费用核对技巧',
          'description': '支付前核对完整费用链路。',
          'status': 'received',
          'createdAt': '2026-07-26T08:00:00.000Z',
        }, status: 201);
      }),
    );
    addTearDown(client.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'access-token',
    );

    final created = await repository.createSubmission(
      const LocalSubmissionDraft(
        category: LocalSubmissionCategory.tip,
        subject: '费用核对技巧',
        description: '支付前核对完整费用链路。',
        cardId: 'card-1',
        cardName: '示例卡',
        publishAnonymously: true,
      ),
    );

    expect(captured?.url.path, '/api/submissions/tips');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['subject'], '费用核对技巧');
    expect(body['description'], '支付前核对完整费用链路。');
    expect(body['cardId'], 'card-1');
    expect(body, isNot(contains('steps')));
    expect(body['publishAnonymously'], isTrue);
    expect(created.category, LocalSubmissionCategory.tip);
    expect(created.status, LocalSubmissionStatus.received);
  });

  test('rejects community experiences longer than 2000 characters', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requestCount++;
        return _json({});
      }),
    );
    addTearDown(client.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'access-token',
    );

    await expectLater(
      () => repository.createSubmission(
        LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          subject: '费用核对技巧',
          description: List.filled(2001, '字').join(),
          cardId: 'card-1',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_TIP_DESCRIPTION',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  test('requires a title for community experiences', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requestCount++;
        return _json({});
      }),
    );
    addTearDown(client.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'access-token',
    );

    await expectLater(
      () => repository.createSubmission(
        const LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          description: '支付前核对完整费用链路。',
          cardId: 'card-1',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'TIP_TITLE_REQUIRED',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  test('reports when the production tip JSON route is unavailable', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => _json({'message': 'Not found'}, status: 404),
      ),
    );
    addTearDown(client.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'access-token',
    );

    await expectLater(
      () => repository.createSubmission(
        const LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          subject: '费用核对技巧',
          description: '支付前核对完整费用链路。',
          cardId: 'card-1',
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'TIP_API_UNAVAILABLE')
            .having((error) => error.message, 'message', '技巧投稿服务尚未完成更新，请稍后再试'),
      ),
    );
  });

  test('reports when multipart tips are parsed as JSON', () async {
    final uploadClient = MockClient(
      (_) async => _json({
        'code': 'INVALID_JSON',
        'message': 'JSON 请求格式不正确',
      }, status: 400),
    );
    final client = ApiClient(baseUrl: 'https://example.test');
    addTearDown(client.close);
    addTearDown(uploadClient.close);
    final repository = RemoteUserDataRepository(
      client,
      accessTokenProvider: () async => 'access-token',
      uploadClient: uploadClient,
    );

    await expectLater(
      () => repository.createSubmission(
        LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          subject: '钱包绑定步骤',
          description: '用图片说明钱包绑定入口。',
          cardId: 'card-1',
          images: [
            LocalSubmissionImage(
              bytes: base64Decode('AQID'),
              fileName: 'wallet-step.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'TIP_API_UNAVAILABLE',
        ),
      ),
    );
  });

  test(
    'uploads community tip images as authenticated multipart data',
    () async {
      http.Request? captured;
      final uploadClient = MockClient((request) async {
        captured = request;
        return _json({
          'id': 'tip-with-images',
          'category': 'tip',
          'subject': '钱包绑定步骤',
          'description': '用两张图片说明钱包绑定入口。',
          'status': 'received',
          'createdAt': '2026-07-26T09:00:00.000Z',
        }, status: 201);
      });
      final client = ApiClient(baseUrl: 'https://example.test');
      addTearDown(client.close);
      addTearDown(uploadClient.close);
      final repository = RemoteUserDataRepository(
        client,
        accessTokenProvider: () async => 'access-token',
        uploadClient: uploadClient,
      );

      final created = await repository.createSubmission(
        LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          subject: '钱包绑定步骤',
          description: '用两张图片说明钱包绑定入口。',
          cardId: 'card-1',
          cardName: '示例卡',
          images: [
            LocalSubmissionImage(
              bytes: base64Decode('AQID'),
              fileName: 'wallet-step.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.path, '/api/submissions/tips');
      expect(captured?.headers['authorization'], 'Bearer access-token');
      expect(
        captured?.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final multipartBody = utf8.decode(
        captured!.bodyBytes,
        allowMalformed: true,
      );
      expect(multipartBody, contains('name="images"'));
      expect(multipartBody, contains('filename="wallet-step.png"'));
      expect(multipartBody, contains('name="description"'));
      expect(multipartBody, contains('name="subject"'));
      expect(multipartBody, contains('name="title"'));
      expect(multipartBody, isNot(contains('name="steps"')));
      expect(created.id, 'tip-with-images');
    },
  );
}

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
