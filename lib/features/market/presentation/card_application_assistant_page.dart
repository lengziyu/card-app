import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/celebration_effects.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/ai_data_consent_tile.dart';
import 'package:cardfi/core/widgets/premium_motion.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/searchable_card_picker.dart';
import 'package:cardfi/features/market/data/card_application_assistant_repository.dart';
import 'package:cardfi/features/market/domain/card_application_assistant.dart';
import 'package:cardfi/features/market/widgets/ai_assistant_flow_controls.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CardApplicationAssistantPage extends StatefulWidget {
  const CardApplicationAssistantPage({
    required this.repository,
    required this.cards,
    required this.enableRemoteData,
    required this.onBack,
    required this.onLoginRequired,
    required this.onProRequired,
    this.onOpenArticle,
    this.initialCard,
    super.key,
  });

  final CardApplicationAssistantRepository repository;
  final List<CardSummary> cards;
  final bool enableRemoteData;
  final CardSummary? initialCard;
  final VoidCallback onBack;
  final VoidCallback onLoginRequired;
  final VoidCallback onProRequired;
  final ValueChanged<String>? onOpenArticle;

  @override
  State<CardApplicationAssistantPage> createState() =>
      _CardApplicationAssistantPageState();
}

class _CardApplicationAssistantPageState
    extends State<CardApplicationAssistantPage> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();
  late final List<CardSummary> _cards;
  late CardSummary _card;
  late _ApplicationStep _step;
  AiResidenceSelection _residence = AiResidenceSelection.mainlandChina;
  String _applicantType = '个人申请';
  final Set<String> _documents = {'护照'};
  String _stage = '准备申请';
  bool _loading = false;
  bool _aiDataConsent = false;
  String? _message;
  String? _messageCode;
  CardApplicationAssistantResult? _result;
  int _resultCelebrationVersion = 0;

  String get _document => _documents.join('、');

  @override
  void initState() {
    super.initState();
    _cards = widget.cards
        .where((card) => !card.isGlobalAccount)
        .toList(growable: false);
    _card = widget.initialCard?.isGlobalAccount == false
        ? widget.initialCard!
        : _cards.first;
    _step = widget.initialCard == null
        ? _ApplicationStep.card
        : _ApplicationStep.applicantType;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _selectedValue => switch (_step) {
    _ApplicationStep.card => _card.id,
    _ApplicationStep.residence => _residence.apiResidence,
    _ApplicationStep.applicantType => _applicantType,
    _ApplicationStep.document => _document,
    _ApplicationStep.stage => _stage,
    _ApplicationStep.review => '',
  };

  void _select(String value) {
    AppHaptics.selection();
    setState(() {
      _result = null;
      _aiDataConsent = false;
      switch (_step) {
        case _ApplicationStep.card:
          _card = _cards.firstWhere((card) => card.id == value);
        case _ApplicationStep.residence:
          break;
        case _ApplicationStep.applicantType:
          _applicantType = value;
        case _ApplicationStep.document:
          if (value == '材料待确认') {
            _documents
              ..clear()
              ..add(value);
          } else {
            _documents.remove('材料待确认');
            if (!_documents.add(value)) _documents.remove(value);
            if (_documents.isEmpty) _documents.add('材料待确认');
          }
        case _ApplicationStep.stage:
          _stage = value;
        case _ApplicationStep.review:
          break;
      }
    });
  }

  void _previous() {
    if (_step == _ApplicationStep.card) return;
    AppHaptics.selection();
    setState(() {
      _result = null;
      _aiDataConsent = false;
      _message = null;
      _step = _ApplicationStep.values[_step.index - 1];
    });
    _resetScrollPosition();
  }

  void _next() {
    if (_step == _ApplicationStep.review) {
      _submit();
      return;
    }
    AppHaptics.mediumImpact();
    setState(() {
      _result = null;
      _message = null;
      _step = _ApplicationStep.values[_step.index + 1];
    });
    _resetScrollPosition();
  }

  void _resetScrollPosition() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_aiDataConsent) {
      setState(() {
        _messageCode = 'AI_DATA_CONSENT_REQUIRED';
        _message = '请先同意将本次资料发送给阿里云百炼处理。';
      });
      return;
    }
    if (!widget.enableRemoteData) {
      setState(() {
        _messageCode = 'SERVICE_UNAVAILABLE';
        _message = '连接正式服务后才能生成 AI 协助开卡清单。';
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _messageCode = null;
    });
    try {
      final result = await widget.repository.prepare(
        CardApplicationProfile(
          cardId: _card.id,
          residence: _residence.apiResidence,
          residenceCountryCode: _residence.countryCode,
          applicantType: _applicantType,
          document: _document,
          stage: _stage,
          language: Localizations.localeOf(context).toLanguageTag(),
          question: _questionController.text.trim(),
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
      setState(() {
        _messageCode = error.code;
        _message = error.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RestartConfirmationSheet(
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;
    AppHaptics.selection();
    setState(() {
      _result = null;
      _message = null;
      _messageCode = null;
      _step = _ApplicationStep.card;
      _aiDataConsent = false;
    });
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final footerHeight = 144.0 + bottomInset;
    return Scaffold(
      key: const Key('card-application-assistant-page'),
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, topInset + 82, 20, footerHeight),
            children: [
              AiAssistantStepTransition(
                step: _step.index,
                child: _ApplicationHero(
                  card: _card,
                  step: _step,
                  businessApplicant: _applicantType == '企业申请',
                ),
              ),
              const SizedBox(height: 14),
              _ApplicationProgress(step: _step),
              const SizedBox(height: 16),
              AiAssistantStepTransition(
                step: _step.index,
                child: _step == _ApplicationStep.review
                    ? _ReviewPanel(
                        card: _card,
                        residence: _residence.localizedName(context),
                        applicantType: _applicantType,
                        document: _document,
                        stage: _stage,
                        controller: _questionController,
                        aiDataConsent: _aiDataConsent,
                        onAiDataConsentChanged: (value) => setState(() {
                          _aiDataConsent = value ?? false;
                          _message = null;
                          _messageCode = null;
                        }),
                        onQuestionChanged: (_) {
                          if (_aiDataConsent) {
                            setState(() {
                              _aiDataConsent = false;
                              _message = null;
                              _messageCode = null;
                            });
                          }
                        },
                      )
                    : _QuestionPanel(
                        step: _step,
                        cards: _cards,
                        selected: _selectedValue,
                        residence: _residence,
                        businessApplicant: _applicantType == '企业申请',
                        selectedDocuments: _documents,
                        onSelected: _select,
                        onResidenceChanged: (value) {
                          AppHaptics.selection();
                          setState(() {
                            _result = null;
                            _residence = value;
                            _aiDataConsent = false;
                          });
                        },
                      ),
              ),
              if (_result case final result?) ...[
                const SizedBox(height: 22),
                _ApplicationResult(
                  key: _resultKey,
                  result: result,
                  onOpenArticle: widget.onOpenArticle,
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
            child: _ApplicationBottomBar(
              bottomInset: bottomInset,
              message: _message,
              messageCode: _messageCode,
              onLogin: widget.onLoginRequired,
              onPro: widget.onProRequired,
              firstStep: _step == _ApplicationStep.card,
              review: _step == _ApplicationStep.review,
              hasResult: _result != null,
              loading: _loading,
              onPrevious: _previous,
              onNext: _next,
              onRestart: _confirmRestart,
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
                    key: const Key('application-assistant-back'),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip: context.tr('返回'),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'AI 协助开卡',
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

enum _ApplicationStep {
  card,
  applicantType,
  residence,
  document,
  stage,
  review,
}

extension on _ApplicationStep {
  String title({required bool businessApplicant}) => switch (this) {
    _ApplicationStep.card => '你想准备申请哪张卡？',
    _ApplicationStep.applicantType => '你使用什么主体申请？',
    _ApplicationStep.residence =>
      businessApplicant ? '企业注册国家或地区是？' : '你的居住国家或地区是？',
    _ApplicationStep.document => '你可以使用哪类材料？',
    _ApplicationStep.stage => '你现在处于哪个阶段？',
    _ApplicationStep.review => '确认申请准备条件',
  };
}

class _ApplicationHero extends StatelessWidget {
  const _ApplicationHero({
    required this.card,
    required this.step,
    required this.businessApplicant,
  });

  final CardSummary card;
  final _ApplicationStep step;
  final bool businessApplicant;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A70FF), Color(0xFF52C8F0)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title(businessApplicant: businessApplicant),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${card.name} · 优先检索项目文章',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _ApplicationProgress extends StatelessWidget {
  const _ApplicationProgress({required this.step});

  final _ApplicationStep step;

  @override
  Widget build(BuildContext context) => AiAssistantProgress(
    currentStep: step.index,
    stepCount: _ApplicationStep.values.length,
  );
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.step,
    required this.cards,
    required this.selected,
    required this.residence,
    required this.businessApplicant,
    required this.selectedDocuments,
    required this.onSelected,
    required this.onResidenceChanged,
  });

  final _ApplicationStep step;
  final List<CardSummary> cards;
  final String selected;
  final AiResidenceSelection residence;
  final bool businessApplicant;
  final Set<String> selectedDocuments;
  final ValueChanged<String> onSelected;
  final ValueChanged<AiResidenceSelection> onResidenceChanged;

  List<String> get _options => switch (step) {
    _ApplicationStep.residence => const [],
    _ApplicationStep.applicantType => const ['个人申请', '企业申请'],
    _ApplicationStep.document => const ['护照', '身份证', '地址证明', '材料待确认'],
    _ApplicationStep.stage => const ['准备申请', '填写申请', '等待审核', '收卡与激活'],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: switch (step) {
        _ApplicationStep.card => SearchableCardPicker(
          key: const Key('application-assistant-card-picker'),
          cards: cards,
          selected: cards.firstWhere(
            (card) => card.id == selected,
            orElse: () => cards.first,
          ),
          label: '目标卡片',
          sheetTitle: '选择目标卡片',
          sheetKey: const Key('application-card-picker-sheet'),
          searchKey: const Key('application-card-picker-search'),
          onChanged: (card) => onSelected(card.id),
        ),
        _ApplicationStep.residence => AiResidenceSelector(
          selection: residence,
          businessApplicant: businessApplicant,
          onChanged: onResidenceChanged,
        ),
        _ => Column(
          children: [
            for (final option in _options) ...[
              AiAssistantOption(
                key: Key('application-option-$option'),
                label: option,
                selected: _isSelected(option),
                multiSelect: step == _ApplicationStep.document,
                onTap: () => onSelected(option),
              ),
              if (option != _options.last) const SizedBox(height: 9),
            ],
          ],
        ),
      },
    );
  }

  bool _isSelected(String option) => step == _ApplicationStep.document
      ? selectedDocuments.contains(option)
      : selected == option;
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.card,
    required this.residence,
    required this.applicantType,
    required this.document,
    required this.stage,
    required this.controller,
    required this.aiDataConsent,
    required this.onAiDataConsentChanged,
    required this.onQuestionChanged,
  });

  final CardSummary card;
  final String residence;
  final String applicantType;
  final String document;
  final String stage;
  final TextEditingController controller;
  final bool aiDataConsent;
  final ValueChanged<bool?> onAiDataConsentChanged;
  final ValueChanged<String> onQuestionChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '这是我理解的准备条件',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ReviewLine(label: '目标卡片', value: card.name),
          _ReviewLine(label: '申请主体', value: applicantType),
          _ReviewLine(
            label: applicantType == '企业申请' ? '企业注册地' : '居住地区',
            value: residence,
          ),
          _ReviewLine(label: '可用材料', value: document),
          _ReviewLine(label: '当前阶段', value: stage),
          const SizedBox(height: 18),
          TextField(
            key: const Key('application-assistant-question'),
            controller: controller,
            onChanged: onQuestionChanged,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            decoration: const InputDecoration(
              labelText: '想确认的问题（可选）',
              alignLabelWithHint: true,
              hintText: '例如：需要准备哪些材料，哪些费用需要再去官网确认？',
            ),
          ),
          const SizedBox(height: 8),
          AiDataConsentTile(
            key: const Key('application-assistant-ai-consent'),
            kind: AiDataConsentKind.applicationPrep,
            value: aiDataConsent,
            onChanged: onAiDataConsentChanged,
          ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

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
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
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

class _ApplicationActions extends StatelessWidget {
  const _ApplicationActions({
    required this.firstStep,
    required this.review,
    required this.hasResult,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
    required this.onRestart,
  });

  final bool firstStep;
  final bool review;
  final bool hasResult;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (hasResult)
          Expanded(
            child: FilledButton.icon(
              key: const Key('application-assistant-restart'),
              onPressed: loading ? null : onRestart,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('重新开始'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          )
        else ...[
          if (!firstStep) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                key: const Key('application-assistant-previous'),
                onPressed: loading ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('上一步'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.glassStrong,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: firstStep ? 1 : 4,
            child: FilledButton.icon(
              key: const Key('application-assistant-submit'),
              onPressed: loading ? null : onNext,
              icon: loading
                  ? const ThinkingOrbs(size: 22, label: '')
                  : Icon(
                      review
                          ? Icons.auto_awesome_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                loading
                    ? '正在检索项目文章…'
                    : review
                    ? '生成开卡准备清单'
                    : '下一步',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ApplicationBottomBar extends StatelessWidget {
  const _ApplicationBottomBar({
    required this.bottomInset,
    required this.message,
    required this.messageCode,
    required this.onLogin,
    required this.onPro,
    required this.firstStep,
    required this.review,
    required this.hasResult,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
    required this.onRestart,
  });

  final double bottomInset;
  final String? message;
  final String? messageCode;
  final VoidCallback onLogin;
  final VoidCallback onPro;
  final bool firstStep;
  final bool review;
  final bool hasResult;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRestart;

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
            _InlineMessage(message: value),
            const SizedBox(height: 8),
          ],
          if (messageCode == 'UNAUTHORIZED') ...[
            OutlinedButton.icon(
              key: const Key('application-assistant-login'),
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('去登录'),
            ),
            const SizedBox(height: 8),
          ],
          if (messageCode == 'PRO_REQUIRED') ...[
            OutlinedButton.icon(
              key: const Key('application-assistant-pro'),
              onPressed: onPro,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('查看 Pro 权益'),
            ),
            const SizedBox(height: 8),
          ],
          _ApplicationActions(
            firstStep: firstStep,
            review: review,
            hasResult: hasResult,
            loading: loading,
            onPrevious: onPrevious,
            onNext: onNext,
            onRestart: onRestart,
          ),
          const SizedBox(height: 7),
          Text(
            hasResult
                ? '结果仅在本次页面查看；重新开始不会保留当前清单。'
                : review
                ? '请不要填写证件号、卡号、密码、验证码或助记词。'
                : '只需选择材料类型，不会要求上传证件或账户凭据。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ApplicationResult extends StatelessWidget {
  const _ApplicationResult({
    required this.result,
    this.onOpenArticle,
    super.key,
  });

  final CardApplicationAssistantResult result;
  final ValueChanged<String>? onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('application-assistant-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '开卡准备清单',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            _SourceModeBadge(mode: result.sourceMode),
          ],
        ),
        const SizedBox(height: 10),
        _Panel(
          child: Text(
            result.summary,
            style: const TextStyle(fontSize: 13, height: 1.55),
          ),
        ),
        if (result.checklist.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ResultGroup(
            title: '按步骤准备',
            icon: Icons.checklist_rounded,
            children: [
              for (var index = 0; index < result.checklist.length; index++)
                _ChecklistRow(index: index, item: result.checklist[index]),
            ],
          ),
        ],
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _StringResultGroup(
            title: '风险提醒',
            icon: Icons.warning_amber_rounded,
            items: result.warnings,
          ),
        ],
        if (result.unknowns.isNotEmpty) ...[
          const SizedBox(height: 14),
          _StringResultGroup(
            title: '仍需官方确认',
            icon: Icons.help_outline_rounded,
            items: result.unknowns,
          ),
        ],
        if (result.nextSteps.isNotEmpty) ...[
          const SizedBox(height: 14),
          _StringResultGroup(
            title: '下一步',
            icon: Icons.arrow_circle_right_outlined,
            items: result.nextSteps,
          ),
        ],
        if (result.sources.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SourcesGroup(sources: result.sources, onOpenArticle: onOpenArticle),
        ],
        const SizedBox(height: 12),
        Text(
          result.disclaimer.isEmpty
              ? '仅基于公开资料提供申请准备提醒，不代办、不提交申请，不保证开卡或审核成功。'
              : result.disclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SourceModeBadge extends StatelessWidget {
  const _SourceModeBadge({required this.mode});
  final String mode;

  String get _label => switch (mode) {
    'official_web' => '官网补充',
    'mixed' => '文章＋官网',
    _ => '项目文章',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      _label,
      style: TextStyle(
        color: AppColors.violet,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.violet, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.index, required this.item});
  final int index;
  final CardApplicationChecklistItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: AppColors.violet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.detail,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
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

class _StringResultGroup extends StatelessWidget {
  const _StringResultGroup({
    required this.title,
    required this.icon,
    required this.items,
  });
  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => _ResultGroup(
    title: title,
    icon: icon,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.violet,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _SourcesGroup extends StatelessWidget {
  const _SourcesGroup({required this.sources, this.onOpenArticle});
  final List<CardApplicationSource> sources;
  final ValueChanged<String>? onOpenArticle;

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => _ResultGroup(
    title: '资料来源',
    icon: Icons.source_outlined,
    children: [
      for (final source in sources)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            key: Key('application-source-${source.id}'),
            onTap: source.isProjectArticle
                ? source.articleSlug == null || onOpenArticle == null
                      ? null
                      : () => onOpenArticle!(source.articleSlug!)
                : source.url.isEmpty
                ? null
                : () => _open(source.url),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.glassStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      source.isProjectArticle ? '项目文章' : '官方网页',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      source.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (source.isProjectArticle || source.url.isNotEmpty)
                    Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.violet.withValues(alpha: .24)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.violet),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 11.5, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _RestartConfirmationSheet extends StatelessWidget {
  const _RestartConfirmationSheet({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
    decoration: BoxDecoration(
      color: AppColors.isDark ? const Color(0xFF171D33) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '重新开始 AI 协助开卡？',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '当前清单只在本次页面展示，重新开始后将返回第一步。',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('继续查看'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('从第一步开始'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
      boxShadow: AppColors.isDark
          ? null
          : const [
              BoxShadow(
                color: Color(0x105A67A0),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
    ),
    child: child,
  );
}
