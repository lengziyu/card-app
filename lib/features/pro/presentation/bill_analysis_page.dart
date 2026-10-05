import 'dart:async';

import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/ai_data_consent_tile.dart';
import 'package:cardfi/core/widgets/premium_motion.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/pro/data/bill_analysis_repository.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/data/bill_history_repository.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/domain/bill_cny_rates.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:cardfi/features/pro/presentation/bill_history_page.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/widgets/bill_receipt_printer.dart';
import 'package:cardfi/features/pro/widgets/pro_crown_badge.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class BillAnalysisPage extends StatefulWidget {
  const BillAnalysisPage({
    required this.repository,
    required this.enableRemoteData,
    required this.onBack,
    this.benchmarkRepository,
    this.historyRepository,
    this.onOpenHistory,
    this.cards = const [],
    super.key,
  });

  final BillAnalysisRepository repository;
  final bool enableRemoteData;
  final VoidCallback onBack;
  final BillBenchmarkRepository? benchmarkRepository;
  final BillHistoryRepository? historyRepository;
  final VoidCallback? onOpenHistory;
  final List<CardSummary> cards;

  @override
  State<BillAnalysisPage> createState() => _BillAnalysisPageState();
}

class _BillAnalysisPageState extends State<BillAnalysisPage> {
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _receiptPrinterKey = GlobalKey();
  Uint8List? _imageBytes;
  String? _mimeType;
  String? _fileName;
  BillAnalysis? _analysis;
  String? _error;
  bool _privacyConfirmed = false;
  bool _analyzing = false;
  bool _savingHistory = false;
  bool _benchmarkLoading = false;
  BillBenchmarkQuote? _benchmarkQuote;
  BillBenchmarkQuote? _cnyQuote;
  BillRecord? _savedRecord;
  String? _historyMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_recoverLostImage());
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final files = response.files;
      if (files != null && files.isNotEmpty) await _acceptFile(files.first);
    } catch (_) {
      // Recovery is best effort. A normal gallery selection remains available.
    }
  }

  Future<void> _pickImage() async {
    AppHaptics.selection();
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file != null) await _acceptFile(file);
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取相册，请检查照片权限后重试。');
    }
  }

  Future<void> _acceptFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final mimeType = _supportedMimeType(file);
    if (mimeType == null) {
      setState(() => _error = '请选择 JPG、PNG 或 WebP 截图。');
      return;
    }
    if (bytes.length > BillAnalysisRepository.maxImageBytes) {
      setState(() => _error = '截图超过 1.35 MB，请先裁剪或压缩。');
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _mimeType = mimeType;
      _fileName = file.name;
      _analysis = null;
      _benchmarkQuote = null;
      _cnyQuote = null;
      _benchmarkLoading = false;
      _savedRecord = null;
      _historyMessage = null;
      _error = null;
      // Consent applies to the exact image that is about to be uploaded.
      _privacyConfirmed = false;
    });
  }

  String? _supportedMimeType(XFile file) {
    final declared = file.mimeType?.toLowerCase();
    if (const ['image/jpeg', 'image/png', 'image/webp'].contains(declared)) {
      return declared;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<void> _analyze() async {
    final imageBytes = _imageBytes;
    final mimeType = _mimeType;
    if (imageBytes == null || mimeType == null) return;
    if (!_privacyConfirmed) {
      setState(() => _error = '请先确认截图不包含完整卡号等敏感信息。');
      return;
    }
    if (!widget.enableRemoteData) {
      setState(() => _error = '连接正式服务后才能上传并识别账单截图。');
      return;
    }
    AppHaptics.selection();
    setState(() {
      _analyzing = true;
      _error = null;
    });
    if (ProConfig.billReceiptPrinterEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final receiptContext = _receiptPrinterKey.currentContext;
        if (!mounted || receiptContext == null) return;
        Scrollable.ensureVisible(
          receiptContext,
          alignment: .08,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
    try {
      final analysis = await widget.repository.analyze(
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _benchmarkLoading = widget.benchmarkRepository != null;
      });
      BillBenchmarkQuote? benchmarkQuote;
      BillBenchmarkQuote? cnyQuote;
      final benchmarkRepository = widget.benchmarkRepository;
      if (benchmarkRepository != null) {
        await Future.wait([
          () async {
            try {
              benchmarkQuote = await benchmarkRepository.loadCurrent(
                analysis.extraction,
              );
            } catch (_) {
              // Current market references are best effort.
            }
          }(),
          () async {
            try {
              cnyQuote = await benchmarkRepository.loadCurrentPair(
                from: analysis.extraction.deduction.currency,
                to: 'CNY',
              );
            } catch (_) {
              // RMB conversion is supplementary and must not block results.
            }
          }(),
        ]);
        if (mounted && identical(_analysis, analysis)) {
          setState(() {
            _benchmarkQuote = benchmarkQuote;
            _cnyQuote = cnyQuote;
            _benchmarkLoading = false;
          });
        }
      }
      final historyRepository = widget.historyRepository;
      if (historyRepository != null) {
        setState(() => _savingHistory = true);
        try {
          final record = await historyRepository.createDraft(
            analysis,
            benchmarkRate: benchmarkQuote?.rate,
          );
          if (mounted) {
            setState(() {
              _savedRecord = record;
              _historyMessage = '已保存到历史账单，等待你核对。';
            });
          }
        } on ApiException catch (error) {
          if (mounted) {
            setState(
              () => _historyMessage = '识别已完成，但历史记录保存失败：${error.message}',
            );
          }
        } catch (_) {
          if (mounted) setState(() => _historyMessage = '识别已完成，但历史记录暂未保存。');
        } finally {
          if (mounted) setState(() => _savingHistory = false);
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '账单识别失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _editSavedRecord() async {
    final record = _savedRecord;
    final historyRepository = widget.historyRepository;
    if (record == null || historyRepository == null) return;
    AppHaptics.selection();
    final updated = await openBillRecordEditorPage(
      context: context,
      repository: historyRepository,
      benchmarkRepository: widget.benchmarkRepository,
      record: record,
      cards: widget.cards,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _savedRecord = updated;
      _analysis = BillAnalysis(
        extraction: updated.confirmed,
        metrics: updated.metrics.base,
        disclaimer: _analysis?.disclaimer ?? '',
      );
      _historyMessage = '账单信息已更新并重新计算。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('bill-analysis-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, bottomInset + 38),
          children: [
            _IntroCard(),
            const SizedBox(height: 14),
            _UploadCard(
              imageBytes: _imageBytes,
              fileName: _fileName,
              privacyConfirmed: _privacyConfirmed,
              analyzing: _analyzing,
              onPick: _analyzing ? null : _pickImage,
              onPrivacyChanged: _analyzing
                  ? null
                  : (value) =>
                        setState(() => _privacyConfirmed = value ?? false),
              onAnalyze: _imageBytes == null || _analyzing ? null : _analyze,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              _MessageCard(message: error, error: true),
            ],
            if (ProConfig.billReceiptPrinterEnabled &&
                (_analyzing || _analysis != null)) ...[
              const SizedBox(height: 18),
              BillReceiptPrinter(
                key: _receiptPrinterKey,
                analyzing: _analyzing,
                analysis: _analysis,
              ),
            ],
            if (_analysis case final analysis?) ...[
              const SizedBox(height: 14),
              BillAnalysisResultView(
                analysis: analysis,
                benchmarkQuote: _benchmarkQuote,
                cnyQuote: _cnyQuote,
                benchmarkLoading: _benchmarkLoading,
                showRecognitionSummary: !ProConfig.billReceiptPrinterEnabled,
              ),
              if (widget.historyRepository != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('bill-result-edit-record'),
                  onPressed: _savedRecord == null ? null : _editSavedRecord,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(_savingHistory ? '正在准备账单…' : '补充或修改返现等信息'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
              if (_savingHistory || _historyMessage != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  message: _savingHistory ? '正在保存结构化结果…' : _historyMessage!,
                  error: !_savingHistory && _savedRecord == null,
                ),
              ],
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            height: 76,
            child: Row(
              children: [
                IconButton(
                  key: const Key('bill-analysis-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '消费账单分析',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                if (widget.onOpenHistory != null)
                  IconButton(
                    key: const Key('bill-open-history'),
                    onPressed: widget.onOpenHistory,
                    tooltip: '历史账单',
                    icon: const Icon(Icons.history_rounded),
                  ),
                const ProCrownBadge(showLabel: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.document_scanner_outlined, color: AppColors.cyan),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '识别真实消费成本',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'AI 只提取截图中明确显示的金额、币种、费率和手续费；损耗由固定公式计算，不让模型猜测。',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            height: 1.55,
          ),
        ),
      ],
    ),
  );
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.imageBytes,
    required this.fileName,
    required this.privacyConfirmed,
    required this.analyzing,
    required this.onPick,
    required this.onPrivacyChanged,
    required this.onAnalyze,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final bool privacyConfirmed;
  final bool analyzing;
  final VoidCallback? onPick;
  final ValueChanged<bool?>? onPrivacyChanged;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageBytes case final bytes?) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 340),
              color: AppColors.glassStrong,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            fileName ?? '已选择截图',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          key: const Key('bill-pick-image'),
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(imageBytes == null ? '选择消费截图' : '更换截图'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
          ),
        ),
        const SizedBox(height: 10),
        AiDataConsentTile(
          key: const Key('bill-privacy-confirmation'),
          kind: AiDataConsentKind.billVision,
          value: privacyConfirmed,
          onChanged: onPrivacyChanged,
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('bill-start-analysis'),
          onPressed: onAnalyze,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          child: analyzing
              ? const ThinkingOrbs(size: 24, label: 'Working…')
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded),
                    SizedBox(width: 8),
                    Text('开始分析'),
                  ],
                ),
        ),
      ],
    ),
  );
}

class BillAnalysisResultView extends StatelessWidget {
  const BillAnalysisResultView({
    required this.analysis,
    required this.showRecognitionSummary,
    this.benchmarkQuote,
    this.cnyQuote,
    this.benchmarkLoading = false,
    super.key,
  });

  final BillAnalysis analysis;
  final bool showRecognitionSummary;
  final BillBenchmarkQuote? benchmarkQuote;
  final BillBenchmarkQuote? cnyQuote;
  final bool benchmarkLoading;

  @override
  Widget build(BuildContext context) {
    final extraction = analysis.extraction;
    final metrics = analysis.metrics;
    final presentation = _BillResultPresentation.from(
      analysis,
      benchmarkQuote,
      cnyQuote,
      benchmarkLoading,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final feeColor = !presentation.hasExplicitSameCurrencyFee
        ? AppColors.textMuted
        : _isZeroAmount(metrics.declaredFeesInDeductionCurrency ?? '')
        ? AppColors.mint
        : AppColors.pink;
    final resultRows = <_ResultRowData>[
      _ResultRowData(
        key: const Key('bill-result-effective-rate'),
        label: '实际综合汇率',
        value: presentation.effectiveRateLabel,
        icon: Icons.swap_horiz_rounded,
        valueColor: presentation.requiredFieldsNeedReview
            ? AppColors.textMuted
            : AppColors.cyan,
        emphasized: !presentation.requiredFieldsNeedReview,
      ),
      _ResultRowData(
        key: const Key('bill-result-current-benchmark'),
        label: '当前参考汇率（可修改）',
        value: presentation.benchmarkRateLabel,
        icon: Icons.currency_exchange_rounded,
        valueColor: presentation.hasBenchmark
            ? AppColors.cyan
            : AppColors.textMuted,
        emphasized: presentation.hasBenchmark,
      ),
      if (presentation.cnyRateLabel != null)
        _ResultRowData(
          key: const Key('bill-result-cny-rate'),
          label: '实时人民币参考',
          value: presentation.cnyRateLabel!,
          icon: Icons.currency_yen_rounded,
          valueColor: AppColors.cyan,
          emphasized: true,
        ),
      if (presentation.lossCnyRateLabel != null)
        _ResultRowData(
          key: const Key('bill-result-loss-cny-rate'),
          label: '磨损后人民币汇率',
          value: presentation.lossCnyRateLabel!,
          icon: Icons.calculate_outlined,
          valueColor: AppColors.cyan,
          emphasized: true,
        ),
      if (presentation.cashbackCnyRateLabel != null)
        _ResultRowData(
          key: const Key('bill-result-cashback-cny-rate'),
          label: '返现后人民币汇率',
          value: presentation.cashbackCnyRateLabel!,
          icon: Icons.savings_outlined,
          valueColor: AppColors.mint,
          emphasized: true,
        ),
      _ResultRowData(
        key: const Key('bill-result-current-loss'),
        label: '当前参考损耗',
        value: presentation.lossLabel,
        icon: Icons.stacked_line_chart_rounded,
        valueColor: presentation.lossIsPositive == null
            ? AppColors.textMuted
            : presentation.lossIsPositive!
            ? AppColors.pink
            : AppColors.mint,
        emphasized: presentation.lossIsPositive != null,
      ),
      if (presentation.lossCnyLabel != null)
        _ResultRowData(
          key: const Key('bill-result-loss-cny'),
          label: '损耗折合人民币',
          value: presentation.lossCnyLabel!,
          icon: Icons.payments_outlined,
          valueColor: presentation.lossIsPositive == true
              ? AppColors.pink
              : AppColors.mint,
          emphasized: true,
        ),
      _ResultRowData(
        key: const Key('bill-result-cashback-summary'),
        label: '返现',
        value: presentation.cashbackLabel,
        icon: Icons.savings_outlined,
        valueColor: presentation.hasCashback
            ? AppColors.mint
            : AppColors.textMuted,
        emphasized: presentation.hasCashback,
      ),
      _ResultRowData(
        key: const Key('bill-result-net-cashback'),
        label: '扣除损耗后实际返现',
        value: presentation.netCashbackLabel,
        icon: Icons.account_balance_wallet_outlined,
        valueColor: presentation.netCashbackIsPositive == null
            ? AppColors.textMuted
            : presentation.netCashbackIsPositive!
            ? AppColors.mint
            : AppColors.pink,
        emphasized: presentation.netCashbackIsPositive != null,
      ),
      _ResultRowData(
        key: const Key('bill-result-fee'),
        label: '截图明示手续费',
        value: presentation.feeLabel,
        icon: Icons.price_check_rounded,
        valueColor: feeColor,
        emphasized: presentation.hasExplicitSameCurrencyFee,
      ),
    ];
    final content = Column(
      key: const Key('bill-analysis-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHero(
          extraction: extraction,
          showRecognitionSummary: showRecognitionSummary,
        ),
        const SizedBox(height: 12),
        _ResultSection(
          icon: Icons.analytics_outlined,
          title: '本次账单可以确认的结果',
          subtitle: '根据截图识别值预览，确认后再作为费用记录使用',
          rows: resultRows,
        ),
        if (presentation.connectedRates.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExchangeRateSection(rates: presentation.connectedRates),
        ],
        if (presentation.missingCalculationMessages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MissingCalculationPanel(
            messages: presentation.missingCalculationMessages,
          ),
        ],
        const SizedBox(height: 12),
        _ReviewPanel(fields: presentation.reviewLabels),
        if (presentation.sourceNote != null) ...[
          const SizedBox(height: 12),
          _BenchmarkSourceNote(note: presentation.sourceNote!),
        ],
        const SizedBox(height: 10),
        Text(
          analysis.disclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            height: 1.4,
          ),
        ),
      ],
    );
    if (reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: content,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _BillResultPresentation {
  const _BillResultPresentation({
    required this.requiredFieldsNeedReview,
    required this.effectiveRateLabel,
    required this.benchmarkRateLabel,
    required this.hasBenchmark,
    required this.cnyRateLabel,
    required this.lossCnyRateLabel,
    required this.cashbackCnyRateLabel,
    required this.lossLabel,
    required this.lossCnyLabel,
    required this.lossIsPositive,
    required this.cashbackLabel,
    required this.hasCashback,
    required this.netCashbackLabel,
    required this.netCashbackIsPositive,
    required this.feeLabel,
    required this.hasExplicitSameCurrencyFee,
    required this.connectedRates,
    required this.reviewLabels,
    required this.missingCalculationMessages,
    required this.sourceNote,
  });

  factory _BillResultPresentation.from(
    BillAnalysis analysis,
    BillBenchmarkQuote? benchmarkQuote,
    BillBenchmarkQuote? cnyQuote,
    bool benchmarkLoading,
  ) {
    final extraction = analysis.extraction;
    final metrics = analysis.metrics;
    final reviewPaths = extraction.needsReview.toSet();
    final requiredFieldsNeedReview = reviewPaths.any(
      _calculationRequiredReviewPaths.contains,
    );
    final rawRatePath = _connectedRatePath(extraction);
    final ratePathIsPlausible = _ratePathIsPlausible(
      rawRatePath,
      extraction,
      metrics,
    );
    final ratePath = ratePathIsPlausible
        ? rawRatePath
        : const <BillExchangeRate>[];
    final currenciesAreSame =
        extraction.original.currency != null &&
        extraction.original.currency == extraction.deduction.currency;
    final completeRates = extraction.exchangeRates
        .where(
          (rate) => rate.from != null && rate.to != null && rate.rate != null,
        )
        .toList(growable: false);
    final unmatchedRateCount = currenciesAreSame
        ? completeRates.length
        : completeRates.length - rawRatePath.length;
    final suspiciousRatePath = rawRatePath.isNotEmpty && !ratePathIsPlausible;
    final reviewLabels = <String>{
      for (final field in extraction.needsReview) _reviewFieldLabel(field),
      if (unmatchedRateCount > 0) '有 $unmatchedRateCount 条汇率无法匹配本次扣款链路',
      if (suspiciousRatePath) '截图汇率与实际扣款明显不符，请核对币种或数值',
    }.toList(growable: false);

    final originalCurrency = extraction.original.currency;
    final deductionCurrency = extraction.deduction.currency;
    final effectiveRate = metrics.effectiveDeductionPerOriginal;
    final effectiveRateLabel = requiredFieldsNeedReview
        ? '确认原始金额和最终扣款后计算'
        : effectiveRate == null ||
              originalCurrency == null ||
              deductionCurrency == null
        ? '缺少原始金额或最终扣款'
        : '1 $originalCurrency = $effectiveRate $deductionCurrency';

    final original = _FixedDecimal.tryParse(extraction.original.amount);
    final deduction = _FixedDecimal.tryParse(extraction.deduction.amount);
    final currentRate = _FixedDecimal.tryParse(benchmarkQuote?.rate);
    final currentExpected =
        requiredFieldsNeedReview || original == null || currentRate == null
        ? null
        : original.multiply(currentRate);
    final currentLoss = currentExpected == null || deduction == null
        ? null
        : deduction.subtract(currentExpected);
    final serverLoss = _FixedDecimal.tryParse(metrics.marketLoss);
    final loss = currentLoss ?? serverLoss;
    final lossBasis = currentExpected ?? deduction;
    final lossPercent = loss == null || lossBasis == null
        ? null
        : loss.percentOf(lossBasis, precision: 2);
    final benchmarkRateLabel = benchmarkLoading
        ? '正在获取当前值…'
        : benchmarkQuote == null
        ? '暂不可用，可手动填写'
        : benchmarkQuote.rateLabel;
    final cnyRate = _FixedDecimal.tryParse(cnyQuote?.rate);
    final cnyRateLabel = benchmarkLoading
        ? null
        : cnyQuote == null || cnyRate == null
        ? null
        : '1 ${cnyQuote.from} ≈ ¥${cnyRate.format(maxFractionDigits: 4)}';
    final lossLabel = benchmarkLoading
        ? '获取当前参考汇率后计算'
        : loss == null
        ? '填写当前参考汇率后计算'
        : '${loss.units > BigInt.zero ? '+' : ''}${loss.format(maxFractionDigits: 6)} ${deductionCurrency ?? ''}'
                  '${lossPercent == null ? '' : '（${lossPercent.units > BigInt.zero ? '+' : ''}${lossPercent.format()}%）'}'
              .trim();
    final lossCny = loss == null || cnyRate == null
        ? null
        : loss.multiply(cnyRate);
    final lossCnyLabel = lossCny == null
        ? null
        : '${lossCny.units > BigInt.zero ? '+' : ''}¥${lossCny.format(maxFractionDigits: 2)}';
    final cashback = requiredFieldsNeedReview
        ? null
        : _cashbackSummary(extraction);
    final expectedForCnyRates =
        currentExpected ??
        (deduction == null || serverLoss == null
            ? null
            : deduction.subtract(serverLoss));
    final cnyRates = calculateBillCnyRates(
      currentCnyRate: double.tryParse(cnyRate?.format() ?? ''),
      benchmarkExpectedDeduction: double.tryParse(
        expectedForCnyRates?.format() ?? '',
      ),
      actualDeduction: double.tryParse(deduction?.format() ?? ''),
      cashback: double.tryParse(cashback?.value.format() ?? ''),
    );
    final lossCnyRateLabel = cnyRates == null || deductionCurrency == null
        ? null
        : '1 $deductionCurrency ≈ ¥${formatBillCnyRate(cnyRates.lossAdjusted)}';
    final cashbackCnyRateLabel =
        cnyRates?.cashbackAdjusted == null || deductionCurrency == null
        ? null
        : '1 $deductionCurrency ≈ ¥${formatBillCnyRate(cnyRates!.cashbackAdjusted!)}';
    final netCashback = cashback != null && loss != null
        ? cashback.value.subtract(loss)
        : null;
    final netCashbackPercent = netCashback == null || deduction == null
        ? null
        : netCashback.percentOf(deduction, precision: 2);
    final netCashbackLabel = cashback == null
        ? '未识别，可点击下方按钮补录'
        : benchmarkLoading
        ? '获取当前参考汇率后计算'
        : loss == null
        ? '填写当前参考汇率后计算'
        : '${netCashback!.units > BigInt.zero ? '+' : ''}${netCashback.format(maxFractionDigits: 6)} ${deductionCurrency ?? ''}'
                  '${netCashbackPercent == null ? '' : '（${netCashbackPercent.units > BigInt.zero ? '+' : ''}${netCashbackPercent.format()}%）'}'
              .trim();
    final sameCurrencyFees = extraction.fees
        .where(
          (fee) =>
              fee.amount != null &&
              fee.currency != null &&
              fee.currency == deductionCurrency,
        )
        .toList(growable: false);
    final hasExplicitSameCurrencyFee = sameCurrencyFees.isNotEmpty;
    final feeLabel = hasExplicitSameCurrencyFee
        ? metrics.declaredFeesInDeductionCurrency == null
              ? '金额或币种需要确认'
              : '${metrics.declaredFeesInDeductionCurrency} ${deductionCurrency ?? ''}'
                    .trim()
        : extraction.fees.isEmpty
        ? '截图未显示'
        : '已识别其他币种费用，未合并';
    final missingCalculationMessages = <String>[
      if (requiredFieldsNeedReview)
        '先确认原始金额、原始币种、最终扣款和扣款币种，再生成正式计算结果。'
      else if (suspiciousRatePath)
        '截图汇率疑似识别错误，本次不参与损耗计算；请在历史账单中核对。'
      else if (ratePath.isEmpty &&
          !currenciesAreSame &&
          completeRates.isNotEmpty)
        '截图汇率无法连接 $originalCurrency 与 $deductionCurrency，本次不参与损耗计算。',
      if (cashback == null) '返现：截图未识别，可点击下方按钮补录返现比例或实际到账金额。',
      if (!benchmarkLoading && benchmarkQuote == null && serverLoss == null)
        '当前参考汇率暂不可用，可点击下方按钮手动填写。',
      if (benchmarkQuote != null) '当前参考汇率仅用于当前估算，并非交易时点汇率；可点击下方按钮修改。',
    ];
    final sourceNotes = <String>{
      if (benchmarkQuote != null) _benchmarkSourceSummary(benchmarkQuote),
      if (cnyQuote != null) _benchmarkSourceSummary(cnyQuote),
    };

    return _BillResultPresentation(
      requiredFieldsNeedReview: requiredFieldsNeedReview,
      effectiveRateLabel: effectiveRateLabel,
      benchmarkRateLabel: benchmarkRateLabel,
      hasBenchmark: benchmarkQuote != null,
      cnyRateLabel: cnyRateLabel,
      lossCnyRateLabel: lossCnyRateLabel,
      cashbackCnyRateLabel: cashbackCnyRateLabel,
      lossLabel: lossLabel,
      lossCnyLabel: lossCnyLabel,
      lossIsPositive: loss == null ? null : loss.units >= BigInt.zero,
      cashbackLabel: cashback?.label ?? '未识别，可点击下方按钮补录',
      hasCashback: cashback != null,
      netCashbackLabel: netCashbackLabel,
      netCashbackIsPositive: netCashback == null
          ? null
          : netCashback.units >= BigInt.zero,
      feeLabel: feeLabel,
      hasExplicitSameCurrencyFee: hasExplicitSameCurrencyFee,
      connectedRates: ratePath,
      reviewLabels: reviewLabels,
      missingCalculationMessages: missingCalculationMessages,
      sourceNote: sourceNotes.isEmpty ? null : sourceNotes.join('；'),
    );
  }

  final bool requiredFieldsNeedReview;
  final String effectiveRateLabel;
  final String benchmarkRateLabel;
  final bool hasBenchmark;
  final String? cnyRateLabel;
  final String? lossCnyRateLabel;
  final String? cashbackCnyRateLabel;
  final String lossLabel;
  final String? lossCnyLabel;
  final bool? lossIsPositive;
  final String cashbackLabel;
  final bool hasCashback;
  final String netCashbackLabel;
  final bool? netCashbackIsPositive;
  final String feeLabel;
  final bool hasExplicitSameCurrencyFee;
  final List<BillExchangeRate> connectedRates;
  final List<String> reviewLabels;
  final List<String> missingCalculationMessages;
  final String? sourceNote;
}

String _benchmarkSourceSummary(BillBenchmarkQuote quote) {
  final updatedAt = quote.updatedAt?.toLocal();
  if (updatedAt == null) return quote.sourceLabel;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final timestamp =
      '${updatedAt.year}-${twoDigits(updatedAt.month)}-'
      '${twoDigits(updatedAt.day)} ${twoDigits(updatedAt.hour)}:'
      '${twoDigits(updatedAt.minute)}';
  return '${quote.sourceLabel} · 更新 $timestamp';
}

const _calculationRequiredReviewPaths = <String>{
  'original.amount',
  'original.currency',
  'deduction.amount',
  'deduction.currency',
};

const _reviewFieldLabels = <String, String>{
  'provider': '平台或发卡方',
  'cardName': '卡片名称',
  'status': '交易状态',
  'transactionAt': '交易时间',
  'original.amount': '原始消费金额',
  'original.currency': '原始消费币种',
  'settlement.amount': '结算金额',
  'settlement.currency': '结算币种',
  'deduction.amount': '最终扣款金额',
  'deduction.currency': '最终扣款币种',
  'fees': '手续费',
  'exchangeRates': '截图汇率',
  'cardLast4': '卡号末四位',
  'cashback.rate': '返现比例',
  'cashback.amount': '返现金额',
  'cashback.currency': '返现币种',
};

String _reviewFieldLabel(String field) =>
    _reviewFieldLabels[field] ?? (field.contains('.') ? '其他识别字段' : field);

List<BillExchangeRate> _connectedRatePath(BillExtraction extraction) {
  final start = extraction.original.currency;
  final target = extraction.deduction.currency;
  if (start == null || target == null || start == target) return const [];
  final rates = extraction.exchangeRates
      .where(
        (rate) => rate.from != null && rate.to != null && rate.rate != null,
      )
      .toList(growable: false);
  final queue = <({String currency, List<int> path})>[
    (currency: start, path: const []),
  ];
  final visited = <String>{start};
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (var index = 0; index < rates.length; index++) {
      final rate = rates[index];
      if (rate.from != current.currency || current.path.contains(index)) {
        continue;
      }
      final nextCurrency = rate.to!;
      final nextPath = [...current.path, index];
      if (nextCurrency == target) {
        return nextPath.map((item) => rates[item]).toList(growable: false);
      }
      if (visited.add(nextCurrency)) {
        queue.add((currency: nextCurrency, path: nextPath));
      }
    }
  }
  return const [];
}

bool _ratePathIsPlausible(
  List<BillExchangeRate> path,
  BillExtraction extraction,
  BillMetrics metrics,
) {
  if (path.isEmpty) return true;
  final effective = double.tryParse(
    metrics.effectiveDeductionPerOriginal ?? '',
  );
  var composite = 1.0;
  for (final item in path) {
    final rate = double.tryParse(item.rate ?? '');
    if (rate == null || !rate.isFinite || rate <= 0) return false;
    composite *= rate;
  }
  if (!composite.isFinite || composite <= 0) return false;
  final isUsdPegPair =
      extraction.original.currency == 'USD' &&
      _usdPeggedCurrencies.contains(extraction.deduction.currency);
  if (isUsdPegPair && (composite < .8 || composite > 1.2)) return false;
  if (effective == null || !effective.isFinite || effective <= 0) return true;
  return (composite - effective).abs() / effective <= .25;
}

const _usdPeggedCurrencies = <String>{
  'USDT',
  'USDC',
  'USDP',
  'PYUSD',
  'FDUSD',
  'RLUSD',
  'USD1',
};

({String label, _FixedDecimal value})? _cashbackSummary(
  BillExtraction extraction,
) {
  final currency = extraction.deduction.currency;
  final amount = _FixedDecimal.tryParse(extraction.cashback.amount);
  if (amount != null &&
      currency != null &&
      extraction.cashback.currency == currency) {
    final deduction = _FixedDecimal.tryParse(extraction.deduction.amount);
    final rate = deduction == null
        ? _FixedDecimal.tryParse(extraction.cashback.rate)
        : amount.percentOf(deduction, precision: 2);
    return (
      label:
          '${amount.format()} $currency${rate == null ? '' : '（${rate.format()}%）'}',
      value: amount,
    );
  }
  final rate = _FixedDecimal.tryParse(extraction.cashback.rate);
  final deduction = _FixedDecimal.tryParse(extraction.deduction.amount);
  if (rate == null || deduction == null || currency == null) return null;
  final estimated = deduction.multiply(rate).divideByPowerOfTen(2);
  return (
    label: '${rate.format()}%（预计 ${estimated.format()} $currency）',
    value: estimated,
  );
}

class _FixedDecimal {
  const _FixedDecimal(this.units, this.scale);

  static _FixedDecimal? tryParse(String? value) {
    final source = value?.trim();
    if (source == null || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(source)) {
      return null;
    }
    final negative = source.startsWith('-');
    final parts = source.replaceFirst('-', '').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final units = BigInt.parse('${parts[0]}$fraction');
    return _FixedDecimal(negative ? -units : units, fraction.length);
  }

  final BigInt units;
  final int scale;

  _FixedDecimal subtract(_FixedDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    return _FixedDecimal(
      units * _power10(targetScale - scale) -
          other.units * _power10(targetScale - other.scale),
      targetScale,
    );
  }

  _FixedDecimal multiply(_FixedDecimal other) =>
      _FixedDecimal(units * other.units, scale + other.scale);

  _FixedDecimal divideByPowerOfTen(int exponent) =>
      _FixedDecimal(units, scale + exponent);

  _FixedDecimal absolute() => _FixedDecimal(units.abs(), scale);

  _FixedDecimal? percentOf(_FixedDecimal other, {required int precision}) {
    if (other.units == BigInt.zero) return null;
    var numerator = units * BigInt.from(100);
    var denominator = other.units;
    final exponent = other.scale + precision - scale;
    if (exponent >= 0) {
      numerator *= _power10(exponent);
    } else {
      denominator *= _power10(-exponent);
    }
    final negative = numerator.isNegative != denominator.isNegative;
    final numeratorAbs = numerator.abs();
    final denominatorAbs = denominator.abs();
    var rounded = numeratorAbs ~/ denominatorAbs;
    if ((numeratorAbs % denominatorAbs) * BigInt.two >= denominatorAbs) {
      rounded += BigInt.one;
    }
    return _FixedDecimal(negative ? -rounded : rounded, precision);
  }

  String format({int? maxFractionDigits}) {
    if (maxFractionDigits != null && scale > maxFractionDigits) {
      final factor = _power10(scale - maxFractionDigits);
      final absoluteUnits = units.abs();
      var rounded = absoluteUnits ~/ factor;
      if ((absoluteUnits % factor) * BigInt.two >= factor) {
        rounded += BigInt.one;
      }
      return _FixedDecimal(
        units.isNegative ? -rounded : rounded,
        maxFractionDigits,
      ).format();
    }
    final negative = units.isNegative;
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    if (scale == 0) return '${negative ? '-' : ''}$digits';
    final integer = digits.substring(0, digits.length - scale);
    final fraction = digits
        .substring(digits.length - scale)
        .replaceFirst(RegExp(r'0+$'), '');
    return '${negative ? '-' : ''}$integer${fraction.isEmpty ? '' : '.$fraction'}';
  }
}

BigInt _power10(int exponent) => BigInt.from(10).pow(exponent);

class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required this.extraction,
    required this.showRecognitionSummary,
  });

  final BillExtraction extraction;
  final bool showRecognitionSummary;

  Future<void> _copyDeduction(BuildContext context) async {
    final value = extraction.deduction.label;
    await Clipboard.setData(ClipboardData(text: value));
    AppHaptics.selection();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('已复制最终扣款'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: _resultCardDecoration(accent: AppColors.violet),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -32,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withValues(alpha: .24),
                    AppColors.cyan.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.violet, AppColors.cyan],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.violet.withValues(alpha: .25),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 识别完成',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text('请重点核对扣款金额', style: TextStyle(fontSize: 10.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ConfidenceBadge(value: extraction.confidence),
                  ],
                ),
                if (showRecognitionSummary) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _MetaChip(
                        icon: Icons.storefront_outlined,
                        label: extraction.provider ?? '平台未识别',
                      ),
                      _MetaChip(
                        icon: Icons.credit_card_rounded,
                        label: [
                          extraction.cardName ?? '卡片未识别',
                          if (extraction.cardLast4 != null)
                            '•••• ${extraction.cardLast4}',
                        ].join(' · '),
                      ),
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: extraction.transactionAt ?? '时间未识别',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.violet,
                        Color.lerp(AppColors.violet, AppColors.cyan, .72)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: .28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '最终扣款',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                extraction.deduction.label,
                                key: const Key('bill-result-final-deduction'),
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('bill-copy-final-deduction'),
                        onPressed: () => _copyDeduction(context),
                        tooltip: '复制最终扣款',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: .16),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                if (showRecognitionSummary) ...[
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 310;
                      final original = _AmountTile(
                        key: const Key('bill-result-original'),
                        label: '原始消费',
                        value: extraction.original.label,
                        icon: Icons.shopping_bag_outlined,
                        accent: AppColors.cyan,
                      );
                      final settlement = _AmountTile(
                        key: const Key('bill-result-settlement'),
                        label: '结算金额',
                        value: extraction.settlement.label,
                        icon: Icons.account_balance_wallet_outlined,
                        accent: AppColors.violet,
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            original,
                            const SizedBox(height: 8),
                            settlement,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: original),
                          const SizedBox(width: 8),
                          Expanded(child: settlement),
                        ],
                      );
                    },
                  ),
                  if (extraction.cashback.hasValue) ...[
                    const SizedBox(height: 8),
                    _CashbackBanner(cashback: extraction.cashback),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.cyan.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.cyan.withValues(alpha: .22)),
    ),
    child: Text(
      '${(value * 100).round()}%',
      maxLines: 1,
      style: TextStyle(
        color: AppColors.cyan,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 250),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.glassStrong,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .15)),
    ),
    child: Row(
      children: [
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 9.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CashbackBanner extends StatelessWidget {
  const _CashbackBanner({required this.cashback});

  final BillCashback cashback;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('bill-result-cashback'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.mint.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.mint.withValues(alpha: .24)),
    ),
    child: Row(
      children: [
        Icon(Icons.savings_outlined, color: AppColors.mint, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            cashback.label ?? '截图返现',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ),
        Text(
          cashback.valueLabel,
          style: TextStyle(
            color: AppColors.mint,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ResultRowData {
  const _ResultRowData({
    required this.label,
    required this.value,
    required this.icon,
    this.key,
    this.valueColor,
    this.emphasized = false,
  });

  final Key? key;
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool emphasized;
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_ResultRowData> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _resultCardDecoration(accent: AppColors.cyan),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.cyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 7),
          Container(
            key: rows[index].key,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: (rows[index].valueColor ?? AppColors.textMuted).withValues(
                alpha: rows[index].emphasized ? .075 : .035,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  rows[index].icon,
                  size: 15,
                  color: rows[index].valueColor ?? AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    rows[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        rows[index].value,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: rows[index].valueColor ?? AppColors.text,
                          fontSize: rows[index].emphasized ? 12 : 11,
                          fontWeight: rows[index].emphasized
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _BenchmarkSourceNote extends StatelessWidget {
  const _BenchmarkSourceNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '实时参考来源：$note',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExchangeRateSection extends StatelessWidget {
  const _ExchangeRateSection({required this.rates});

  final List<BillExchangeRate> rates;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _resultCardDecoration(accent: AppColors.violet),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '截图显示汇率',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < rates.length; index++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.violet.withValues(alpha: .11),
                      AppColors.cyan.withValues(alpha: .07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.violet.withValues(alpha: .18),
                  ),
                ),
                child: Text(
                  rates[index].label,
                  style: TextStyle(
                    color: AppColors.violet,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _MissingCalculationPanel extends StatelessWidget {
  const _MissingCalculationPanel({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('bill-missing-calculations'),
    padding: const EdgeInsets.all(15),
    decoration: _resultCardDecoration(accent: const Color(0xFFFFB44A)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              color: Color(0xFFFFB44A),
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '补充这些信息可获得更多结果',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < messages.length; index++) ...[
          if (index > 0) const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB44A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  messages[index],
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final complete = fields.isEmpty;
    final accent = complete ? AppColors.mint : const Color(0xFFFFB44A);
    return Container(
      key: const Key('bill-result-review'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            complete ? Icons.verified_rounded : Icons.error_outline_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete ? '关键字段完整' : '有字段需要确认',
                  style: TextStyle(
                    color: complete ? AppColors.text : accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  complete ? '未发现明显冲突；金额、币种和扣款仍需你对照原图确认。' : fields.join('、'),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isZeroAmount(String value) => double.tryParse(value) == 0;

BoxDecoration _resultCardDecoration({required Color accent}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? [const Color(0xE6384158), const Color(0xCC2C3449)]
        : [
            const Color(0xF5FFFFFF),
            Color.lerp(const Color(0xFFFFFFFF), accent, .035)!,
          ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: accent.withValues(alpha: .14)),
  boxShadow: [
    BoxShadow(
      color: accent.withValues(alpha: AppColors.isDark ? .07 : .1),
      blurRadius: 24,
      spreadRadius: -12,
      offset: const Offset(0, 12),
    ),
  ],
);

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final accent = error ? const Color(0xFFFF4D67) : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .24)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? accent : AppColors.text,
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.glass,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.line),
);
