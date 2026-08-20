import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class AddCardPage extends StatelessWidget {
  const AddCardPage({
    required this.addedCardIds,
    required this.cards,
    required this.onCardChanged,
    required this.onOpenCard,
    required this.onSearch,
    super.key,
  });

  final Set<String> addedCardIds;
  final List<CardSummary> cards;
  final void Function(CardSummary card, bool added) onCardChanged;
  final ValueChanged<CardSummary> onOpenCard;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final addableCards = cards
        .where((card) => card.isAddableToCardWallet)
        .toList(growable: false);
    return CustomScrollView(
      key: Key('add-card-page'),
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
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
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 132 + bottomInset),
          sliver: SliverList.builder(
            itemCount: addableCards.length,
            itemBuilder: (context, index) {
              final card = addableCards[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CatalogCardRow(
                  card: card,
                  added: addedCardIds.contains(card.id),
                  onTap: () => onOpenCard(card),
                  toggleKey: Key('toggle-${card.id}'),
                  onToggleAdded: (added) {
                    AppHaptics.selection();
                    onCardChanged(card, added);
                  },
                ),
              );
            },
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
    return MotionPressEffect(
      child: Material(
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
      ),
    );
  }
}
