import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:flutter/material.dart';

class CardCorrectionPage extends StatefulWidget {
  const CardCorrectionPage({
    required this.card,
    required this.onBack,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onBack;

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
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _message = '纠错表单预览完成，内容未发送或保存。');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: Key('card-correction-page'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              key: Key('correction-back'),
              onPressed: widget.onBack,
              tooltip: '返回',
              icon: Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: Size(48, 48),
                foregroundColor: AppColors.text,
                backgroundColor: AppColors.glassStrong,
                side: BorderSide(color: AppColors.line),
              ),
            ),
            SizedBox(width: 14),
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
        SizedBox(height: 22),
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
              SizedBox(height: 8),
              Text(
                '请说明需要更新的字段，并尽量附上官方公开来源。当前仅预览表单交互。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: Key('correction-description'),
                controller: _controller,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: '纠错说明',
                  hintText: '例如：年费信息已经更新，官方页面显示……',
                ),
              ),
              if (_message != null) ...[
                SizedBox(height: 12),
                Text(
                  _message!,
                  key: Key('correction-result'),
                  style: TextStyle(
                    color: _message!.startsWith('纠错')
                        ? AppColors.mint
                        : Color(0xFFFF8496),
                    fontSize: 12.5,
                  ),
                ),
              ],
              SizedBox(height: 16),
              FilledButton(
                key: Key('correction-submit'),
                onPressed: _submit,
                child: Text('预览提交'),
              ),
              SizedBox(height: 9),
              Text(
                '账号与反馈服务暂未接入，输入内容不会上传。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ],
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
