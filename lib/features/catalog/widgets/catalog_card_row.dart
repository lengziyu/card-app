import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

class CatalogCardRow extends StatelessWidget {
  const CatalogCardRow({
    required this.card,
    required this.onTap,
    this.added,
    this.onToggleAdded,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final bool? added;
  final ValueChanged<bool>? onToggleAdded;

  @override
  Widget build(BuildContext context) {
    final isAdded = added ?? false;
    return Material(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('catalog-card-${card.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 88),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 112,
                    height: 70,
                    child: CardArtwork(card: card, showGeneratedLabels: false),
                  ),
                ),
                SizedBox(width: 17),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '${card.issuer} · ${card.category.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                if (onToggleAdded != null)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filledTonal(
                      key: Key('search-toggle-${card.id}'),
                      onPressed: () => onToggleAdded!(!isAdded),
                      tooltip: isAdded ? '移除' : '添加',
                      icon: Icon(
                        isAdded ? Icons.check_rounded : Icons.add_rounded,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: isAdded
                            ? AppColors.mint
                            : AppColors.text,
                        backgroundColor: isAdded
                            ? AppColors.mint.withValues(alpha: 0.14)
                            : AppColors.violet.withValues(alpha: 0.24),
                      ),
                    ),
                  )
                else
                  _CardNetworkMark(network: card.network, fallback: card.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardNetworkMark extends StatelessWidget {
  const _CardNetworkMark({required this.network, required this.fallback});

  final CardNetwork network;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Align(
        alignment: Alignment.centerRight,
        child: switch (network) {
          CardNetwork.visa => Text(
            'VISA',
            style: TextStyle(
              color: AppColors.isDark
                  ? const Color(0xFF4F86FF)
                  : const Color(0xFF0A347E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.2,
            ),
          ),
          CardNetwork.mastercard => const _MastercardMark(),
          CardNetwork.other => Text(
            fallback.split('·').first.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        },
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 43,
      height: 28,
      child: Stack(
        children: [
          Positioned(left: 1, top: 3, child: _circle(const Color(0xFFEB001B))),
          Positioned(
            right: 1,
            top: 3,
            child: _circle(const Color(0xFFF79E1B).withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }

  Widget _circle(Color color) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
