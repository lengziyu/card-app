import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/market/data/card_advisor_repository.dart';
import 'package:cardfi/features/market/domain/card_advisor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const profile = CardAdvisorProfile(
    residence: '中国大陆',
    residenceCountryCode: 'CN',
    document: '护照',
    useCase: '日常消费',
    kycPreference: '可接受 KYC',
    language: 'en-US',
  );

  test(
    'requires a verified-session access token before sending a profile',
    () async {
      final repository = CardAdvisorRepository(
        ApiClient(baseUrl: 'https://example.test'),
        accessTokenProvider: () async => null,
      );

      await expectLater(
        () => repository.advise(profile),
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

  test(
    'sends the minimal profile and parses only server-selected cards',
    () async {
      late http.Request request;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'advisor': {
                'summary': 'Two public matches were found.',
                'recommendations': [
                  {
                    'cardId': 'redotpay',
                    'reason': 'Matches the selected use case.',
                    'cautions': 'Confirm availability on the official site.',
                  },
                ],
                'nextSteps': ['Check the official terms.'],
                'disclaimer': 'Public information only.',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repository = CardAdvisorRepository(
        client,
        accessTokenProvider: () async => 'session-token',
      );

      final result = await repository.advise(profile);

      expect(request.url.path, CardAdvisorRepository.path);
      expect(request.headers['authorization'], 'Bearer session-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['profile']['language'], 'en-US');
      expect(body['profile']['residenceCountryCode'], 'CN');
      expect(body['profile'].containsKey('password'), isFalse);
      expect(body['aiDataConsent'], {
        'granted': true,
        'version': '2026-08-18',
        'provider': 'alibaba-cloud-bailian',
      });
      expect(result.recommendations.single.cardId, 'redotpay');
      client.close();
    },
  );

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
    final repository = CardAdvisorRepository(
      client,
      accessTokenProvider: () async => 'session-token',
    );

    await expectLater(
      () => repository.advise(profile),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'SERVICE_UNAVAILABLE')
            .having((error) => error.message, 'message', 'AI精选好卡服务尚未部署，请稍后再试。'),
      ),
    );
  });
}
