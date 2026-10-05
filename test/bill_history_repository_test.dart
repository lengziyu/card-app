import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/bill_history_repository.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('normalizes points into cash value in legacy bill records', () {
    final record = BillRecord.fromJson({
      ..._record(revision: 1),
      'recognized': _pointsExtraction(),
      'confirmed': _pointsExtraction(),
      'calculationInputs': {
        'benchmarkRate': '1.3545',
        'cashbackRate': null,
        'cashbackAmount': {'amount': '13.58', 'currency': 'USD'},
      },
      'metrics': {
        'marketLoss': '0.035',
        'marketLossRate': '0.2584',
        'cashbackValue': '13.58',
        'netLoss': '-13.545',
      },
    });

    expect(record.confirmed.cashback.label, '积分现金价值');
    expect(record.confirmed.cashback.amount, '0.1358');
    expect(record.calculationInputs.cashbackRate, isNull);
    expect(record.calculationInputs.cashbackAmount.amount, '0.1358');
    expect(record.metrics.cashbackValue, '0.1358');
    expect(record.metrics.netLoss, '-0.1008');
  });

  test('clears a normalized points value that leaked into advertised rate', () {
    final normalized = {
      ..._pointsExtraction(),
      'cashback': {
        'label': '积分现金价值',
        'rate': '1',
        'amount': '0.1358',
        'currency': 'USD',
      },
    };
    final record = BillRecord.fromJson({
      ..._record(revision: 1),
      'recognized': normalized,
      'confirmed': normalized,
      'calculationInputs': {
        'benchmarkRate': '1.3545',
        'cashbackRate': '0.1358',
        'cashbackAmount': {'amount': '0.1358', 'currency': 'USD'},
      },
      'metrics': {
        'marketLoss': '0.035',
        'cashbackValue': '0.1358',
        'netLoss': '-0.1008',
      },
    });

    expect(record.calculationInputs.cashbackRate, isNull);
    expect(record.calculationInputs.cashbackAmount.amount, '0.1358');
  });

  test(
    'bill history repository creates, lists, updates and deletes records',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return _jsonResponse({'record': _record(revision: 1)}, 201);
          }
          if (request.method == 'GET') {
            return _jsonResponse({
              'records': [_record(revision: 1)],
              'nextCursor': null,
            });
          }
          if (request.method == 'PATCH') {
            return _jsonResponse({'record': _record(revision: 2, bound: true)});
          }
          return http.Response('', 204);
        }),
      );
      final repository = BillHistoryRepository(
        client,
        accessTokenProvider: () async => 'token',
      );
      final analysis = BillAnalysis(
        extraction: BillExtraction.fromJson(_extraction()),
        metrics: BillMetrics.fromJson(const {}),
        disclaimer: '',
      );

      final created = await repository.createDraft(
        analysis,
        benchmarkRate: '1.01',
      );
      final page = await repository.list(limit: 20);
      final updated = await repository.update(
        record: created,
        confirmed: created.confirmed,
        calculationInputs: const BillCalculationInputs(
          benchmarkRate: '1',
          cashbackRate: '2',
          cashbackAmount: BillMoney(amount: null, currency: null),
        ),
        cardBinding: const BillCardBinding(
          cardId: 'card-1',
          cardNameSnapshot: 'Test Card',
        ),
        confirmedByUser: true,
      );
      await repository.delete(updated.id);

      expect(page.records, hasLength(1));
      expect(updated.revision, 2);
      expect(updated.cardBinding.cardId, 'card-1');
      expect(requests.map((request) => request.method), [
        'POST',
        'GET',
        'PATCH',
        'DELETE',
      ]);
      final createBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(createBody['calculationInputs']['cashbackRate'], '2');
      expect(createBody['calculationInputs']['benchmarkRate'], '1.01');
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer token',
        ),
        isTrue,
      );
      final patchBody = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(patchBody['expectedRevision'], 1);
      expect(patchBody['status'], 'confirmed');
      expect(patchBody['calculationInputs']['cashbackRate'], '2');
      client.close();
    },
  );
}

Map<String, dynamic> _extraction() => {
  'provider': 'Test Pay',
  'cardName': 'Test Card',
  'status': 'success',
  'transactionAt': '2026-08-29 23:46:08+08:00',
  'original': {'amount': '100', 'currency': 'USD'},
  'settlement': {'amount': '105', 'currency': 'USD'},
  'deduction': {'amount': '105', 'currency': 'USD'},
  'cashback': {'label': '截图返现', 'rate': '2', 'amount': null, 'currency': null},
  'fees': <Object?>[],
  'exchangeRates': <Object?>[],
  'cardLast4': '1234',
  'confidence': 0.9,
  'needsReview': <Object?>[],
};

Map<String, dynamic> _pointsExtraction() => {
  ..._extraction(),
  'provider': 'Giffgaff',
  'cardName': 'Gate Card',
  'original': {'amount': '10', 'currency': 'GBP'},
  'settlement': {'amount': '13.58', 'currency': 'USD'},
  'deduction': {'amount': '13.58', 'currency': 'USD'},
  'cashback': {
    'label': '获得积分',
    'rate': '0.1358',
    'amount': '13.58',
    'currency': 'USD',
  },
};

Map<String, dynamic> _record({required int revision, bool bound = false}) => {
  'id': 'record-1',
  'status': revision == 1 ? 'draft' : 'confirmed',
  'recognized': _extraction(),
  'confirmed': _extraction(),
  'calculationInputs': {
    'benchmarkRate': revision == 1 ? null : '1',
    'cashbackRate': revision == 1 ? null : '2',
    'cashbackAmount': {'amount': null, 'currency': null},
  },
  'metrics': {
    'marketLoss': revision == 1 ? null : '5',
    'cashbackValue': revision == 1 ? null : '2.1',
    'netLoss': revision == 1 ? null : '2.9',
  },
  'cardBinding': {
    'cardId': bound ? 'card-1' : null,
    'cardNameSnapshot': bound ? 'Test Card' : null,
  },
  'revision': revision,
  'createdAt': '2026-08-30T00:00:00.000Z',
  'updatedAt': '2026-08-30T00:00:00.000Z',
};

http.Response _jsonResponse(Object? body, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
