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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('catalog-card-${card.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 88),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 92,
                    height: 58,
                    child: CardArtwork(card: card, showGeneratedLabels: false),
                  ),
                ),
                SizedBox(width: 14),
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
                      SizedBox(height: 3),
                      Text(
                        card.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(card.tint).withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
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
                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
