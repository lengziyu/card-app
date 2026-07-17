import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/home/widgets/card_stack.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.cards,
    required this.cardHeightScale,
    required this.onAddCard,
    required this.onOpenCard,
    required this.onCardHeightScaleChanged,
    required this.onReorderCards,
    required this.onToggleNavigation,
    super.key,
  });

  final List<CardSummary> cards;
  final double cardHeightScale;
  final VoidCallback onAddCard;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<double> onCardHeightScaleChanged;
  final ValueChanged<List<String>> onReorderCards;
  final VoidCallback onToggleNavigation;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _cardInteractionActive = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return CustomScrollView(
      controller: _scrollController,
      physics: _cardInteractionActive
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 122 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _HomeHeader(
                cardCount: widget.cards.length,
                onAddCard: widget.onAddCard,
                onToggleNavigation: widget.onToggleNavigation,
              ),
              SizedBox(height: 21),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: widget.cards.isNotEmpty
                    ? CardStack(
                        key: ValueKey('card-stack'),
                        cards: widget.cards,
                        heightScale: widget.cardHeightScale,
                        scrollController: _scrollController,
                        onOpenCard: widget.onOpenCard,
                        onHeightScaleChanged: widget.onCardHeightScaleChanged,
                        onReorder: widget.onReorderCards,
                        onInteractionChanged: (active) {
                          if (_cardInteractionActive == active) return;
                          setState(() => _cardInteractionActive = active);
                        },
                      )
                    : _EmptyState(key: ValueKey('empty-state')),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.cardCount,
    required this.onAddCard,
    required this.onToggleNavigation,
  });

  final int cardCount;
  final VoidCallback onAddCard;
  final VoidCallback onToggleNavigation;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '切换底部导航显示',
            child: GestureDetector(
              key: const Key('home-title-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggleNavigation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的卡片',
                    key: Key('home-title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 10),
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
          ),
        ),
        SizedBox(width: 16),
        Semantics(
          button: true,
          label: '添加卡片',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('home-add-button'),
              onTap: onAddCard,
              customBorder: CircleBorder(),
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassStrong,
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.isDark
                          ? Color(0x3D000000)
                          : Color(0x385F6A96),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(Icons.add_rounded, color: AppColors.text, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark ? Color(0x47000000) : Color(0x1A626EAE),
            blurRadius: AppColors.isDark ? 28 : 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '还没有卡片',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '去市场或添加页选择第一张卡片',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
