import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reveals an AI result below the overlaid page header instead of aligning it
/// with the raw viewport edge, where its title would be covered.
void revealAiAssistantResultAfterLayout({
  required BuildContext pageContext,
  required GlobalKey resultKey,
  required ScrollController scrollController,
  double stickyHeaderHeight = 72,
  double topGap = 10,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!pageContext.mounted || !scrollController.hasClients) return;
    final targetContext = resultKey.currentContext;
    final renderObject = targetContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;

    final safeTop =
        MediaQuery.paddingOf(pageContext).top + stickyHeaderHeight + topGap;
    final revealedOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final position = scrollController.position;
    final targetOffset = (revealedOffset - safeTop)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - targetOffset).abs() < .5) return;

    if (MediaQuery.disableAnimationsOf(pageContext)) {
      scrollController.jumpTo(targetOffset);
      return;
    }
    scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  });
}

/// Keeps enough scroll extent after a short result to place its heading below
/// the sticky header. The page's existing bottom padding still protects it
/// from the overlaid action bar.
double aiAssistantResultTrailingSpace(
  BuildContext context, {
  required double footerHeight,
  double stickyHeaderHeight = 72,
  double topGap = 10,
}) {
  final viewportHeight = MediaQuery.sizeOf(context).height;
  final safeTop =
      MediaQuery.paddingOf(context).top + stickyHeaderHeight + topGap;
  return (viewportHeight - safeTop - footerHeight)
      .clamp(0, double.infinity)
      .toDouble();
}

@immutable
class AiResidenceSelection {
  const AiResidenceSelection({
    required this.countryCode,
    required this.canonicalName,
  });

  static const mainlandChina = AiResidenceSelection(
    countryCode: 'CN',
    canonicalName: 'Mainland China',
  );
  static final CountryService _countryService = CountryService();

  final String countryCode;
  final String canonicalName;

  bool get isMainlandChina => countryCode == 'CN';

  /// Keep the legacy text field while the API migrates to the ISO code.
  String get apiResidence => isMainlandChina ? '中国大陆' : canonicalName;

  String localizedName(BuildContext context) {
    if (isMainlandChina) return context.tr('中国大陆');
    final country = _countryService.findByCode(countryCode);
    return country?.getTranslatedName(context) ?? canonicalName;
  }
}

/// Shared controls for the two guided AI flows, so their questions feel like
/// one product rather than two separately styled forms.
class AiAssistantProgress extends StatelessWidget {
  const AiAssistantProgress({
    required this.currentStep,
    required this.stepCount,
    super.key,
  });

  final int currentStep;
  final int stepCount;

  static const _colors = <Color>[
    Color(0xFFA57CFF),
    Color(0xFF9875FF),
    Color(0xFF837CF8),
    Color(0xFF6D90F7),
    Color(0xFF57A8F5),
    Color(0xFF4CC4EE),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: List.generate(stepCount, (index) {
        final active = index <= currentStep;
        final current = index == currentStep;
        final color = _colors[index % _colors.length];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 5),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$index-$active-$current'),
              duration: reduceMotion
                  ? Duration.zero
                  : Duration(milliseconds: 420 + index * 55),
              curve: Curves.easeOutBack,
              tween: Tween(begin: active ? .72 : .94, end: 1),
              builder: (context, value, _) => Transform.scale(
                // Keep every segment at the same width even before it is
                // active. Only the vertical arrival motion changes.
                scaleY: value,
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : MotionTokens.stateChange,
                  height: current ? 9 : 5,
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(
                            colors: [
                              color.withValues(alpha: .78),
                              color,
                              Color.lerp(color, AppColors.cyan, .3)!,
                            ],
                          )
                        : null,
                    color: active
                        ? null
                        : AppColors.line.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: .7),
                              blurRadius: 20,
                              spreadRadius: 1.2,
                            ),
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: .22),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class AiAssistantOption extends StatelessWidget {
  const AiAssistantOption({
    required this.label,
    required this.selected,
    required this.multiSelect,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizedLabel = context.tr(label);
    return Semantics(
      button: true,
      selected: selected,
      label: localizedLabel,
      child: MotionPressEffect(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : MotionTokens.stateChange,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF847CF4), Color(0xFF5D8CFA)],
                    )
                  : LinearGradient(
                      colors: AppColors.isDark
                          ? const [Color(0xA3242B45), Color(0x80212A42)]
                          : const [Color(0xD9FFFFFF), Color(0xBEEEF2FF)],
                    ),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected
                    ? const Color(0xFFC8C6FF).withValues(alpha: .8)
                    : AppColors.line.withValues(alpha: .38),
                width: selected ? 1.1 : .9,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: .2),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localizedLabel,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? (multiSelect
                            ? Icons.check_box_rounded
                            : Icons.radio_button_checked_rounded)
                      : (multiSelect
                            ? Icons.check_box_outline_blank_rounded
                            : Icons.radio_button_unchecked_rounded),
                  color: selected ? Colors.white : AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiResidenceSelector extends StatelessWidget {
  const AiResidenceSelector({
    required this.selection,
    required this.onChanged,
    this.businessApplicant = false,
    super.key,
  });

  final AiResidenceSelection selection;
  final ValueChanged<AiResidenceSelection> onChanged;
  final bool businessApplicant;

  @override
  Widget build(BuildContext context) {
    final otherSelected = !selection.isMainlandChina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.glassStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ResidenceModeButton(
                  key: const Key('ai-residence-mainland'),
                  label: context.tr('中国大陆'),
                  selected: selection.isMainlandChina,
                  onTap: () => onChanged(AiResidenceSelection.mainlandChina),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ResidenceModeButton(
                  key: const Key('ai-residence-other'),
                  label: context.tr('其他国家或地区'),
                  selected: otherSelected,
                  onTap: () => _showPicker(context),
                ),
              ),
            ],
          ),
        ),
        if (otherSelected) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('ai-residence-country'),
              onTap: () => _showPicker(context),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    _CountryCodeBadge(code: selection.countryCode),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        selection.localizedName(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Text(
          context.tr(
            businessApplicant
                ? '请选择企业注册所在的国家或地区。'
                : '请选择你目前长期居住的国家或地区，不是护照签发国。',
          ),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showCountryPicker(
      context: context,
      exclude: const ['CN'],
      useSafeArea: true,
      showPhoneCode: false,
      searchAutofocus: false,
      header: Padding(
        key: const Key('ai-residence-country-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Text(
          context.tr('选择国家或地区'),
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      customFlagBuilder: (country) =>
          _CountryCodeBadge(code: country.countryCode),
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.isDark
            ? const Color(0xFF151A2B)
            : const Color(0xFFF7F8FF),
        textStyle: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        searchTextStyle: TextStyle(color: AppColors.text, fontSize: 15),
        inputDecoration: InputDecoration(
          hintText: context.tr('搜索国家或地区'),
          prefixIcon: const Icon(Icons.search_rounded),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        bottomSheetHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      onSelect: (country) {
        onChanged(
          AiResidenceSelection(
            countryCode: country.countryCode,
            canonicalName: country.name,
          ),
        );
      },
    );
  }
}

class _ResidenceModeButton extends StatelessWidget {
  const _ResidenceModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MotionTokens.stateChange,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF847CF4), Color(0xFF5D8CFA)],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 11.5,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _CountryCodeBadge extends StatelessWidget {
  const _CountryCodeBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.violet.withValues(alpha: .24)),
    ),
    child: Text(
      code,
      style: TextStyle(
        color: AppColors.isDark ? const Color(0xFFC7C9FF) : AppColors.violet,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );
}
