import 'dart:convert';
import 'dart:typed_data';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/pro/data/bill_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requires an account token before uploading a bill image', () async {
    var requested = false;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    final repository = BillAnalysisRepository(
      client,
      accessTokenProvider: () async => null,
    );

    await expectLater(
      repository.analyze(
        imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        mimeType: 'image/jpeg',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'UNAUTHORIZED',
        ),
      ),
    );
    expect(requested, isFalse);
    client.close();
  });

  test('uploads the selected image and parses structured analysis', () async {
    late http.Request captured;
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return _jsonResponse({
          'analysis': {
            'extraction': {
              'provider': 'MEXC',
              'cardName': 'MEXC Card',
              'status': 'success',
              'transactionAt': '2026-07-20 18:51:25',
              'original': {'amount': '25', 'currency': 'CNY'},
              'settlement': {'amount': '3.73', 'currency': 'USD'},
              'deduction': {'amount': '3.7677', 'currency': 'USDT'},
              'fees': <Object?>[],
              'exchangeRates': [
                {'from': 'CNY', 'to': 'USD', 'rate': '0.1492'},
                {'from': 'USD', 'to': 'USDT', 'rate': '1.0102'},
              ],
              'cardLast4': '0348',
              'confidence': 0.96,
              'needsReview': <Object?>[],
            },
            'metrics': {
              'effectiveDeductionPerOriginal': '0.150708',
              'effectiveRatePair': 'USDT/CNY',
              'internalExpectedDeduction': '3.768046',
              'internalRoundingDifference': '-0.000346',
              'declaredFeesInDeductionCurrency': '0',
              'deductionCurrency': 'USDT',
              'marketLoss': null,
              'marketLossRate': null,
              'benchmarkStatus': 'not_available',
            },
            'disclaimer': '请核对识别结果。',
          },
        });
      }),
    );
    final repository = BillAnalysisRepository(
      client,
      accessTokenProvider: () async => 'short-lived-token',
    );

    final analysis = await repository.analyze(
      imageBytes: bytes,
      mimeType: 'image/png',
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/pro/bill-analysis');
    expect(captured.headers['authorization'], 'Bearer short-lived-token');
    expect(body['mimeType'], 'image/png');
    expect(body['imageBase64'], base64Encode(bytes));
    expect(body['aiDataConsent'], {
      'granted': true,
      'version': '2026-08-18',
      'provider': 'openai',
    });
    expect(analysis.extraction.provider, 'MEXC');
    expect(analysis.extraction.original.label, '25 CNY');
    expect(analysis.extraction.exchangeRates, hasLength(2));
    expect(analysis.metrics.internalRoundingDifference, '-0.000346');
    expect(analysis.metrics.benchmarkStatus, 'not_available');
    client.close();
  });
}

http.Response _jsonResponse(Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
