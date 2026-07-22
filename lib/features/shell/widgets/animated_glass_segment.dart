import 'dart:ui';

import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class GlassSegmentItem<T> {
  const GlassSegmentItem({required this.value, required this.label, this.key});

  final T value;
  final String label;
  final Key? key;
}

class AnimatedGlassSegment<T> extends StatelessWidget {
  const AnimatedGlassSegment({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.height = 48,
    this.padding = 4,
    this.fontSize = 13,
    this.radius = 24,
    this.showOuterSurface = true,
    super.key,
  });

  final List<GlassSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final double padding;
  final double fontSize;
  final double radius;
  final bool showOuterSurface;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectedIndex = items.indexWhere((item) => item.value == selected);
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final duration = reduceMotion ? Duration.zero : MotionTokens.contentSwitch;
    const curve = MotionTokens.standardEnter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                (constraints.maxWidth - padding * 2) / items.length;
            return Container(
              key: const Key('animated-glass-segment-surface'),
              height: height,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: showOuterSurface
                    ? (AppColors.isDark
                          ? const Color(0xA6232737)
                          : const Color(0x247382A8))
                    : Colors.transparent,
                gradient: showOuterSurface && !AppColors.isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x2C8B9AC0), Color(0x18798AAD)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(radius),
                border: showOuterSurface && AppColors.isDark
                    ? Border.all(color: AppColors.line)
                    : null,
                boxShadow: showOuterSurface
                    ? [
                        BoxShadow(
                          color: AppColors.isDark
                              ? const Color(0x33000000)
                              : const Color(0x12646FA8),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: curve,
                    // Keep a one-pixel breathing space at either edge.  The
                    // selected indicator has a border and shadow, which used
                    // to be visibly clipped when the last segment was active.
                    left: safeIndex * itemWidth + 1,
                    top: 1,
                    bottom: 1,
                    width: itemWidth - 2,
                    child: DecoratedBox(
                      key: const Key('animated-glass-segment-indicator'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: AppColors.isDark
                              ? const [Color(0x57969EEA), Color(0x706771C2)]
                              : const [Color(0xF7FFFFFF), Color(0xE8FFFFFF)],
                        ),
                        borderRadius: BorderRadius.circular(radius - padding),
                        border: AppColors.isDark
                            ? Border.all(color: const Color(0x1FFFFFFF))
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.isDark
                                ? const Color(0x47503C88)
                                : const Color(0x145360B4),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: index == safeIndex,
                            child: MotionPressEffect(
                              child: InkWell(
                                key: items[index].key,
                                onTap: () {
                                  if (items[index].value == selected) return;
                                  AppHaptics.selection();
                                  onChanged(items[index].value);
                                },
                                borderRadius: BorderRadius.circular(radius),
                                child: AnimatedScale(
                                  duration: duration,
                                  curve: curve,
                                  scale: index == safeIndex ? 1 : 0.975,
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: reduceMotion
                                          ? Duration.zero
                                          : MotionTokens.stateChange,
                                      curve: MotionTokens.standardEnter,
                                      style: TextStyle(
                                        color: index == safeIndex
                                            ? (AppColors.isDark
                                                  ? const Color(0xFFEDF2FF)
                                                  : const Color(0xFF6070FF))
                                            : AppColors.textMuted,
                                        fontSize: fontSize,
                                        fontWeight: index == safeIndex
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                      child: Text(
                                        items[index].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnimatedPillSegment<T> extends StatelessWidget {
  const AnimatedPillSegment({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.height = 34,
    this.gap = 10,
    this.fontSize = 11.5,
    super.key,
  });

  final List<GlassSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final double gap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) SizedBox(width: gap),
          Expanded(
            child: Semantics(
              button: true,
              selected: items[index].value == selected,
              child: GestureDetector(
                key: items[index].key,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (items[index].value == selected) return;
                  AppHaptics.selection();
                  onChanged(items[index].value);
                },
                child: MotionPressEffect(
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : MotionTokens.contentSwitch,
                        curve: MotionTokens.standardEnter,
                        height: height,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: items[index].value == selected
                              ? (AppColors.isDark
                                    ? const Color(0x706771C2)
                                    : const Color(0xFAFFFFFF))
                              : (AppColors.isDark
                                    ? const Color(0x24FFFFFF)
                                    : const Color(0x94FFFFFF)),
                          borderRadius: BorderRadius.circular(height / 2),
                          border: Border.all(
                            color: items[index].value == selected
                                ? (AppColors.isDark
                                      ? const Color(0x57AAB2FF)
                                      : const Color(0x2E5E79FF))
                                : (AppColors.isDark
                                      ? const Color(0x29FFFFFF)
                                      : const Color(0xBDFFFFFF)),
                          ),
                          boxShadow: AppColors.isDark
                              ? [
                                  BoxShadow(
                                    color: const Color(0x24000000),
                                    blurRadius: items[index].value == selected
                                        ? 18
                                        : 14,
                                    offset: const Offset(0, 7),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0x2963729F),
                                    blurRadius: items[index].value == selected
                                        ? 24
                                        : 20,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 9),
                                  ),
                                  BoxShadow(
                                    color: items[index].value == selected
                                        ? const Color(0x245C73FF)
                                        : const Color(0x1463729F),
                                    blurRadius: 12,
                                    spreadRadius: -3,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Text(
                          items[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: items[index].value == selected
                                ? (AppColors.isDark
                                      ? const Color(0xFFEDF2FF)
                                      : const Color(0xFF3554FF))
                                : AppColors.textMuted,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class PinnedGlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  PinnedGlassHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant PinnedGlassHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
