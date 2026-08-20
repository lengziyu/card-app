import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/global_account_cover.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

/// A lightweight shared-card flight used by the market list and the existing
/// card detail overlay. The source artwork is hidden while this copy is active.
class MarketCardTransition extends StatelessWidget {
  const MarketCardTransition({
    required this.card,
    required this.animation,
    required this.sourceRect,
    required this.targetRect,
    required this.sourceTitleRect,
    required this.targetTitleRect,
    this.animateTitle = true,
    super.key,
  });

  final CardSummary card;
  final Animation<double> animation;
  final Rect sourceRect;
  final Rect targetRect;
  final Rect sourceTitleRect;
  final Rect targetTitleRect;
  final bool animateTitle;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final curve = animation.status == AnimationStatus.reverse
                ? MotionTokens.standardExit
                : MotionTokens.standardEnter;
            final value = curve.transform(animation.value);
            final rect = Rect.lerp(sourceRect, targetRect, value)!;
            final titleRect = Rect.lerp(
              sourceTitleRect,
              targetTitleRect,
              value,
            )!;
            final handoff =
                1 -
                const Interval(.86, 1, curve: Curves.easeOut).transform(value);
            final radius = card.isGlobalAccount ? 14.0 : 10 + (10 * value);
            return Stack(
              children: [
                Positioned.fromRect(
                  key: const Key('market-card-flight-position'),
                  rect: rect,
                  child: Opacity(
                    opacity: handoff,
                    child: RepaintBoundary(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: .10 + (.10 * value),
                              ),
                              blurRadius: 12 + (10 * value),
                              spreadRadius: -3,
                              offset: Offset(0, 5 + (5 * value)),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: card.isGlobalAccount
                              ? GlobalAccountCover(
                                  card: card,
                                  compact: value < .55,
                                )
                              : CardArtwork(
                                  card: card,
                                  showGeneratedLabels: false,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (animateTitle)
                  Positioned.fromRect(
                    key: const Key('market-card-flight-title-position'),
                    rect: titleRect,
                    child: Opacity(
                      opacity:
                          1 -
                          const Interval(
                            .28,
                            .54,
                            curve: Curves.easeOut,
                          ).transform(value),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15 + (10 * value),
                            fontWeight: FontWeight.lerp(
                              FontWeight.w800,
                              FontWeight.w900,
                              value,
                            ),
                            letterSpacing: -1.1 * value,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
