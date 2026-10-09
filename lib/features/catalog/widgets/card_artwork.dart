import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class CardArtwork extends StatelessWidget {
  const CardArtwork({
    required this.card,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.showGeneratedLabels = true,
    this.memCacheWidth,
    this.fallbackMemCacheWidth,
    super.key,
  });

  final CardSummary card;
  final BoxFit fit;
  final Alignment alignment;
  final bool showGeneratedLabels;
  final int? memCacheWidth;

  /// Reuse the already decoded list image while the detail resolution loads.
  final int? fallbackMemCacheWidth;

  @override
  Widget build(BuildContext context) {
    final imageUrl = card.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final width =
              memCacheWidth ??
              (constraints.maxWidth.isFinite
                  ? (constraints.maxWidth * pixelRatio).round().clamp(1, 1280)
                  : null);
          Widget fallback() {
            final fallbackWidth = fallbackMemCacheWidth;
            if (fallbackWidth != null && fallbackWidth != width) {
              return CardArtwork(
                card: card,
                fit: fit,
                alignment: alignment,
                showGeneratedLabels: showGeneratedLabels,
                memCacheWidth: fallbackWidth,
              );
            }
            return _GeneratedArtwork(
              card: card,
              showLabels: showGeneratedLabels,
            );
          }

          return CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            alignment: alignment,
            memCacheWidth: width,
            maxWidthDiskCache: 1280,
            filterQuality: FilterQuality.medium,
            fadeInDuration:
                fallbackMemCacheWidth != null ||
                    MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            fadeOutDuration: fallbackMemCacheWidth != null
                ? Duration.zero
                : const Duration(milliseconds: 90),
            placeholder: (_, _) => fallback(),
            errorWidget: (_, _, _) => fallback(),
          );
        },
      );
    }
    final assetPath = card.assetPath;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) =>
            _GeneratedArtwork(card: card, showLabels: showGeneratedLabels),
      );
    }
    return _GeneratedArtwork(card: card, showLabels: showGeneratedLabels);
  }
}

class _GeneratedArtwork extends StatelessWidget {
  const _GeneratedArtwork({required this.card, required this.showLabels});

  final CardSummary card;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final tint = Color(card.tint);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.92), AppColors.ink],
        ),
      ),
      child: showLabels
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  Text(
                    card.issuer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
