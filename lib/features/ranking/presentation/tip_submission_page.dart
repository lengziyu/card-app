import 'dart:async';

import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/searchable_card_picker.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';

typedef TipImagePicker = Future<List<XFile>> Function(int limit);

class TipSubmissionPage extends StatefulWidget {
  const TipSubmissionPage({
    required this.cards,
    required this.onBack,
    required this.onSubmit,
    required this.onOpenContributions,
    this.pickImages,
    super.key,
  });

  final List<CardSummary> cards;
  final VoidCallback onBack;
  final Future<void> Function(LocalSubmissionDraft) onSubmit;
  final VoidCallback onOpenContributions;
  final TipImagePicker? pickImages;

  @override
  State<TipSubmissionPage> createState() => _TipSubmissionPageState();
}

class _TipSubmissionPageState extends State<TipSubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _experienceController = TextEditingController();
  String _savedTitle = '';
  String _savedDescription = '';
  final _imagePicker = ImagePicker();

  CardSummary? _card;
  final List<LocalSubmissionImage> _images = [];
  bool _anonymous = true;
  bool _confirmedSafe = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.pickImages == null) unawaited(_recoverLostImages());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _recoverLostImages() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      final files = response.files;
      if (!mounted || response.isEmpty || files == null || files.isEmpty) {
        return;
      }
      await _acceptImages(files);
    } catch (_) {
      // Recovery is best effort; the normal system picker remains available.
    }
  }

  Future<void> _pickImages() async {
    if (_submitting || _images.length >= maxLocalSubmissionImages) return;
    final remaining = maxLocalSubmissionImages - _images.length;
    try {
      final files = widget.pickImages != null
          ? await widget.pickImages!(remaining)
          : await _imagePicker.pickMultiImage(
              maxWidth: 1800,
              maxHeight: 1800,
              imageQuality: 82,
              limit: remaining,
              requestFullMetadata: false,
            );
      await _acceptImages(files);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法读取照片，请检查照片权限后重试。');
      }
    }
  }

  Future<void> _acceptImages(List<XFile> files) async {
    if (files.isEmpty) return;
    final accepted = <LocalSubmissionImage>[];
    String? rejection;
    var totalBytes = _images.fold<int>(
      0,
      (total, image) => total + image.bytes.length,
    );
    for (final file in files.take(maxLocalSubmissionImages - _images.length)) {
      final mimeType = _supportedMimeType(file);
      if (mimeType == null) {
        rejection ??= '图片仅支持 JPG、PNG 或 WebP 格式。';
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxLocalSubmissionImageBytes) {
        rejection ??= '每张图片需小于 4 MB。';
        continue;
      }
      if (totalBytes + bytes.length > maxLocalSubmissionImageTotalBytes) {
        rejection ??= '投稿图片总大小需小于 10 MB。';
        continue;
      }
      totalBytes += bytes.length;
      accepted.add(
        LocalSubmissionImage(
          bytes: bytes,
          fileName: file.name,
          mimeType: mimeType,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _images.addAll(accepted);
      _error = rejection;
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

  void _removeImage(int index) {
    if (_submitting) return;
    setState(() {
      _images.removeAt(index);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Let mobile IMEs commit any active composing text before reading the form.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final form = _formKey.currentState;
    if (!(form?.validate() ?? false)) return;
    form!.save();
    final controllerTitle = _titleController.text.trim();
    final controllerDescription = _experienceController.text.trim();
    final title = _savedTitle.trim().isNotEmpty
        ? _savedTitle.trim()
        : controllerTitle;
    final description = _savedDescription.trim().isNotEmpty
        ? _savedDescription.trim()
        : controllerDescription;
    if (_card == null) {
      setState(() => _error = '请选择关联卡片。');
      return;
    }
    if (!_confirmedSafe) {
      setState(() => _error = '请先确认投稿中不包含敏感信息或推广内容。');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        LocalSubmissionDraft(
          category: LocalSubmissionCategory.tip,
          subject: title,
          description: description,
          cardId: _card!.id,
          cardName: _card!.name,
          images: List.unmodifiable(_images),
          publishAnonymously: _anonymous,
        ),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _submitted = true);
    } on ApiException catch (error) {
      debugPrint(
        '[tip-submit] code=${error.code} status=${error.statusCode} '
        'titleLength=${title.runes.length} images=${_images.length}',
      );
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '投稿暂时没有提交成功，请稍后再试。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value, String message, {int minLength = 1}) {
    if ((value?.trim().length ?? 0) < minLength) return message;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('tip-submission-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, 28 + bottomInset),
          children: [
            if (_submitted)
              _TipSubmitted(
                onOpenContributions: widget.onOpenContributions,
                onSubmitAnother: () => setState(() {
                  _submitted = false;
                  _titleController.clear();
                  _experienceController.clear();
                  _savedTitle = '';
                  _savedDescription = '';
                  _images.clear();
                  _confirmedSafe = false;
                }),
              )
            else ...[
              const _TipIntro(),
              const SizedBox(height: 14),
              _TipPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchableCardPicker(
                        key: const Key('tip-card'),
                        cards: widget.cards,
                        selected: _card,
                        sheetKey: const Key('tip-card-picker-sheet'),
                        searchKey: const Key('tip-card-picker-search'),
                        onChanged: (card) => setState(() {
                          _card = card;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('tip-title'),
                        controller: _titleController,
                        maxLength: 80,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '技巧标题',
                          hintText: '用一句话概括这条经验',
                        ),
                        onChanged: (_) {
                          _savedTitle = _titleController.text;
                          if (_error != null) setState(() => _error = null);
                        },
                        onSaved: (value) => _savedTitle = value ?? '',
                        validator: (value) => _required(value, '请填写技巧标题'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('tip-experience'),
                        controller: _experienceController,
                        minLines: 10,
                        maxLines: 18,
                        maxLength: 2000,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          labelText: '经验描述',
                          hintText: '自由分享你的使用经验、操作过程、遇到的问题或需要提醒其他卡友的内容。',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (value) => _savedDescription = value,
                        onSaved: (value) => _savedDescription = value ?? '',
                        validator: (value) => _required(value, '请填写经验描述'),
                      ),
                      const SizedBox(height: 12),
                      _TipImagePicker(
                        images: _images,
                        enabled: !_submitting,
                        onAdd: _pickImages,
                        onRemove: _removeImage,
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile.adaptive(
                          key: const Key('tip-anonymous'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('匿名发布'),
                          subtitle: const Text('审核通过后不展示你的账号昵称'),
                          value: _anonymous,
                          onChanged: (value) =>
                              setState(() => _anonymous = value),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          key: const Key('tip-safe-confirmation'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            '我确认文字和图片不含完整卡号、证件、账号密码、验证码、联系方式、邀请码、返佣或推广内容。',
                          ),
                          value: _confirmedSafe,
                          onChanged: (value) =>
                              setState(() => _confirmedSafe = value ?? false),
                        ),
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 8),
                        Text(
                          error,
                          key: const Key('tip-submit-error'),
                          style: const TextStyle(
                            color: Color(0xFFFF6F83),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const Key('tip-submit'),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 19),
                        label: Text(_submitting ? '正在提交…' : '提交审核'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('tip-submission-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.text,
                    backgroundColor: AppColors.glassStrong,
                    side: BorderSide(color: AppColors.line),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '投稿技巧',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipIntro extends StatelessWidget {
  const _TipIntro();

  @override
  Widget build(BuildContext context) {
    return const _TipPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分享可复核的真实经验',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            '填写一个简洁标题，正文不用套固定模板，在 2000 字内自由分享即可。投稿不会立即公开，内容会经过安全、合规和基础事实核验。',
            style: TextStyle(fontSize: 12.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _TipImagePicker extends StatelessWidget {
  const _TipImagePicker({
    required this.images,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<LocalSubmissionImage> images;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '补充图片（可选）',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '最多 3 张，仅选择有助于说明经验的画面。上传前请遮挡姓名、完整卡号、订单号、地址、二维码和联系方式。',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < images.length; index++) ...[
                  _TipImagePreview(
                    key: ValueKey('tip-image-$index'),
                    image: images[index],
                    index: index,
                    enabled: enabled,
                    onRemove: onRemove,
                  ),
                  if (index != images.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
        if (images.length < maxLocalSubmissionImages) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('tip-add-images'),
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择图片'),
                Text('（${images.length}/$maxLocalSubmissionImages）'),
              ],
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }
}

class _TipImagePreview extends StatelessWidget {
  const _TipImagePreview({
    required this.image,
    required this.index,
    required this.enabled,
    required this.onRemove,
    super.key,
  });

  final LocalSubmissionImage image;
  final int index;
  final bool enabled;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '投稿图片 ${index + 1}',
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: AppColors.glassStrong,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton.filled(
                key: Key('tip-remove-image-$index'),
                onPressed: enabled ? () => onRemove(index) : null,
                tooltip: '移除图片 ${index + 1}',
                icon: const Icon(Icons.close_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: Colors.black.withValues(alpha: 0.72),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black38,
                  disabledForegroundColor: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipSubmitted extends StatelessWidget {
  const _TipSubmitted({
    required this.onOpenContributions,
    required this.onSubmitAnother,
  });

  final VoidCallback onOpenContributions;
  final VoidCallback onSubmitAnother;

  @override
  Widget build(BuildContext context) {
    return _TipPanel(
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, color: AppColors.mint, size: 46),
          const SizedBox(height: 14),
          Text(
            '技巧已提交审核',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '你可以在“消息与反馈 → 贡献”中查看审核进度、采纳结果和管理员回复。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('tip-open-contributions'),
              onPressed: onOpenContributions,
              child: const Text('查看处理进度'),
            ),
          ),
          TextButton(
            key: const Key('tip-submit-another'),
            onPressed: onSubmitAnother,
            child: const Text('再投稿一个'),
          ),
        ],
      ),
    );
  }
}

class _TipPanel extends StatelessWidget {
  const _TipPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}
