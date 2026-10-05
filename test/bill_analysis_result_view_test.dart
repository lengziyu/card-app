import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/presentation/bill_analysis_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlights the key bill values with clear visual hierarchy', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      analysis: _analysis,
      benchmarkQuote: const BillBenchmarkQuote(
        from: 'CNY',
        to: 'USDT',
        rate: '0.148',
        sourceLabel: 'Frankfurter / DefiLlama',
        updatedAt: null,
      ),
      cnyQuote: const BillBenchmarkQuote(
        from: 'USDT',
        to: 'CNY',
        rate: '7.2',
        sourceLabel: 'Frankfurter / DefiLlama',
        updatedAt: null,
      ),
    );

    expect(find.byKey(const Key('bill-analysis-result')), findsOneWidget);
    expect(
      find.byKey(const Key('bill-result-final-deduction')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bill-result-original')), findsOneWidget);
    expect(find.byKey(const Key('bill-result-settlement')), findsOneWidget);
    expect(find.byKey(const Key('bill-result-cashback')), findsOneWidget);
    expect(
      find.byKey(const Key('bill-result-cashback-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bill-result-net-cashback')), findsOneWidget);
    expect(find.text('关键字段完整'), findsOneWidget);

    final deduction = tester.widget<Text>(
      find.byKey(const Key('bill-result-final-deduction')),
    );
    expect(deduction.style?.fontWeight, FontWeight.w900);
    expect(deduction.style?.color, Colors.white);

    final rateText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('bill-result-effective-rate')),
            matching: find.byType(Text),
          ),
        )
        .firstWhere((widget) => widget.data?.contains('0.150708') == true);
    expect(rateText.style?.fontWeight, FontWeight.w900);
    expect(rateText.style?.color, AppColors.cyan);
    expect(find.text('1 CNY = 0.150708 USDT'), findsOneWidget);
    expect(find.text('2%（预计 0.075354 USDT）'), findsOneWidget);
    expect(find.text('1 CNY = 0.148 USDT'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.2'), findsOneWidget);
    expect(find.text('磨损后人民币汇率'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.0706'), findsOneWidget);
    expect(find.text('返现后人民币汇率'), findsOneWidget);
    expect(find.text('1 USDT ≈ ¥7.2149'), findsOneWidget);
    expect(find.text('+¥0.49'), findsOneWidget);
    expect(find.text('实时参考来源：Frankfurter / DefiLlama'), findsOneWidget);
    expect(find.text('+0.0677 USDT（+1.83%）'), findsOneWidget);
    expect(find.text('+0.007654 USDT（+0.2%）'), findsOneWidget);
    expect(find.text('0 USDT'), findsOneWidget);
  });

  testWidgets('copies the final deduction and confirms the interaction', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpResult(tester, analysis: _analysis);

    await tester.tap(find.byKey(const Key('bill-copy-final-deduction')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已复制最终扣款'), findsOneWidget);
  });

  testWidgets('shows review fields as an explicit warning state', (
    tester,
  ) async {
    await _pumpResult(tester, analysis: _analysisWithReview);

    expect(find.text('有字段需要确认'), findsOneWidget);
    expect(find.text('交易时间、手续费'), findsOneWidget);
  });

  testWidgets(
    'turns a sparse USD stablecoin bill into useful and honest results',
    (tester) async {
      await _pumpResult(
        tester,
        analysis: _sparseStablecoinAnalysis,
        benchmarkQuote: const BillBenchmarkQuote(
          from: 'USD',
          to: 'USDT',
          rate: '1.00026807',
          sourceLabel: 'DefiLlama',
          updatedAt: null,
        ),
      );

      expect(find.text('1 USD = 1.01010594 USDT'), findsOneWidget);
      expect(find.text('+0.120711 USDT（+0.98%）'), findsOneWidget);
      expect(find.text('未识别，可点击下方按钮补录'), findsNWidgets(2));
      expect(find.text('截图未显示'), findsOneWidget);
      expect(find.text('1 USD = 139.99 USDT'), findsNothing);
      expect(find.text('1720.4771 USDT'), findsNothing);
      expect(find.text('-1708.0629 USDT'), findsNothing);
      expect(find.text('截图汇率与实际扣款明显不符，请核对币种或数值'), findsOneWidget);
      expect(
        find.byKey(const Key('bill-missing-calculations')),
        findsOneWidget,
      );
      expect(find.text('无法计算'), findsNothing);
    },
  );

  testWidgets('shows cashback after deducting a trusted market loss', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      analysis: BillAnalysis(
        extraction: _analysis.extraction,
        metrics: const BillMetrics(
          effectiveDeductionPerOriginal: '0.150708',
          effectiveRatePair: 'CNY/USDT',
          internalExpectedDeduction: null,
          internalRoundingDifference: null,
          declaredFeesInDeductionCurrency: '0',
          deductionCurrency: 'USDT',
          marketLoss: '0.05',
          marketLossRate: '1.35',
          benchmarkStatus: 'market',
        ),
        disclaimer: '请核对识别结果。',
      ),
    );

    expect(find.text('+0.025354 USDT（+0.67%）'), findsOneWidget);
  });

  testWidgets('treats earned points cash value as cashback', (tester) async {
    final extraction = BillExtraction.fromJson(const {
      'provider': 'Giffgaff',
      'cardName': 'Gate Card',
      'status': 'success',
      'transactionAt': '2026-07-15 21:41:14',
      'original': {'amount': '10', 'currency': 'GBP'},
      'deduction': {'amount': '13.58', 'currency': 'USD'},
      'cashback': {
        'label': '获得积分',
        'rate': '0.1358',
        'amount': '13.58',
        'currency': 'USD',
      },
    });

    await _pumpResult(
      tester,
      analysis: BillAnalysis(
        extraction: extraction,
        metrics: const BillMetrics(
          effectiveDeductionPerOriginal: '1.358',
          effectiveRatePair: 'GBP/USD',
          internalExpectedDeduction: null,
          internalRoundingDifference: null,
          declaredFeesInDeductionCurrency: null,
          deductionCurrency: 'USD',
          marketLoss: '0.035',
          marketLossRate: '0.26',
          benchmarkStatus: 'user_provided',
        ),
        disclaimer: '',
      ),
    );

    expect(extraction.cashback.amount, '0.1358');
    expect(extraction.cashback.rate, '1');
    expect(find.text('0.1358 USD（1%）'), findsOneWidget);
    expect(find.text('+0.1008 USD（+0.74%）'), findsOneWidget);
  });

  testWidgets('does not calculate with required fields awaiting confirmation', (
    tester,
  ) async {
    await _pumpResult(tester, analysis: _uncertainStablecoinAnalysis);

    expect(find.text('确认原始金额和最终扣款后计算'), findsOneWidget);
    expect(find.text('原始消费币种、最终扣款币种'), findsOneWidget);
    expect(find.text('original.currency'), findsNothing);
    expect(find.text('deduction.currency'), findsNothing);
    expect(find.text('填写当前参考汇率后计算'), findsOneWidget);
  });

  testWidgets('fits a narrow screen with larger accessibility text', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      analysis: _analysis,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.byKey(const Key('bill-analysis-result')), findsOneWidget);
    expect(find.byKey(const Key('bill-result-original')), findsOneWidget);
    expect(find.byKey(const Key('bill-result-settlement')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpResult(
  WidgetTester tester, {
  required BillAnalysis analysis,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  BillBenchmarkQuote? benchmarkQuote,
  BillBenchmarkQuote? cnyQuote,
  bool benchmarkLoading = false,
}) async {
  AppColors.configure(Brightness.light);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
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
          disableAnimations: true,
          textScaler: textScaler,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BillAnalysisResultView(
              analysis: analysis,
              benchmarkQuote: benchmarkQuote,
              cnyQuote: cnyQuote,
              benchmarkLoading: benchmarkLoading,
              showRecognitionSummary: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

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
      BillFee(type: 'transaction', label: '手续费', amount: '0', currency: 'USDT'),
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

const _analysisWithReview = BillAnalysis(
  extraction: BillExtraction(
    provider: 'MEXC',
    cardName: 'MEXC Card',
    status: 'needs_review',
    transactionAt: null,
    original: BillMoney(amount: '25', currency: 'CNY'),
    settlement: BillMoney(amount: '3.73', currency: 'USD'),
    deduction: BillMoney(amount: '3.7677', currency: 'USDT'),
    cashback: BillCashback.empty(),
    fees: [],
    exchangeRates: [],
    cardLast4: '0348',
    confidence: .72,
    needsReview: ['交易时间', '手续费'],
  ),
  metrics: BillMetrics(
    effectiveDeductionPerOriginal: '0.150708',
    effectiveRatePair: 'USDT/CNY',
    internalExpectedDeduction: null,
    internalRoundingDifference: null,
    declaredFeesInDeductionCurrency: null,
    deductionCurrency: 'USDT',
    marketLoss: null,
    marketLossRate: null,
    benchmarkStatus: 'not_available',
  ),
  disclaimer: '请核对识别结果。',
);

const _sparseStablecoinAnalysis = BillAnalysis(
  extraction: BillExtraction(
    provider: null,
    cardName: 'MEXC Card',
    status: 'success',
    transactionAt: '2026-08-24 07:00:54',
    original: BillMoney(amount: '12.27', currency: 'USD'),
    settlement: BillMoney(amount: '12.394', currency: 'USDT'),
    deduction: BillMoney(amount: '12.394', currency: 'USDT'),
    cashback: BillCashback.empty(),
    fees: [],
    exchangeRates: [BillExchangeRate(from: 'USD', to: 'USDT', rate: '139.99')],
    cardLast4: null,
    confidence: .85,
    needsReview: [],
  ),
  metrics: BillMetrics(
    effectiveDeductionPerOriginal: '1.01010594',
    effectiveRatePair: 'USD/USDT',
    internalExpectedDeduction: '1720.4771',
    internalRoundingDifference: '-1708.0629',
    declaredFeesInDeductionCurrency: '0',
    deductionCurrency: 'USDT',
    marketLoss: null,
    marketLossRate: null,
    benchmarkStatus: 'not_available',
  ),
  disclaimer: '请核对识别结果。',
);

const _uncertainStablecoinAnalysis = BillAnalysis(
  extraction: BillExtraction(
    provider: null,
    cardName: 'MEXC Card',
    status: 'success',
    transactionAt: '2026-08-24 07:00:54',
    original: BillMoney(amount: '12.27', currency: 'USD'),
    settlement: BillMoney(amount: '12.394', currency: 'USDT'),
    deduction: BillMoney(amount: '12.394', currency: 'USDT'),
    cashback: BillCashback.empty(),
    fees: [],
    exchangeRates: [],
    cardLast4: null,
    confidence: .85,
    needsReview: ['original.currency', 'deduction.currency'],
  ),
  metrics: BillMetrics(
    effectiveDeductionPerOriginal: '1.01010594',
    effectiveRatePair: 'USD/USDT',
    internalExpectedDeduction: null,
    internalRoundingDifference: null,
    declaredFeesInDeductionCurrency: '0',
    deductionCurrency: 'USDT',
    marketLoss: null,
    marketLossRate: null,
    benchmarkStatus: 'not_available',
  ),
  disclaimer: '请核对识别结果。',
);
