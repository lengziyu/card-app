import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the live stablecoin USD price for a USD bill', () async {
    final cardApi = ApiClient(
      baseUrl: 'https://card.example',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'updatedAt': '2026-09-01T09:37:16.000Z',
            'assets': [
              {'symbol': 'USDT', 'price': r'$0.999732'},
            ],
          }),
          200,
        ),
      ),
    );
    final fiatApi = ApiClient(
      baseUrl: 'https://fiat.example/v2',
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final repository = BillBenchmarkRepository(cardApi, fiatApiClient: fiatApi);
    addTearDown(cardApi.close);
    addTearDown(fiatApi.close);

    final quote = await repository.loadCurrent(_extraction('USD', 'USDT'));

    expect(quote.rate, '1.00026807');
    expect(quote.sourceLabel, 'DefiLlama');
    expect(quote.rateLabel, '1 USD = 1.00026807 USDT');
  });

  test('combines the current fiat and stablecoin references', () async {
    final cardApi = ApiClient(
      baseUrl: 'https://card.example',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'updatedAt': '2026-09-01T09:37:16.000Z',
            'assets': [
              {'symbol': 'USDT', 'price': r'$0.999732'},
            ],
          }),
          200,
        ),
      ),
    );
    final fiatApi = ApiClient(
      baseUrl: 'https://fiat.example/v2',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'date': '2026-09-01',
            'base': 'CNY',
            'quote': 'USD',
            'rate': 0.14883,
          }),
          request.url.path == '/v2/rate/CNY/USD' ? 200 : 404,
        ),
      ),
    );
    final repository = BillBenchmarkRepository(cardApi, fiatApiClient: fiatApi);
    addTearDown(cardApi.close);
    addTearDown(fiatApi.close);

    final quote = await repository.loadCurrent(_extraction('CNY', 'USDT'));

    expect(quote.rate, '0.1488699');
    expect(quote.sourceLabel, 'Frankfurter / DefiLlama');
  });
}

BillExtraction _extraction(String from, String to) => BillExtraction(
  provider: null,
  cardName: null,
  status: 'success',
  transactionAt: null,
  original: BillMoney(amount: '100', currency: from),
  settlement: const BillMoney(amount: null, currency: null),
  deduction: BillMoney(amount: '101', currency: to),
  cashback: const BillCashback.empty(),
  fees: const [],
  exchangeRates: const [],
  cardLast4: null,
  confidence: 1,
  needsReview: const [],
);
