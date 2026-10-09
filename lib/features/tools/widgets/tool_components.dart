import 'dart:math' as math;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/motion/pressable_scale.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:cardfi/features/shell/widgets/animated_glass_segment.dart';
import 'package:flutter/material.dart' hide Text;

/// Uses the catalog's glass, fine border and restrained card shadow.
class ToolSurface extends StatelessWidget {
  const ToolSurface({
    required this.child,
    this.radius = 14,
    this.color,
    super.key,
  });
  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0xFF63729F,
          ).withValues(alpha: AppColors.isDark ? .04 : .09),
          blurRadius: 18,
          spreadRadius: -4,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Material(
      color: color ?? AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

class ToolModeSegment extends StatelessWidget {
  const ToolModeSegment({
    required this.items,
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(
          text: context.tr(item.$2),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width + 38);
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: SizedBox(
          width: math.max(constraints.maxWidth, widest * items.length + 8),
          child: AnimatedGlassSegment<String>(
            height: math.max(48, scaler.scale(13) * 1.4 + 18),
            items: [
              for (final item in items)
                GlassSegmentItem(
                  value: item.$1,
                  label: item.$2,
                  key: Key('tools-mode-${item.$1}'),
                ),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class ToolFilterStrip extends StatelessWidget {
  const ToolFilterStrip({
    required this.items,
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    var itemWidth = 60.0;
    final scaler = MediaQuery.textScalerOf(context);
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(
          text: context.tr(item.$2),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      itemWidth = math.max(itemWidth, painter.width + 24);
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: SizedBox(
          width: math.max(
            constraints.maxWidth,
            itemWidth * items.length + 8 * (items.length - 1),
          ),
          child: AnimatedPillSegment<String>(
            height: math.min(44, math.max(32, scaler.scale(11.5) * 1.4 + 10)),
            gap: 8,
            fontSize: 11.5,
            items: [
              for (final item in items)
                GlassSegmentItem(
                  value: item.$1,
                  label: item.$2,
                  key: Key('tools-filter-${item.$1}'),
                ),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class ToolResultRow extends StatelessWidget {
  const ToolResultRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.leading,
    this.facts = const [],
    super.key,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget Function(double width) leading;
  final List<String> facts;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    builder: (context, pressed) => ToolSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            final artWidth = largeText
                ? 64.0
                : constraints.maxWidth < 295
                ? 88.0
                : 104.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading(artWidth),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
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
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            for (final fact in facts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  fact,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.textMuted,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ToolCardArt extends StatelessWidget {
  const ToolCardArt({required this.card, required this.width, super.key});
  final CardSummary card;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width / 1.6,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .07),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: CardArtwork(card: card, showGeneratedLabels: false),
    ),
  );
}

class ToolFact extends StatelessWidget {
  const ToolFact({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final labelStyle = TextStyle(
      fontSize: 12,
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = TextStyle(
      fontSize: label == 'BIN' ? 20 : 13,
      height: 1.45,
      color: label == 'BIN' ? AppColors.cyan : AppColors.text,
      fontFamily: label == 'BIN' ? 'monospace' : null,
      fontWeight: label == 'BIN' ? FontWeight.w800 : FontWeight.w600,
    );
    final long =
        value.length > 35 ||
        value.contains('\n') ||
        MediaQuery.textScalerOf(context).scale(13) > 19;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: long
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 5),
                Text(value, style: valueStyle),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 100, child: Text(label, style: labelStyle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: valueStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
    );
  }
}

class ToolNotice extends StatelessWidget {
  const ToolNotice(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: .055),
        border: Border.all(color: AppColors.cyan.withValues(alpha: .09)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Compact two-column facts in the same order as the H5 BIN result.
class ToolFactGrid extends StatelessWidget {
  const ToolFactGrid({required this.facts, super.key});
  final List<(String, String)> facts;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(13) > 19
          ? 1
          : 2;
      return Wrap(
        spacing: 16,
        runSpacing: 15,
        children: [
          for (final fact in facts)
            SizedBox(
              width: (constraints.maxWidth - 16 * (columns - 1)) / columns,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fact.$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fact.$2.isEmpty ? '—' : cleanToolText(fact.$2),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
