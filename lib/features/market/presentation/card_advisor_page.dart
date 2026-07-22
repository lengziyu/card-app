import 'package:card_app/core/localization/localized_text.dart';
import 'package:card_app/core/localization/app_localizations.dart';
import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/market/data/card_advisor_repository.dart';
import 'package:card_app/features/market/domain/card_advisor.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/material.dart' hide Text;

class CardAdvisorPage extends StatefulWidget {
  const CardAdvisorPage({
    required this.repository,
    required this.cards,
    required this.onBack,
    required this.onOpenCard,
    required this.onLoginRequired,
    super.key,
  });

  final CardAdvisorRepository repository;
  final List<CardSummary> cards;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final VoidCallback onLoginRequired;

  @override
  State<CardAdvisorPage> createState() => _CardAdvisorPageState();
}

class _CardAdvisorPageState extends State<CardAdvisorPage> {
  final _noteController = TextEditingController();
  String _residence = '中国大陆';
  String _document = '护照';
  String _useCase = '日常消费';
  String _kycPreference = '可接受 KYC';
  bool _loading = false;
  String? _message;
  CardAdvisorResult? _result;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await widget.repository.advise(
        CardAdvisorProfile(
          residence: _residence,
          document: _document,
          useCase: _useCase,
          kycPreference: _kycPreference,
          language: Localizations.localeOf(context).toLanguageTag(),
          note: _noteController.text,
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: const Key('card-advisor-page'),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              topInset + 82,
              20,
              32 + bottomInset,
            ),
            children: [
              _Hero(),
              const SizedBox(height: 16),
              _ChoiceSection(
                title: '所在地',
                options: const ['中国大陆', '港澳台', '海外'],
                value: _residence,
                onChanged: (value) => setState(() => _residence = value),
              ),
              const SizedBox(height: 14),
              _ChoiceSection(
                title: '可使用证件',
                options: const ['护照', '身份证', '暂不确定'],
                value: _document,
                onChanged: (value) => setState(() => _document = value),
              ),
              const SizedBox(height: 14),
              _ChoiceSection(
                title: '主要用途',
                options: const ['日常消费', '线上订阅', '旅行消费', '收付款'],
                value: _useCase,
                onChanged: (value) => setState(() => _useCase = value),
              ),
              const SizedBox(height: 14),
              _ChoiceSection(
                title: 'KYC 偏好',
                options: const ['可接受 KYC', '希望流程简单', '暂不确定'],
                value: _kycPreference,
                onChanged: (value) => setState(() => _kycPreference = value),
              ),
              const SizedBox(height: 16),
              _NoteField(controller: _noteController),
              const SizedBox(height: 14),
              if (_message case final message?) ...[
                _MessageCard(message: message),
                const SizedBox(height: 10),
              ],
              if (_message != null && _message!.contains('登录'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: widget.onLoginRequired,
                    child: Text('去登录'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('card-advisor-submit'),
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_loading ? '正在匹配公开资料…' : '生成 AI 选卡建议'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '不会上传证件、卡号或密码。建议仅按你填写的条件与收录资料生成。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              if (_result case final result?) ...[
                const SizedBox(height: 22),
                _ResultSection(
                  result: result,
                  cards: widget.cards,
                  onOpenCard: widget.onOpenCard,
                ),
              ],
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StickyPageHeader(
              height: 72,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('card-advisor-back'),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip: context.tr('返回'),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI 选卡',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.auto_awesome_rounded, color: AppColors.violet),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.isDark
            ? const [Color(0xFF303752), Color(0xFF1C223A)]
            : const [Color(0xFFF4F1FF), Color(0xFFEAF7FF)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '告诉我你的条件',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          'AI 会从集卡已收录的公开资料里筛选适合进一步了解的卡片，并列出需要到官方页面确认的限制。',
          style: const TextStyle(
            fontSize: 12,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: option == value,
              onSelected: (_) {
                AppHaptics.selection();
                onChanged(option);
              },
            ),
        ],
      ),
    ],
  );
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('card-advisor-note'),
    controller: controller,
    minLines: 3,
    maxLines: 4,
    maxLength: 500,
    decoration: InputDecoration(
      labelText: context.tr('补充条件（可选）'),
      hintText: context.tr('例如：希望优先了解线上消费、地区限制或费率说明。请不要填写证件号、卡号、密码等敏感信息。'),
      alignLabelWithHint: true,
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.isDark
          ? const Color(0x332F3656)
          : const Color(0xFFF1EFFF),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.violet),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.cards,
    required this.onOpenCard,
  });

  final CardAdvisorResult result;
  final List<CardSummary> cards;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  Widget build(BuildContext context) {
    final cardById = {for (final card in cards) card.id: card};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '匹配结果',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          result.summary,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (result.recommendations.isEmpty)
          _MessageCard(message: '当前公开资料不足以匹配具体卡片。建议补充用途后重试，并直接查看卡片目录。'),
        for (final advice in result.recommendations)
          if (cardById[advice.cardId] case final card?) ...[
            _RecommendationCard(
              card: card,
              advice: advice,
              onTap: () => onOpenCard(card),
            ),
            const SizedBox(height: 10),
          ],
        if (result.nextSteps.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            '下一步确认',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          for (final step in result.nextSteps)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '• $step',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          result.disclaimer,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.card,
    required this.advice,
    required this.onTap,
  });
  final CardSummary card;
  final CardAdvisorRecommendation advice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: Key('card-advisor-result-${card.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.glassStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            if (card.issuer.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                card.issuer,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              advice.reason,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${context.tr('需确认：')}${advice.cautions}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
