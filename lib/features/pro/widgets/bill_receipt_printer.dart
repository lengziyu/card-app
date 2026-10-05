import 'dart:math' as math;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

enum BillReceiptPrinterStage { processing, printing, complete }

class BillReceiptPrinter extends StatefulWidget {
  const BillReceiptPrinter({
    required this.analyzing,
    required this.analysis,
    super.key,
  });

  final bool analyzing;
  final BillAnalysis? analysis;

  @override
  State<BillReceiptPrinter> createState() => _BillReceiptPrinterState();
}

class _BillReceiptPrinterState extends State<BillReceiptPrinter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _feedController;
  BillReceiptPrinterStage _stage = BillReceiptPrinterStage.processing;
  bool _startedInitialResult = false;
  BillAnalysis? _printingAnalysis;

  @override
  void initState() {
    super.initState();
    _feedController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1750),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed || !mounted) return;
          setState(() => _stage = BillReceiptPrinterStage.complete);
          AppHaptics.lightImpact();
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedInitialResult || widget.analysis == null) return;
    _startedInitialResult = true;
    _startPrinting();
  }

  @override
  void didUpdateWidget(covariant BillReceiptPrinter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analyzing && !oldWidget.analyzing) {
      _feedController.reset();
      _printingAnalysis = null;
      setState(() => _stage = BillReceiptPrinterStage.processing);
      return;
    }
    if (widget.analysis != null && widget.analysis != _printingAnalysis) {
      _startPrinting();
    }
  }

  void _startPrinting() {
    _printingAnalysis = widget.analysis;
    if (MediaQuery.disableAnimationsOf(context)) {
      _feedController.value = 1;
      setState(() => _stage = BillReceiptPrinterStage.complete);
      return;
    }
    setState(() => _stage = BillReceiptPrinterStage.printing);
    _feedController.forward(from: 0);
  }

  @override
  void dispose() {
    _feedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final paperVisible = analysis != null;
    return Semantics(
      key: const Key('bill-receipt-printer'),
      container: true,
      liveRegion: true,
      label: AppLocalizations.of(context).text(_statusLabel),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 356.0);
          return Center(
            child: SizedBox(
              width: width,
              child: AnimatedBuilder(
                animation: _feedController,
                builder: (context, _) {
                  final progress = paperVisible
                      ? reduceMotion
                            ? 1.0
                            : receiptFeedProgress(_feedController.value)
                      : 0.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PrinterMachine(stage: _stage, analysis: analysis),
                          if (analysis != null)
                            Transform.translate(
                              offset: const Offset(0, -14),
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: math.max(.002, progress),
                                  child: _ReceiptPaper(analysis: analysis),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        top: 163,
                        left: width * .12,
                        right: width * .12,
                        child: const _OutputSlot(),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String get _statusLabel => switch (_stage) {
    BillReceiptPrinterStage.processing => '正在使用 Qwen 识别账单',
    BillReceiptPrinterStage.printing => '正在生成识别小票',
    BillReceiptPrinterStage.complete => '账单识别完成',
  };
}

@visibleForTesting
double receiptFeedProgress(double time) {
  const times = <double>[
    0,
    .075,
    .105,
    .18,
    .21,
    .285,
    .315,
    .39,
    .42,
    .495,
    .525,
    .6,
    .63,
    .705,
    .735,
    .81,
    .84,
    .915,
    .945,
    1,
  ];
  const values = <double>[
    0,
    .09,
    .09,
    .19,
    .19,
    .30,
    .30,
    .42,
    .42,
    .55,
    .55,
    .68,
    .68,
    .80,
    .80,
    .90,
    .90,
    .97,
    .97,
    1,
  ];
  final clamped = time.clamp(0.0, 1.0).toDouble();
  for (var index = 1; index < times.length; index++) {
    if (clamped > times[index]) continue;
    final span = times[index] - times[index - 1];
    final local = span == 0 ? 1.0 : (clamped - times[index - 1]) / span;
    return values[index - 1] + (values[index] - values[index - 1]) * local;
  }
  return 1;
}

class _PrinterMachine extends StatelessWidget {
  const _PrinterMachine({required this.stage, required this.analysis});

  final BillReceiptPrinterStage stage;
  final BillAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final extraction = analysis?.extraction;
    final amount = extraction?.deduction.label ?? '—';
    final title = extraction?.provider ?? '消费账单';
    final subtitle = extraction?.cardName ?? 'Qwen 视觉识别';
    return Container(
      key: const Key('bill-receipt-machine'),
      height: 178,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 23),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF37335F), Color(0xFF202A50)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          const BoxShadow(
            color: Color(0x18FFFFFF),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 15,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CARDFI · BILL LAB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFCDD3E2),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: stage == BillReceiptPrinterStage.complete
                      ? const Color(0xFF5ED4A5)
                      : AppColors.cyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (stage == BillReceiptPrinterStage.complete
                                  ? const Color(0xFF5ED4A5)
                                  : AppColors.cyan)
                              .withValues(alpha: .5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 11),
              decoration: BoxDecoration(
                color: const Color(0xFF121722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3A4152)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xB0000000),
                    blurRadius: 10,
                    spreadRadius: -4,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF5F7FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8992A8),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '最终扣款',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF8992A8),
                                fontSize: 8.5,
                              ),
                            ),
                            Text(
                              amount,
                              key: const Key('bill-receipt-machine-deduction'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _PrinterStatus(stage: stage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterStatus extends StatelessWidget {
  const _PrinterStatus({required this.stage});

  final BillReceiptPrinterStage stage;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      BillReceiptPrinterStage.processing => 'Qwen 正在识别账单',
      BillReceiptPrinterStage.printing => '正在生成识别小票',
      BillReceiptPrinterStage.complete => '账单识别完成',
    };
    return Row(
      key: const Key('bill-receipt-status'),
      children: [
        SizedBox.square(
          dimension: 17,
          child: stage == BillReceiptPrinterStage.complete
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF5ED4A5),
                  size: 17,
                )
              : CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.cyan,
                  backgroundColor: const Color(0xFF343B4B),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              label,
              key: ValueKey(stage),
              style: const TextStyle(
                color: Color(0xFFAAB2C5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutputSlot extends StatelessWidget {
  const _OutputSlot();

  @override
  Widget build(BuildContext context) => Container(
    height: 10,
    decoration: BoxDecoration(
      color: const Color(0xFF10141D),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFF3B4253)),
      boxShadow: const [
        BoxShadow(
          color: Color(0xA0000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
  );
}

class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({required this.analysis});

  final BillAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final extraction = analysis.extraction;
    final metrics = analysis.metrics;
    final receiptText = const Color(0xFF20232B);
    final muted = const Color(0xFF777B85);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .2),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const _ReceiptEdgeClipper(),
          child: CustomPaint(
            foregroundPainter: const _ReceiptPaperTexturePainter(),
            child: Container(
              key: const Key('bill-receipt-paper'),
              color: const Color(0xFFFFFDF4).withValues(alpha: .97),
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 34),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: receiptText,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.35,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CARDFI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: receiptText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '消费账单识别结果',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReceiptDivider(color: muted),
                    const SizedBox(height: 12),
                    _ReceiptRow('平台', extraction.provider ?? '未识别'),
                    _ReceiptRow('卡片', extraction.cardName ?? '未识别'),
                    _ReceiptRow('交易时间', extraction.transactionAt ?? '未识别'),
                    if (extraction.cardLast4 != null)
                      _ReceiptRow('卡号', '•••• ${extraction.cardLast4}'),
                    const SizedBox(height: 9),
                    _ReceiptDivider(color: muted),
                    const SizedBox(height: 9),
                    _ReceiptRow('原始消费', extraction.original.label),
                    _ReceiptRow('结算金额', extraction.settlement.label),
                    _ReceiptRow(
                      '最终扣款',
                      extraction.deduction.label,
                      emphasized: true,
                      valueKey: const Key('bill-receipt-final-deduction'),
                      accent: const Color(0xFF5147C9),
                    ),
                    if (extraction.cashback.hasValue)
                      _ReceiptRow(
                        extraction.cashback.label ?? '截图返现',
                        extraction.cashback.valueLabel,
                        emphasized: true,
                        valueKey: const Key('bill-receipt-cashback'),
                        accent: const Color(0xFF16806C),
                      ),
                    for (final fee in extraction.fees.take(2))
                      _ReceiptRow(
                        fee.label ?? '手续费',
                        fee.valueLabel,
                        emphasized: true,
                        accent: _isZeroReceiptAmount(fee.amount)
                            ? const Color(0xFF16806C)
                            : const Color(0xFFC44D76),
                      ),
                    if (extraction.exchangeRates.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      _ReceiptDivider(color: muted),
                      const SizedBox(height: 9),
                      for (final rate in extraction.exchangeRates.take(2))
                        _ReceiptRow('截图汇率', rate.label),
                    ],
                    const SizedBox(height: 9),
                    _ReceiptDivider(color: muted),
                    const SizedBox(height: 9),
                    _ReceiptRow(
                      '实际综合汇率',
                      metrics.effectiveDeductionPerOriginal == null
                          ? '无法计算'
                          : '${metrics.effectiveDeductionPerOriginal} ${metrics.effectiveRatePair ?? ''}'
                                .trim(),
                      emphasized: true,
                      valueKey: const Key('bill-receipt-effective-rate'),
                      accent: const Color(0xFF4258C7),
                    ),
                    _ReceiptRow(
                      '舍入差异',
                      metrics.internalRoundingDifference ?? '无法计算',
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: extraction.needsReview.isEmpty
                            ? const Color(0x1254A77B)
                            : const Color(0x14E59A32),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        extraction.needsReview.isEmpty
                            ? '✓ 未发现必须人工确认的字段'
                            : '需确认：${extraction.needsReview.take(3).join('、')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: extraction.needsReview.isEmpty
                              ? const Color(0xFF16806C)
                              : const Color(0xFFC27817),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '置信度 ${(extraction.confidence * 100).round()}% · QWEN VISION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 8,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'AI 识别结果，请核对后使用',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(
    this.label,
    this.value, {
    this.emphasized = false,
    this.valueKey,
    this.accent,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Key? valueKey;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF777B85),
              fontFamily: 'monospace',
              fontSize: emphasized ? 10 : 9,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w500,
              letterSpacing: .3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: accent ?? const Color(0xFF20232B),
              fontFamily: 'monospace',
              fontSize: emphasized ? 11 : 9.5,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

bool _isZeroReceiptAmount(String? value) => double.tryParse(value ?? '') == 0;

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = math.max(1, (constraints.maxWidth / 5).floor());
      return Text(
        List.filled(count, '·').join(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color.withValues(alpha: .55),
          fontFamily: 'monospace',
          fontSize: 8,
          height: .5,
          letterSpacing: 1,
        ),
      );
    },
  );
}

class _ReceiptEdgeClipper extends CustomClipper<Path> {
  const _ReceiptEdgeClipper();

  @override
  Path getClip(Size size) {
    const toothWidth = 8.0;
    const toothDepth = 5.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - toothDepth);
    var x = size.width;
    var peak = false;
    while (x > 0) {
      x = math.max(0, x - toothWidth / 2);
      path.lineTo(x, peak ? size.height - toothDepth : size.height);
      peak = !peak;
    }
    return path
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ReceiptPaperTexturePainter extends CustomPainter {
  const _ReceiptPaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x0D3A3A3A)
      ..strokeWidth = .5;
    for (var y = 7.0; y < size.height; y += 11) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    final dotPaint = Paint()..color = const Color(0x0A202020);
    for (var y = 5.0; y < size.height; y += 19) {
      for (var x = 9.0 + (y.toInt() % 7); x < size.width; x += 31) {
        canvas.drawCircle(Offset(x, y), .45, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
