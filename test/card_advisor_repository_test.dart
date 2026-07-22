import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/features/market/data/card_advisor_repository.dart';
import 'package:card_app/features/market/domain/card_advisor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const profile = CardAdvisorProfile(
    residence: '中国大陆',
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
      expect(body['profile'].containsKey('password'), isFalse);
      expect(result.recommendations.single.cardId, 'redotpay');
      client.close();
    },
  );
}
