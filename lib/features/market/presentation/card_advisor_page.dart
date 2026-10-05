import 'dart:ui';

import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/ai_data_consent_tile.dart';
import 'package:cardfi/core/widgets/premium_motion.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/market/data/card_advisor_repository.dart';
import 'package:cardfi/features/market/domain/card_advisor.dart';
import 'package:cardfi/features/market/widgets/ai_assistant_flow_controls.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/core/motion/celebration_effects.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
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
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();
  AiResidenceSelection _residence = AiResidenceSelection.mainlandChina;
  final Set<String> _documents = {'护照'};
  String _useCase = '日常消费';
  String _kycPreference = '可接受 KYC';
  _AdvisorStep _step = _AdvisorStep.residence;
  bool _loading = false;
  bool _aiDataConsent = false;
  String? _message;
  CardAdvisorResult? _result;
  int _resultCelebrationVersion = 0;

  String get _document => _documents.join('、');

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetScrollPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_aiDataConsent) {
      setState(() => _message = '请先同意将本次资料发送给阿里云百炼处理。');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await widget.repository.advise(
        CardAdvisorProfile(
          residence: _residence.apiResidence,
          residenceCountryCode: _residence.countryCode,
          document: _document,
          useCase: _useCase,
          kycPreference: _kycPreference,
          language: Localizations.localeOf(context).toLanguageTag(),
          note: _noteController.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _resultCelebrationVersion++;
      });
      revealAiAssistantResultAfterLayout(
        pageContext: context,
        resultKey: _resultKey,
        scrollController: _scrollController,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _stepValue => switch (_step) {
    _AdvisorStep.residence => _residence.apiResidence,
    _AdvisorStep.document => _document,
    _AdvisorStep.useCase => _useCase,
    _AdvisorStep.kyc => _kycPreference,
    _AdvisorStep.review => '',
  };

  void _selectOption(String value) {
    AppHaptics.selection();
    setState(() {
      _aiDataConsent = false;
      switch (_step) {
        case _AdvisorStep.residence:
          break;
        case _AdvisorStep.document:
          if (value == '暂不确定') {
            _documents
              ..clear()
              ..add(value);
          } else {
            _documents.remove('暂不确定');
            if (!_documents.add(value)) _documents.remove(value);
            if (_documents.isEmpty) _documents.add('暂不确定');
          }
        case _AdvisorStep.useCase:
          _useCase = value;
        case _AdvisorStep.kyc:
          _kycPreference = value;
        case _AdvisorStep.review:
          break;
      }
    });
  }

  void _previousStep() {
    if (_step == _AdvisorStep.residence) return;
    AppHaptics.selection();
    setState(() {
      _result = null;
      _aiDataConsent = false;
      _step = _AdvisorStep.values[_step.index - 1];
    });
    _resetScrollPosition();
  }

  void _nextStep() {
    if (_step == _AdvisorStep.review) {
      _submit();
      return;
    }
    AppHaptics.mediumImpact();
    setState(() {
      _result = null;
      _step = _AdvisorStep.values[_step.index + 1];
    });
    _resetScrollPosition();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final footerHeight = 148.0 + bottomInset;
    return Scaffold(
      key: const Key('card-advisor-page'),
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, topInset + 82, 20, footerHeight),
            children: [
              _AdvisorConversationHero(step: _step),
              const SizedBox(height: 14),
              _AdvisorProgress(step: _step),
              const SizedBox(height: 16),
              if (_step != _AdvisorStep.review)
                _AdvisorQuestionCard(
                  step: _step,
                  selected: _stepValue,
                  residence: _residence,
                  selectedDocuments: _documents,
                  onSelected: _selectOption,
                  onResidenceChanged: (value) {
                    AppHaptics.selection();
                    setState(() {
                      _residence = value;
                      _aiDataConsent = false;
                    });
                  },
                )
              else
                _AdvisorReviewCard(
                  residence: _residence.localizedName(context),
                  document: _document,
                  useCase: _useCase,
                  kycPreference: _kycPreference,
                  noteController: _noteController,
                  aiDataConsent: _aiDataConsent,
                  onAiDataConsentChanged: (value) => setState(() {
                    _aiDataConsent = value ?? false;
                    _message = null;
                  }),
                  onNoteChanged: (_) {
                    if (_aiDataConsent) {
                      setState(() {
                        _aiDataConsent = false;
                        _message = null;
                      });
                    }
                  },
                ),
              if (_result case final result?) ...[
                const SizedBox(height: 22),
                _ResultSection(
                  key: _resultKey,
                  result: result,
                  cards: widget.cards,
                  onOpenCard: widget.onOpenCard,
                ),
                SizedBox(
                  height: aiAssistantResultTrailingSpace(
                    context,
                    footerHeight: footerHeight,
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            child: _AdvisorBottomBar(
              bottomInset: bottomInset,
              message: _message,
              showLogin: _message != null && _message!.contains('登录'),
              onLogin: widget.onLoginRequired,
              step: _step,
              loading: _loading,
              onBack: _step == _AdvisorStep.residence ? null : _previousStep,
              onNext: _loading ? null : _nextStep,
            ),
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
                      'AI精选好卡',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: AiResultCelebration(trigger: _resultCelebrationVersion),
          ),
        ],
      ),
    );
  }
}

enum _AdvisorStep { residence, document, useCase, kyc, review }

class _AdvisorConversationHero extends StatelessWidget {
  const _AdvisorConversationHero({required this.step});

  final _AdvisorStep step;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9A87FF), Color(0xFF55CBE9)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withValues(alpha: .26),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step == _AdvisorStep.review ? '信息确认' : 'AI精选好卡助手',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step == _AdvisorStep.review
                    ? '请确认下面的条件，我再基于公开资料生成建议。'
                    : '我会像对话一样逐步了解你的情况，再推荐值得进一步了解的卡。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdvisorProgress extends StatelessWidget {
  const _AdvisorProgress({required this.step});

  final _AdvisorStep step;

  @override
  Widget build(BuildContext context) => AiAssistantProgress(
    currentStep: step.index,
    stepCount: _AdvisorStep.values.length,
  );
}

class _AdvisorQuestionCard extends StatelessWidget {
  const _AdvisorQuestionCard({
    required this.step,
    required this.selected,
    required this.residence,
    required this.selectedDocuments,
    required this.onSelected,
    required this.onResidenceChanged,
  });

  final _AdvisorStep step;
  final String selected;
  final AiResidenceSelection residence;
  final Set<String> selectedDocuments;
  final ValueChanged<String> onSelected;
  final ValueChanged<AiResidenceSelection> onResidenceChanged;

  @override
  Widget build(BuildContext context) {
    final prompt = switch (step) {
      _AdvisorStep.residence => (
        '你目前主要居住在哪里？',
        '不同居住地可申请的产品与限制可能不同。',
        const <String>[],
      ),
      _AdvisorStep.document => (
        '你可使用哪类证件？',
        '只选证件类型，不需要填写任何证件号码。',
        ['护照', '身份证', '暂不确定'],
      ),
      _AdvisorStep.useCase => (
        '你更想用卡完成什么？',
        '先从最常见的主要消费场景开始。',
        ['日常消费', '线上订阅', '旅行消费', '收付款'],
      ),
      _AdvisorStep.kyc => (
        '你对认证流程有什么偏好？',
        '这只用于筛选公开资料中可能更匹配的流程。',
        ['可接受 KYC', '希望流程简单', '暂不确定'],
      ),
      _AdvisorStep.review => throw StateError('Review has no question'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: AppColors.violet,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _GlassPanel(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.$1,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      prompt.$2,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (step == _AdvisorStep.residence)
          AiResidenceSelector(
            selection: residence,
            onChanged: onResidenceChanged,
          )
        else
          for (final option in prompt.$3) ...[
            AiAssistantOption(
              label: option,
              selected: step == _AdvisorStep.document
                  ? selectedDocuments.contains(option)
                  : option == selected,
              multiSelect: step == _AdvisorStep.document,
              onTap: () => onSelected(option),
            ),
            if (option != prompt.$3.last) const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _AdvisorReviewCard extends StatelessWidget {
  const _AdvisorReviewCard({
    required this.residence,
    required this.document,
    required this.useCase,
    required this.kycPreference,
    required this.noteController,
    required this.aiDataConsent,
    required this.onAiDataConsentChanged,
    required this.onNoteChanged,
  });

  final String residence;
  final String document;
  final String useCase;
  final String kycPreference;
  final TextEditingController noteController;
  final bool aiDataConsent;
  final ValueChanged<bool?> onAiDataConsentChanged;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '这是我理解的需求',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _AdvisorReviewLine(label: '居住地区', value: residence),
        _AdvisorReviewLine(label: '可用证件', value: document),
        _AdvisorReviewLine(label: '主要场景', value: useCase),
        _AdvisorReviewLine(label: '认证偏好', value: kycPreference),
        const SizedBox(height: 18),
        _GlassNoteField(controller: noteController, onChanged: onNoteChanged),
        const SizedBox(height: 8),
        AiDataConsentTile(
          key: const Key('card-advisor-ai-consent'),
          kind: AiDataConsentKind.cardMatch,
          value: aiDataConsent,
          onChanged: onAiDataConsentChanged,
        ),
      ],
    ),
  );
}

class _AdvisorReviewLine extends StatelessWidget {
  const _AdvisorReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.violet.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.isDark
                      ? const Color(0xFFC7C9FF)
                      : AppColors.violet,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlassNoteField extends StatelessWidget {
  const _GlassNoteField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: TextField(
          key: const Key('card-advisor-note'),
          controller: controller,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            fillColor: AppColors.isDark
                ? const Color(0x4A151B30)
                : const Color(0x78FFFFFF),
            labelText: context.tr('补充条件（可选）'),
            hintText: context.tr('例如：优先线上消费、地区限制或费率说明。请不要填写证件号、卡号、密码等敏感信息。'),
            alignLabelWithHint: true,
          ),
        ),
      ),
    ),
  );
}

class _AdvisorActions extends StatelessWidget {
  const _AdvisorActions({
    required this.step,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  final _AdvisorStep step;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null) ...[
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('card-advisor-previous'),
            onPressed: loading ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('上一步'),
            style: _advisorSecondaryButtonStyle(),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        flex: onBack == null ? 1 : 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF887BFF), Color(0xFF557DFF)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withValues(alpha: .32),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: FilledButton.icon(
            key: const Key('card-advisor-submit'),
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
            icon: loading
                ? const ThinkingOrbs(size: 22, label: '')
                : Icon(
                    step == _AdvisorStep.review
                        ? Icons.auto_awesome_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              loading
                  ? '正在匹配公开资料…'
                  : step == _AdvisorStep.review
                  ? '生成 AI精选好卡建议'
                  : '确认并继续',
            ),
          ),
        ),
      ),
    ],
  );
}

class _AdvisorBottomBar extends StatelessWidget {
  const _AdvisorBottomBar({
    required this.bottomInset,
    required this.message,
    required this.showLogin,
    required this.onLogin,
    required this.step,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  final double bottomInset;
  final String? message;
  final bool showLogin;
  final VoidCallback onLogin;
  final _AdvisorStep step;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.isDark
          ? const Color(0xF20D1326)
          : const Color(0xF8F7F9FF),
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 9, 20, 10 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message case final value?) ...[
            _MessageCard(message: value),
            const SizedBox(height: 8),
          ],
          if (showLogin) ...[
            OutlinedButton.icon(
              key: const Key('card-advisor-login'),
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('去登录'),
              style: _advisorSecondaryButtonStyle(),
            ),
            const SizedBox(height: 8),
          ],
          _AdvisorActions(
            step: step,
            loading: loading,
            onBack: onBack,
            onNext: onNext,
          ),
          const SizedBox(height: 7),
          Text(
            step == _AdvisorStep.review
                ? '不会上传证件、卡号或密码。仅依据你确认的条件与公开资料生成。'
                : '每一步都可以返回修改；最后确认后才会请求 AI 建议。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
  );
}

ButtonStyle _advisorSecondaryButtonStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 54),
  foregroundColor: AppColors.isDark
      ? const Color(0xFFD4D7FF)
      : const Color(0xFF596BDF),
  backgroundColor: AppColors.violet.withValues(
    alpha: AppColors.isDark ? .14 : .08,
  ),
  disabledForegroundColor: AppColors.textMuted.withValues(alpha: .55),
  disabledBackgroundColor: AppColors.line.withValues(alpha: .18),
  side: BorderSide(
    color: AppColors.violet.withValues(alpha: AppColors.isDark ? .4 : .28),
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: const TextStyle(fontWeight: FontWeight.w900),
);

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.isDark
                ? const [Color(0xB51D243B), Color(0x9820263E)]
                : const [Color(0xDFFFFFFF), Color(0xBDEEF2FF)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.isDark
                ? const Color(0x755E698A)
                : const Color(0xCDEBEEFA),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDark
                  ? const Color(0x4D000000)
                  : const Color(0x14576AAB),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
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
    super.key,
  });

  final CardAdvisorResult result;
  final List<CardSummary> cards;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  Widget build(BuildContext context) {
    final cardById = {for (final card in cards) card.id: card};
    return Column(
      key: const Key('card-advisor-result'),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 108,
                    height: 68,
                    child: CardArtwork(card: card, showGeneratedLabels: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (card.issuer.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          card.issuer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
