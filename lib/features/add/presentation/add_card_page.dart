import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

class AddCardPage extends StatelessWidget {
  const AddCardPage({
    required this.addedCardIds,
    required this.cards,
    required this.onCardChanged,
    required this.onSearch,
    super.key,
  });

  final Set<String> addedCardIds;
  final List<CardSummary> cards;
  final void Function(CardSummary card, bool added) onCardChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      key: Key('add-card-page'),
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 132 + bottomInset),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '添加卡片',
                          key: Key('add-card-title'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '从卡片目录添加到你的收藏',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  _RoundActionButton(onPressed: onSearch),
                ],
              ),
              SizedBox(height: 24),
              const _CatalogNotice(),
              SizedBox(height: 18),
              for (final card in cards) ...[
                _CardRow(
                  card: card,
                  added: addedCardIds.contains(card.id),
                  onChanged: (added) => onCardChanged(card, added),
                ),
                SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('add-search-button'),
        onTap: onPressed,
        customBorder: CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.glassStrong,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '卡片目录来自线上公开数据；游客调整仅保存在当前会话。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.added,
    required this.onChanged,
  });

  final CardSummary card;
  final bool added;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 86,
              height: 54,
              child: CardArtwork(card: card, showGeneratedLabels: false),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Semantics(
            button: true,
            toggled: added,
            label: added ? '从我的卡片移除 ${card.name}' : '添加 ${card.name}',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filledTonal(
                key: Key('toggle-${card.id}'),
                onPressed: () => onChanged(!added),
                tooltip: added ? '移除' : '添加',
                icon: Icon(
                  added ? Icons.check_rounded : Icons.add_rounded,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: added ? AppColors.mint : AppColors.text,
                  backgroundColor: added
                      ? AppColors.mint.withValues(alpha: 0.14)
                      : AppColors.violet.withValues(alpha: 0.24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
