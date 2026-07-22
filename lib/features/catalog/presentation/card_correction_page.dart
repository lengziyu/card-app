import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/profile/data/local_guest_state.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class CardCorrectionPage extends StatefulWidget {
  const CardCorrectionPage({
    required this.card,
    required this.onBack,
    required this.onSubmit,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onBack;
  final ValueChanged<LocalSubmissionDraft> onSubmit;

  @override
  State<CardCorrectionPage> createState() => _CardCorrectionPageState();
}

class _CardCorrectionPageState extends State<CardCorrectionPage> {
  final _controller = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().length < 8) {
      setState(() => _message = '请至少输入 8 个字的说明');
      return;
    }
    widget.onSubmit(
      LocalSubmissionDraft(
        category: LocalSubmissionCategory.correction,
        description: _controller.text,
        cardId: widget.card.id,
        cardName: widget.card.name,
      ),
    );
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _message = '纠错内容已提交，感谢你的反馈。');
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('card-correction-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, 28 + bottomInset),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.name,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请说明需要更新的字段，并尽量附上官方公开来源。内容会先保存到本机。',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('correction-description'),
                    controller: _controller,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: '纠错说明',
                      hintText: '例如：年费信息已经更新，官方页面显示……',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      key: const Key('correction-result'),
                      style: TextStyle(
                        color: _message!.startsWith('纠错')
                            ? AppColors.mint
                            : const Color(0xFFFF8496),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('correction-submit'),
                    onPressed: _submit,
                    child: const Text('提交纠错'),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '当前不会上传；可在“消息与反馈”中查看或删除。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('correction-back'),
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
                  '纠正信息',
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

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
