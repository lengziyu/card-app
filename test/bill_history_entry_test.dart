import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/pro/data/bill_analysis_repository.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/data/bill_history_repository.dart';
import 'package:cardfi/features/pro/presentation/bill_analysis_page.dart';
import 'package:cardfi/features/pro/presentation/bill_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('bill analysis exposes history from the header icon', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final apiClient = ApiClient(baseUrl: 'https://example.test');
    final repository = BillAnalysisRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillAnalysisPage(
            repository: repository,
            enableRemoteData: true,
            onBack: () {},
            onOpenHistory: () => openCount++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('bill-open-history')), findsOneWidget);
    expect(find.byKey(const Key('bill-history-entry')), findsNothing);
    expect(find.text('查看历史账单'), findsNothing);
    await tester.tap(find.byKey(const Key('bill-open-history')));
    expect(openCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history page loads and displays saved bill information', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': [_record],
              'nextCursor': null,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-history-page')), findsOneWidget);
    expect(find.text('1 条个人记录'), findsNothing);
    expect(find.text('105 USD'), findsOneWidget);
    expect(find.text('2026年8月'), findsOneWidget);
    expect(find.text('Test Pay · 08-29 23:46'), findsOneWidget);
    expect(find.text('Test Card'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history groups months as an accordion and loads by cursor', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final isSecondPage = request.url.queryParameters['cursor'] == 'page-2';
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': [
                _recordForMonth(
                  id: isSecondPage ? 'july-record' : 'august-record',
                  transactionAt: isSecondPage
                      ? '2026-07-15 12:00:00'
                      : '2026-08-29 23:46:08',
                ),
              ],
              'nextCursor': isSecondPage ? null : 'page-2',
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年8月'), findsOneWidget);
    expect(find.byKey(const Key('bill-record-august-record')), findsOneWidget);
    expect(find.text('2026年7月'), findsOneWidget);
    expect(find.byKey(const Key('bill-history-load-more')), findsNothing);
    expect(find.byKey(const Key('bill-record-july-record')), findsNothing);
    await tester.tap(find.byKey(const Key('bill-month-2026-07')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-record-july-record')), findsOneWidget);
    expect(find.byKey(const Key('bill-record-august-record')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular history uses separate cards and loads on scroll', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = List.generate(
      14,
      (index) => _recordForMonth(
        id: 'regular-$index',
        transactionAt:
            '2026-08-${(29 - index).toString().padLeft(2, '0')} 12:00:00',
      ),
    );
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final secondPage = request.url.queryParameters['cursor'] == 'page-2';
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': secondPage
                  ? records.skip(10).toList()
                  : records.take(10).toList(),
              'nextCursor': secondPage ? null : 'page-2',
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-history-view-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bill-history-view-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-history-regular-list')), findsOneWidget);
    expect(
      find.byKey(const Key('bill-history-refresh-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bill-history-pagination')), findsNothing);
    expect(find.text('2026年8月'), findsNothing);
    expect(find.byKey(const Key('bill-list-card-regular-0')), findsOneWidget);
    expect(find.byKey(const Key('bill-list-record-regular-0')), findsOneWidget);
    expect(find.byKey(const Key('bill-list-record-regular-13')), findsNothing);
    expect(find.text('返现后人民币汇率'), findsWidgets);
    final firstCard = tester.getRect(
      find.byKey(const Key('bill-list-card-regular-0')),
    );
    final firstChevron = tester.getRect(
      find.byKey(const Key('bill-list-chevron-regular-0')),
    );
    expect(firstCard.right - firstChevron.right, closeTo(12, .01));

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -1100),
      1600,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-history-pagination')), findsNothing);
    expect(
      find.byKey(const Key('bill-list-record-regular-13')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('bill-list-record-regular-13')),
      320,
    );
    await tester.tap(find.byKey(const Key('bill-list-record-regular-13')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bill-record-detail-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bill record opens a page with share preview', (tester) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': [_record],
              'nextCursor': null,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bill-record-record-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-record-detail-page')), findsOneWidget);
    expect(find.byKey(const Key('bill-record-editor')), findsNothing);
    expect(find.byKey(const Key('bill-record-share')), findsOneWidget);
    expect(find.byKey(const Key('bill-detail-deduction')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bill-record-share')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill-share-sheet')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-poster')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-logo')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-loss-metric')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-cashback-metric')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-net-metric')), findsOneWidget);
    expect(find.byKey(const Key('bill-share-save')), findsOneWidget);
    expect(find.text('磨损后净返现'), findsOneWidget);
    expect(find.text('由 CardFi 生成'), findsOneWidget);
    expect(find.text('实际综合汇率'), findsWidgets);
    expect(find.text('当前参考汇率'), findsWidgets);
    expect(find.text('磨损后人民币汇率'), findsWidgets);
    expect(find.text('返现后人民币汇率'), findsWidgets);
    expect(find.text('扣除损耗后净返现'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bill editor is a full page and exposes cashback inputs', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': [_record],
              'nextCursor': null,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    final fiatApiClient = ApiClient(
      baseUrl: 'https://fiat.example/v2',
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final benchmarkRepository = BillBenchmarkRepository(
      apiClient,
      fiatApiClient: fiatApiClient,
    );
    addTearDown(apiClient.close);
    addTearDown(fiatApiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            benchmarkRepository: benchmarkRepository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bill-record-record-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('bill-record-open-editor')),
      260,
    );
    await tester.tap(find.byKey(const Key('bill-record-open-editor')));
    await tester.pumpAndSettle();

    final editor = find.byKey(const Key('bill-record-editor'));
    expect(editor, findsOneWidget);
    expect(tester.widget<Material>(editor).color, AppColors.canvas);
    expect(find.byKey(const Key('bill-record-editor-back')), findsOneWidget);
    expect(find.byKey(const Key('bill-record-editor-close')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('bill-edit-cashbackRate')),
      220,
      scrollable: find
          .descendant(of: editor, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.byKey(const Key('bill-edit-benchmarkRate')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bill-edit-benchmarkRate')))
          .controller
          ?.text,
      '1',
    );
    expect(find.textContaining('已采用 1 USD = 1 USD'), findsOneWidget);
    expect(find.byKey(const Key('bill-edit-cashbackRate')), findsOneWidget);
    expect(find.byKey(const Key('bill-edit-cashbackAmount')), findsOneWidget);
    expect(find.byKey(const Key('bill-edit-cashbackCurrency')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('points cashback shows cash value and net percentages', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'records': [_gateRecord],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            cards: const [_gateCard],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bill-record-gate-record')));
    await tester.pumpAndSettle();
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const Key('bill-record-detail-page')),
            matching: find.byType(ListView),
          )
          .first,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(find.text('卡片宣称返现'), findsNothing);
    expect(find.text('最高 \$5/MO'), findsNothing);
    expect(find.text('0.028 USD (0.21%)'), findsOneWidget);
    expect(find.text('0.1358 USD (1%)'), findsOneWidget);
    expect(find.text('+0.1078 USD (+0.79%)'), findsOneWidget);
    expect(find.textContaining('0.14%'), findsNothing);
    expect(find.textContaining('13.58 USD (100%)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live references fill missing benchmark and list net RMB', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/api/pro/bill-records') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'records': [_liveReferenceRecord],
                'nextCursor': null,
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/stablecoins') {
          return http.Response(
            jsonEncode({
              'assets': [
                {'symbol': 'USDT', 'price': 1},
              ],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    final fiatApiClient = ApiClient(
      baseUrl: 'https://fiat.example/v2',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'rate': 0.14, 'date': '2026-09-01'}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );
    final repository = BillHistoryRepository(
      apiClient,
      accessTokenProvider: () async => 'token',
    );
    final benchmarkRepository = BillBenchmarkRepository(
      apiClient,
      fiatApiClient: fiatApiClient,
    );
    addTearDown(apiClient.close);
    addTearDown(fiatApiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillHistoryPage(
            repository: repository,
            benchmarkRepository: benchmarkRepository,
            cards: const [],
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Pay · 08-29 23:46 · 净返现 +¥0.71'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bill-record-live-reference')));
    await tester.pumpAndSettle();

    expect(find.text('1 USD = 1 USDT'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.1429'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.0721'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.2150'), findsOneWidget);
    expect(find.text('0.1 USDT (1%)'), findsOneWidget);
    expect(find.text('+0.1 USDT (+0.99%)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _record = <String, Object?>{
  'id': 'record-1',
  'status': 'draft',
  'recognized': _extraction,
  'confirmed': _extraction,
  'calculationInputs': {
    'benchmarkRate': null,
    'cashbackRate': null,
    'cashbackAmount': {'amount': null, 'currency': null},
  },
  'metrics': {'marketLoss': null, 'cashbackValue': null, 'netLoss': null},
  'cardBinding': {'cardId': null, 'cardNameSnapshot': null},
  'revision': 1,
  'createdAt': '2026-08-30T00:00:00.000Z',
  'updatedAt': '2026-08-30T00:00:00.000Z',
};

const _liveReferenceRecord = <String, Object?>{
  'id': 'live-reference',
  'status': 'draft',
  'recognized': _liveReferenceExtraction,
  'confirmed': _liveReferenceExtraction,
  'calculationInputs': {
    'benchmarkRate': null,
    'cashbackRate': '2',
    'cashbackAmount': {'amount': '0.2', 'currency': 'USDT'},
  },
  'metrics': {
    'effectiveDeductionPerOriginal': '1.01',
    'marketLoss': null,
    'cashbackValue': '0.2',
    'netLoss': null,
  },
  'cardBinding': {'cardId': null, 'cardNameSnapshot': null},
  'revision': 1,
  'createdAt': '2026-08-30T00:00:00.000Z',
  'updatedAt': '2026-08-30T00:00:00.000Z',
};

const _liveReferenceExtraction = <String, Object?>{
  'provider': 'Test Pay',
  'cardName': 'Test Card',
  'status': 'success',
  'transactionAt': '2026-08-29 23:46:08+08:00',
  'original': {'amount': '10', 'currency': 'USD'},
  'settlement': {'amount': '10.1', 'currency': 'USDT'},
  'deduction': {'amount': '10.1', 'currency': 'USDT'},
  'cashback': {'label': '返现', 'rate': '2', 'amount': '0.2', 'currency': 'USDT'},
  'fees': <Object?>[],
  'exchangeRates': <Object?>[],
  'cardLast4': '1234',
  'confidence': 0.9,
  'needsReview': <Object?>[],
};

Map<String, Object?> _recordForMonth({
  required String id,
  required String transactionAt,
}) => {
  ..._record,
  'id': id,
  'recognized': {..._extraction, 'transactionAt': transactionAt},
  'confirmed': {..._extraction, 'transactionAt': transactionAt},
};

const _extraction = <String, Object?>{
  'provider': 'Test Pay',
  'cardName': 'Test Card',
  'status': 'success',
  'transactionAt': '2026-08-29 23:46:08+08:00',
  'original': {'amount': '100', 'currency': 'USD'},
  'settlement': {'amount': '105', 'currency': 'USD'},
  'deduction': {'amount': '105', 'currency': 'USD'},
  'cashback': {'label': null, 'rate': null, 'amount': null, 'currency': null},
  'fees': <Object?>[],
  'exchangeRates': <Object?>[],
  'cardLast4': '1234',
  'confidence': 0.9,
  'needsReview': <Object?>[],
};

const _gateRecord = <String, Object?>{
  'id': 'gate-record',
  'status': 'confirmed',
  'recognized': _gateExtraction,
  'confirmed': _gateConfirmedExtraction,
  'calculationInputs': {
    'benchmarkRate': '1.3545',
    'cashbackRate': '0.1358',
    'cashbackAmount': {'amount': '0.1358', 'currency': 'USD'},
  },
  'metrics': {
    'effectiveDeductionPerOriginal': '1.358',
    'marketLoss': '0.028',
    'marketLossRate': '0.2066',
    'benchmarkExpectedDeduction': '13.552',
    'cashbackValue': '0.1358',
    'netLoss': '-0.1078',
  },
  'cardBinding': {'cardId': null, 'cardNameSnapshot': null},
  'revision': 1,
  'createdAt': '2026-07-15T13:41:14.000Z',
  'updatedAt': '2026-07-15T13:41:14.000Z',
};

const _gateExtraction = <String, Object?>{
  'provider': 'Giffgaff',
  'cardName': 'Gate Card',
  'status': 'success',
  'transactionAt': '2026-07-15 21:41:14',
  'original': {'amount': '10', 'currency': 'GBP'},
  'settlement': {'amount': '13.58', 'currency': 'USD'},
  'deduction': {'amount': '13.58', 'currency': 'USD'},
  'cashback': {
    'label': '获得积分',
    'rate': '0.1358',
    'amount': '13.58',
    'currency': 'USD',
  },
  'fees': <Object?>[],
  'exchangeRates': <Object?>[],
  'cardLast4': '4840',
  'confidence': 0.9,
  'needsReview': <Object?>[],
};

const _gateConfirmedExtraction = <String, Object?>{
  'provider': 'Giffgaff',
  'cardName': null,
  'status': 'success',
  'transactionAt': '2026-07-15 21:41:14',
  'original': {'amount': '10', 'currency': 'GBP'},
  'settlement': {'amount': '13.58', 'currency': 'USD'},
  'deduction': {'amount': '13.58', 'currency': 'USD'},
  'cashback': {
    'label': '积分现金价值',
    'rate': '0.1358',
    'amount': '0.1358',
    'currency': 'USD',
  },
  'fees': <Object?>[],
  'exchangeRates': <Object?>[],
  'cardLast4': '4840',
  'confidence': 0.9,
  'needsReview': <Object?>[],
};

const _gateCard = CardSummary(
  id: 'gate-card',
  name: 'Gate Card',
  issuer: 'Gate',
  category: CardCategory.uCard,
  label: 'Mastercard',
  tint: 0xFF3A67F7,
  cashbackRate: '最高 \$5/MO',
);
