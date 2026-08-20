import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/core/localization/localized_text.dart';
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
                  if (compact && card.isCryptoRelated) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: Key('global-account-crypto-${card.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB15C).withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFFFB15C).withValues(alpha: .32),
                        ),
                      ),
                      child: const Text(
                        '加密相关',
                        style: TextStyle(
                          color: Color(0xFFE58524),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
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
                card.label.isEmpty ? '多币种账户服务' : card.label,
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
        Positioned(
          top: compact ? 14 : 20,
          right: compact ? 14 : 20,
          child: _ProviderLogo(card: card, compact: compact),
        ),
        Positioned(
          right: compact ? 14 : 20,
          bottom: compact ? 14 : 20,
          child: Semantics(
            label: '${card.issuer}银行账户',
            child: Icon(
              Icons.account_balance_rounded,
              key: Key('global-account-bank-mark-${card.id}'),
              size: compact ? 38 : 50,
              color: Colors.white.withValues(alpha: compact ? .46 : .52),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.card, required this.compact});

  final CardSummary card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // A provider logo is an editorial asset from the account directory, not a
    // tiny decorative badge. Give uploaded marks enough room to stay legible.
    final size = compact ? 56.0 : 76.0;
    final logoUrl = card.logoImageUrl?.trim();
    final issuer = card.issuer.trim();
    final initials = issuer.isEmpty
        ? '账户'
        : String.fromCharCodes(issuer.runes.take(2)).toUpperCase();
    final fallback = Container(
      padding: EdgeInsets.all(compact ? 7 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(compact ? 10 : 13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: _LogoInitials(
        initials: initials,
        tint: Color(card.tint),
        compact: compact,
      ),
    );
    return Semantics(
      image: true,
      label: '${card.issuer}标志',
      child: SizedBox(
        key: Key('global-account-logo-${card.id}'),
        width: size,
        height: size,
        child: logoUrl == null || logoUrl.isEmpty
            ? fallback
            : ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 12 : 16),
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  // Uploaded logo artwork owns this whole slot. Avoid adding a
                  // white badge or inner padding around the provided image.
                  fit: BoxFit.cover,
                  memCacheWidth: compact ? 80 : 112,
                  maxWidthDiskCache: 224,
                  fadeInDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
      ),
    );
  }
}

class _LogoInitials extends StatelessWidget {
  const _LogoInitials({
    required this.initials,
    required this.tint,
    required this.compact,
  });

  final String initials;
  final Color tint;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        color: tint,
        fontSize: compact ? 12 : 15,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
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
  );
}
