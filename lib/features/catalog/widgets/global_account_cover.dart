import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

/// Shared 16:9 artwork for global-account list, transition and detail states.
class GlobalAccountCover extends StatelessWidget {
  const GlobalAccountCover({
    required this.card,
    this.compact = false,
    super.key,
  });

  final CardSummary card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tint = Color(card.tint);
    final cover = card.coverImageUrl?.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null && cover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.cover,
            memCacheWidth: 1200,
            maxWidthDiskCache: 1400,
            maxHeightDiskCache: 800,
            fadeInDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            placeholder: (_, _) => AppShimmer(child: _Fallback(tint: tint)),
            errorWidget: (_, _, _) => _Fallback(tint: tint),
          )
        else
          _Fallback(tint: tint),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .02),
                Colors.black.withValues(alpha: .62),
              ],
              stops: const [.28, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(compact ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 5 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: compact ? 13 : 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '全球账户',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                card.issuer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? -.5 : -1,
                ),
              ),
              SizedBox(height: compact ? 3 : 6),
              Text(
                '多币种持有 · 收款 · 换汇',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: AppColors.isDark ? .78 : .92),
          AppColors.isDark ? const Color(0xFF172132) : const Color(0xFF33435A),
        ],
      ),
    ),
    child: Align(
      alignment: const Alignment(.72, -.38),
      child: Icon(
        Icons.account_balance_rounded,
        size: 88,
        color: Colors.white.withValues(alpha: .10),
      ),
    ),
  );
}
