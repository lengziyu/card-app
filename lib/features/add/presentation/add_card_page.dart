import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

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
                child: _CardRow(
                  card: card,
                  added: addedCardIds.contains(card.id),
                  onChanged: (added) => onCardChanged(card, added),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : MotionTokens.stateChange,
      curve: MotionTokens.standardEnter,
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: added
            ? AppColors.mint.withValues(alpha: AppColors.isDark ? .08 : .055)
            : AppColors.glass,
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
              width: 38,
              height: 38,
              child: MotionPressEffect(
                child: IconButton.filledTonal(
                  key: Key('toggle-${card.id}'),
                  onPressed: () {
                    AppHaptics.selection();
                    onChanged(!added);
                  },
                  tooltip: added ? '移除' : '添加',
                  icon: MotionStateIcon(
                    stateKey: added,
                    child: Icon(
                      added ? Icons.check_rounded : Icons.add_rounded,
                      size: 18,
                    ),
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
          ),
        ],
      ),
    );
  }
}
