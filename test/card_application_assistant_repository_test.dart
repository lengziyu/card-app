import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/market/data/card_application_assistant_repository.dart';
import 'package:cardfi/features/market/domain/card_application_assistant.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const profile = CardApplicationProfile(
    cardId: 'redotpay',
    residence: '中国大陆',
    residenceCountryCode: 'CN',
    applicantType: '个人申请',
    document: '护照',
    stage: '准备申请',
    language: 'zh-CN',
    question: '需要准备哪些材料？',
  );

  test('requires a verified-session token before requesting assistance', () {
    final client = ApiClient(baseUrl: 'https://example.test');
    addTearDown(client.close);
    final repository = CardApplicationAssistantRepository(
      client,
      accessTokenProvider: () async => null,
    );

    expectLater(
      () => repository.prepare(profile),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'UNAUTHORIZED',
        ),
      ),
    );
  });

  test('blocks sensitive free text before making a network request', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final repository = CardApplicationAssistantRepository(
      client,
      accessTokenProvider: () async => 'session-token',
    );

    await expectLater(
      () => repository.prepare(
        const CardApplicationProfile(
          cardId: 'redotpay',
          residence: '中国大陆',
          applicantType: '个人申请',
          document: '护照',
          stage: '准备申请',
          language: 'zh-CN',
          question: '我的验证码是 123456，帮我确认',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SENSITIVE_INPUT',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  test('sends a minimal profile and parses traceable sources', () async {
    late http.Request request;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'assistant': {
              'summary': '先确认地区与身份要求。',
              'sourceMode': 'mixed',
              'checklist': [
                {
                  'title': '核对开放地区',
                  'detail': '查看项目文章与官方说明。',
                  'sourceIds': ['open-card-guide', 'issuer-help'],
                },
              ],
              'warnings': ['不保证审核结果。'],
              'unknowns': ['当前排队时间。'],
              'nextSteps': ['打开官方页面。'],
              'sources': [
                {
                  'id': 'open-card-guide',
                  'type': 'project_article',
                  'title': '开卡材料指南',
                  'url': 'https://example.test/articles/open-card-guide',
                  'updatedAt': '2026-07-23T00:00:00.000Z',
                },
              ],
              'disclaimer': '仅供资料准备参考。',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final repository = CardApplicationAssistantRepository(
      client,
      accessTokenProvider: () async => 'session-token',
    );

    final result = await repository.prepare(profile);

    expect(request.url.path, ProConfig.applicationAssistantPath);
    expect(request.headers['authorization'], 'Bearer session-token');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['profile']['cardId'], 'redotpay');
    expect(body['profile']['residenceCountryCode'], 'CN');
    expect(body['profile']['question'], '需要准备哪些材料？');
    expect(body['profile'].containsKey('documentNumber'), isFalse);
    expect(body['aiDataConsent'], {
      'granted': true,
      'version': '2026-08-18',
      'provider': 'alibaba-cloud-bailian',
    });
    expect(result.sourceMode, 'mixed');
    expect(result.checklist.single.sourceIds, contains('open-card-guide'));
    expect(result.sources.single.isProjectArticle, isTrue);
  });

  test('maps a missing deployed route to a readable service message', () async {
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
    addTearDown(client.close);
    final repository = CardApplicationAssistantRepository(
      client,
      accessTokenProvider: () async => 'session-token',
    );

    await expectLater(
      () => repository.prepare(profile),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'SERVICE_UNAVAILABLE')
            .having(
              (error) => error.message,
              'message',
              'AI 协助开卡服务尚未部署，请稍后再试。',
            ),
      ),
    );
  });

  test(
    'normalizes structured result items and hides internal KYC fields',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'assistant': {
                'summary': '已整理 Ether.fi 的公开申请要求。',
                'sourceMode': 'official_web',
                'checklist': [
                  {
                    'title': '确认地区',
                    'detail':
                        '请查看官方说明（mainlandAvailability: unavailable, requiresOverseasAddress: required）。',
                    'sourceIds': ['official:etherfi-core'],
                  },
                ],
                'warnings': [
                  {'title': '地区限制', 'detail': '中国大陆不在支持地区内。'},
                  {'unexpected': 'never render a Dart map'},
                  '[object Object]',
                ],
                'unknowns': [
                  {'question': '审核时间', 'answer': '请向发行方确认。'},
                ],
                'nextSteps': [
                  {'action': '打开发行方官方页面。'},
                ],
                'sources': [
                  {
                    'id': 'official:etherfi-core',
                    'type': 'official_web',
                    'title': 'Ether.fi Cash',
                    'url': 'https://www.ether.fi/cash',
                  },
                ],
                'disclaimer': '仅供参考。',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);
      final repository = CardApplicationAssistantRepository(
        client,
        accessTokenProvider: () async => 'session-token',
      );

      final result = await repository.prepare(profile);

      expect(result.checklist.single.detail, '请查看官方说明。');
      expect(result.warnings, ['地区限制：中国大陆不在支持地区内。']);
      expect(result.unknowns, ['审核时间：请向发行方确认。']);
      expect(result.nextSteps, ['打开发行方官方页面。']);
      expect(
        [
          result.summary,
          ...result.checklist.map((item) => item.detail),
          ...result.warnings,
          ...result.unknowns,
          ...result.nextSteps,
        ].join(' '),
        isNot(contains('[object Object]')),
      );
    },
  );
}
