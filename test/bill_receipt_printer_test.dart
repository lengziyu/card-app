import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/widgets/bill_receipt_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stepped feed contains deliberate pauses and reaches completion', () {
    expect(receiptFeedProgress(.075), closeTo(.09, .001));
    expect(receiptFeedProgress(.105), closeTo(.09, .001));
    expect(receiptFeedProgress(.495), closeTo(.55, .001));
    expect(receiptFeedProgress(.525), closeTo(.55, .001));
    expect(receiptFeedProgress(1), 1);
  });

  testWidgets('shows a real processing state before any paper is revealed', (
    tester,
  ) async {
    await _pumpPrinter(tester, analyzing: true, analysis: null);

    expect(find.text('Qwen 正在识别账单'), findsOneWidget);
    expect(find.byKey(const Key('bill-receipt-paper')), findsNothing);
    expect(find.byKey(const Key('bill-receipt-machine')), findsOneWidget);
  });

  testWidgets('reduced motion reveals a complete receipt immediately', (
    tester,
  ) async {
    await _pumpPrinter(
      tester,
      analyzing: false,
      analysis: _analysis,
      disableAnimations: true,
    );
    await tester.pump();

    expect(find.text('账单识别完成'), findsOneWidget);
    expect(find.byKey(const Key('bill-receipt-paper')), findsOneWidget);
    expect(find.text('25 CNY'), findsOneWidget);
    expect(find.text('3.7677 USDT'), findsWidgets);
    expect(find.textContaining('置信度 96%'), findsOneWidget);
    final deduction = tester.widget<Text>(
      find.byKey(const Key('bill-receipt-final-deduction')),
    );
    expect(deduction.style?.fontWeight, FontWeight.w900);
    expect(deduction.style?.color, const Color(0xFF5147C9));
    final cashback = tester.widget<Text>(
      find.byKey(const Key('bill-receipt-cashback')),
    );
    expect(cashback.style?.fontWeight, FontWeight.w900);
    expect(cashback.style?.color, const Color(0xFF16806C));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts paper feed only after the analysis result arrives', (
    tester,
  ) async {
    await _pumpPrinter(tester, analyzing: true, analysis: null);
    expect(find.text('Qwen 正在识别账单'), findsOneWidget);

    await tester.pumpWidget(_printerApp(analyzing: true, analysis: _analysis));
    await tester.pump();

    expect(find.text('正在生成识别小票'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('账单识别完成'), findsOneWidget);
  });

  testWidgets('localizes printer status and receipt labels in English', (
    tester,
  ) async {
    await _pumpPrinter(
      tester,
      analyzing: false,
      analysis: _analysis,
      disableAnimations: true,
      locale: const Locale('en', 'US'),
    );

    expect(find.text('Bill recognition complete'), findsOneWidget);
    expect(find.text('Bill recognition result'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
  });

  testWidgets('prints in stages and completes on a narrow large-text screen', (
    tester,
  ) async {
    await _pumpPrinter(
      tester,
      analyzing: false,
      analysis: _analysis,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('正在生成识别小票'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('正在生成识别小票'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('账单识别完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPrinter(
  WidgetTester tester, {
  required bool analyzing,
  required BillAnalysis? analysis,
  bool disableAnimations = false,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('zh', 'CN'),
}) async {
  AppColors.configure(Brightness.light);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _printerApp(
      analyzing: analyzing,
      analysis: analysis,
      disableAnimations: disableAnimations,
      size: size,
      textScaler: textScaler,
      locale: locale,
    ),
  );
}

Widget _printerApp({
  required bool analyzing,
  required BillAnalysis? analysis,
  bool disableAnimations = false,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('zh', 'CN'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      disableAnimations: disableAnimations,
      textScaler: textScaler,
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BillReceiptPrinter(analyzing: analyzing, analysis: analysis),
      ),
    ),
  ),
);

const _analysis = BillAnalysis(
  extraction: BillExtraction(
    provider: 'MEXC',
    cardName: 'MEXC Card',
    status: 'success',
    transactionAt: '2026-07-20 18:51:25',
    original: BillMoney(amount: '25', currency: 'CNY'),
    settlement: BillMoney(amount: '3.73', currency: 'USD'),
    deduction: BillMoney(amount: '3.7677', currency: 'USDT'),
    cashback: BillCashback(
      label: '返现',
      rate: '2',
      amount: null,
      currency: null,
    ),
    fees: [
      BillFee(type: 'transaction', label: '手续费', amount: '0', currency: 'USD'),
    ],
    exchangeRates: [
      BillExchangeRate(from: 'CNY', to: 'USD', rate: '0.1492'),
      BillExchangeRate(from: 'USD', to: 'USDT', rate: '1.0102'),
    ],
    cardLast4: '0348',
    confidence: .96,
    needsReview: [],
  ),
  metrics: BillMetrics(
    effectiveDeductionPerOriginal: '0.150708',
    effectiveRatePair: 'USDT/CNY',
    internalExpectedDeduction: '3.768046',
    internalRoundingDifference: '-0.000346',
    declaredFeesInDeductionCurrency: '0',
    deductionCurrency: 'USDT',
    marketLoss: null,
    marketLossRate: null,
    benchmarkStatus: 'not_available',
  ),
  disclaimer: '请核对识别结果。',
);
