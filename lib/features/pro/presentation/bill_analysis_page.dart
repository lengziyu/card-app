import 'dart:async';
import 'dart:typed_data';

import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/pro/data/bill_analysis_repository.dart';
import 'package:card_app/features/pro/domain/bill_analysis.dart';
import 'package:card_app/features/pro/widgets/pro_crown_badge.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';

class BillAnalysisPage extends StatefulWidget {
  const BillAnalysisPage({
    required this.repository,
    required this.enableRemoteData,
    required this.onBack,
    super.key,
  });

  final BillAnalysisRepository repository;
  final bool enableRemoteData;
  final VoidCallback onBack;

  @override
  State<BillAnalysisPage> createState() => _BillAnalysisPageState();
}

class _BillAnalysisPageState extends State<BillAnalysisPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _mimeType;
  String? _fileName;
  BillAnalysis? _analysis;
  String? _error;
  bool _privacyConfirmed = false;
  bool _analyzing = false;

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
      _error = null;
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
    try {
      final analysis = await widget.repository.analyze(
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      if (mounted) setState(() => _analysis = analysis);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '账单识别失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
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
            if (_analysis case final analysis?) ...[
              const SizedBox(height: 14),
              _AnalysisResult(analysis: analysis),
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
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            key: const Key('bill-privacy-confirmation'),
            value: privacyConfirmed,
            onChanged: onPrivacyChanged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '我已确认截图不包含完整卡号、姓名、订单号或其他不必要的敏感信息',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '截图会发送到服务端和第三方 AI 进行一次性识别；App 不会把原图保存到账单记录。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9.5,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('bill-start-analysis'),
          onPressed: onAnalyze,
          icon: analyzing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(analyzing ? '正在识别…' : '开始分析'),
        ),
      ],
    ),
  );
}

class _AnalysisResult extends StatelessWidget {
  const _AnalysisResult({required this.analysis});

  final BillAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final extraction = analysis.extraction;
    final metrics = analysis.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultSection(
          title: '识别结果',
          trailing: '置信度 ${(extraction.confidence * 100).round()}%',
          rows: [
            ('平台', extraction.provider ?? '未识别'),
            ('卡片', extraction.cardName ?? '未识别'),
            ('交易时间', extraction.transactionAt ?? '未识别'),
            ('原始消费', extraction.original.label),
            ('结算金额', extraction.settlement.label),
            ('最终扣款', extraction.deduction.label),
            if (extraction.cardLast4 != null)
              ('卡号', '•••• ${extraction.cardLast4}'),
          ],
        ),
        const SizedBox(height: 12),
        _ResultSection(
          title: '费率与内部损耗',
          rows: [
            (
              '实际综合汇率',
              metrics.effectiveDeductionPerOriginal == null
                  ? '无法计算'
                  : '${metrics.effectiveDeductionPerOriginal} ${metrics.effectiveRatePair ?? ''}',
            ),
            ('截图汇率理论扣款', metrics.internalExpectedDeduction ?? '无法计算'),
            ('舍入差异', metrics.internalRoundingDifference ?? '无法计算'),
            (
              '同币种明示手续费',
              metrics.declaredFeesInDeductionCurrency == null
                  ? '无法计算'
                  : '${metrics.declaredFeesInDeductionCurrency} ${metrics.deductionCurrency ?? ''}',
            ),
            ('市场基准损耗', '待接入交易时点基准汇率'),
          ],
        ),
        if (extraction.exchangeRates.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ResultSection(
            title: '截图显示汇率',
            rows: [
              for (
                var index = 0;
                index < extraction.exchangeRates.length;
                index++
              )
                ('汇率 ${index + 1}', extraction.exchangeRates[index].label),
            ],
          ),
        ],
        if (extraction.needsReview.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MessageCard(
            message: '需要确认：${extraction.needsReview.join('、')}',
            error: false,
          ),
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
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.rows,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(color: AppColors.cyan, fontSize: 10.5),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) Divider(height: 17, color: AppColors.line),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  rows[index].$1,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  rows[index].$2,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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
