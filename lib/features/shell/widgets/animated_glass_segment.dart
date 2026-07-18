import 'dart:ui';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 520);
    const spring = Cubic(0.22, 1.16, 0.30, 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                (constraints.maxWidth - padding * 2) / items.length;
            return Container(
              height: height,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: showOuterSurface
                    ? (AppColors.isDark
                          ? const Color(0xA6232737)
                          : const Color(0x57FFFFFF))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(radius),
                border: showOuterSurface
                    ? Border.all(color: AppColors.line)
                    : null,
                boxShadow: showOuterSurface
                    ? [
                        BoxShadow(
                          color: AppColors.isDark
                              ? const Color(0x33000000)
                              : const Color(0x17646FA8),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: spring,
                    left: safeIndex * itemWidth,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding / 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: AppColors.isDark
                                ? const [Color(0x57969EEA), Color(0x706771C2)]
                                : const [Color(0xF5FFFFFF), Color(0xC2FFFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(radius - padding),
                          border: Border.all(
                            color: AppColors.isDark
                                ? const Color(0x1FFFFFFF)
                                : const Color(0x4D5E79FF),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.isDark
                                  ? const Color(0x47503C88)
                                  : const Color(0x245360B4),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
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
                            child: InkWell(
                              key: items[index].key,
                              onTap: () {
                                if (items[index].value == selected) return;
                                HapticFeedback.selectionClick();
                                onChanged(items[index].value);
                              },
                              borderRadius: BorderRadius.circular(radius),
                              child: AnimatedScale(
                                duration: duration,
                                curve: spring,
                                scale: index == safeIndex ? 1 : 0.96,
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
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
                  HapticFeedback.selectionClick();
                  onChanged(items[index].value);
                },
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: const Cubic(0.22, 1.16, 0.30, 1),
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.isDark
                            ? const Color(0x24000000)
                            : const Color(0x146F82AE),
                        blurRadius: items[index].value == selected ? 18 : 14,
                        offset: const Offset(0, 7),
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: AppColors.isDark
                          ? Colors.black.withValues(alpha: 0.04)
                          : const Color(0x0D6470A8),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PinnedGlassHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
