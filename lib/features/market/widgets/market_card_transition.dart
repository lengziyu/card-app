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
    this.hideArtworkOnForward = false,
    super.key,
  });

  final CardSummary card;
  final Animation<double> animation;
  final Rect sourceRect;
  final Rect targetRect;
  final Rect sourceTitleRect;
  final Rect targetTitleRect;
  final bool animateTitle;
  final bool hideArtworkOnForward;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    // The flight changes logical size on every animation frame. Pinning the
    // decoded image width to the final card size prevents CachedNetworkImage
    // from cycling through a new resize key (and its placeholder) per frame.
    final targetImageCacheWidth =
        (targetRect.width * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 1280);
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
                const Interval(
                  .86,
                  1,
                  curve: Curves.easeOut,
                ).transform(animation.value);
            final radius = card.isGlobalAccount ? 14.0 : 10 + (10 * value);
            // 首页进入详情时由详情页的粒子重建接管开场，不能让一张完整
            // 卡面先飞到终点。返回时仍恢复共享卡片飞行，保持关闭连贯。
            final showArtwork =
                !hideArtworkOnForward ||
                animation.status == AnimationStatus.reverse;
            return Stack(
              children: [
                if (showArtwork)
                  Positioned.fromRect(
                    key: const Key('market-card-flight-position'),
                    rect: rect,
                    child: Opacity(
                      key: const Key('market-card-flight-opacity'),
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
                                    memCacheWidth: targetImageCacheWidth,
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
