import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CardArtwork extends StatelessWidget {
  const CardArtwork({
    required this.card,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.showGeneratedLabels = true,
    super.key,
  });

  final CardSummary card;
  final BoxFit fit;
  final Alignment alignment;
  final bool showGeneratedLabels;

  @override
  Widget build(BuildContext context) {
    final imageUrl = card.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final width = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * pixelRatio).round().clamp(1, 1280)
              : null;
          return CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            alignment: alignment,
            memCacheWidth: width,
            maxWidthDiskCache: 1280,
            filterQuality: FilterQuality.medium,
            fadeInDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            fadeOutDuration: const Duration(milliseconds: 90),
            placeholder: (_, _) =>
                _GeneratedArtwork(card: card, showLabels: showGeneratedLabels),
            errorWidget: (_, _, _) =>
                _GeneratedArtwork(card: card, showLabels: showGeneratedLabels),
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
