import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/home/presentation/mock_card.dart';
import 'package:card_app/features/home/widgets/card_stack.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.cards, required this.onAddCard, super.key});

  final List<MockCard> cards;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 136 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _HomeHeader(cardCount: cards.length, onAddCard: onAddCard),
              const SizedBox(height: 34),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: cards.isNotEmpty
                    ? CardStack(key: const ValueKey('card-stack'), cards: cards)
                    : _EmptyState(
                        key: const ValueKey('empty-state'),
                        onAddCard: onAddCard,
                      ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.cardCount, required this.onAddCard});

  final int cardCount;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的卡片',
                key: const Key('home-title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                label: cardCount > 0
                    ? '当前未登录，首页展示 $cardCount 张演示卡片'
                    : '当前未登录，首页暂无演示卡片',
                excludeSemantics: true,
                child: Text(
                  '当前未登录，首页卡片仅为演示',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          button: true,
          label: '添加卡片',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('home-add-button'),
              onTap: onAddCard,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceRaised.withValues(alpha: 0.82),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.text,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddCard, super.key});

  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.violet, AppColors.cyan],
              ),
            ),
            child: const Icon(
              Icons.style_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 22),
          Text('还没有收藏的卡片', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '从市场中添加卡片，建立你的个人收藏。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddCard,
            icon: const Icon(Icons.add_rounded),
            label: const Text('浏览演示卡片'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }
}
