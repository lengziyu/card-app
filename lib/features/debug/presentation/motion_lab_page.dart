import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/celebration_effects.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/material.dart';

/// Temporary internal surface for tuning success motion before it is connected
/// to account sign-in. Keep the effects here testable without a live account
/// or store purchase.
class MotionLabPage extends StatefulWidget {
  const MotionLabPage({
    required this.onBack,
    this.cards = localCardCatalog,
    super.key,
  });

  final VoidCallback onBack;
  final List<CardSummary> cards;

  @override
  State<MotionLabPage> createState() => _MotionLabPageState();
}

class _MotionLabPageState extends State<MotionLabPage> {
  int _cardBurstTrigger = 0;
  int _giftTrigger = 0;
  late final List<CardSummary> _uCards = () {
    final cards = widget.cards
        .where((card) => card.category == CardCategory.uCard)
        .take(20)
        .toList(growable: false);
    if (cards.isEmpty) return const <CardSummary>[];
    return List.generate(20, (index) => cards[index % cards.length]);
  }();

  void _playCardBurst() {
    AppHaptics.selection();
    setState(() => _cardBurstTrigger++);
  }

  void _playGift() {
    AppHaptics.selection();
    setState(() => _giftTrigger++);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('motion-lab-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 92, 20, 30 + bottomInset),
          children: [
            Text(
              context.tr('动画实验室'),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('仅用于调试成功反馈；正式上线前会隐藏这个入口。'),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _LabActionCard(
              key: const Key('motion-lab-card-burst'),
              icon: Icons.style_rounded,
              title: context.tr('顶部爆卡'),
              subtitle: context.tr('模拟登录成功后，卡片从页面顶部爆出并落下。'),
              actionLabel: context.tr('播放爆卡效果'),
              onPressed: _playCardBurst,
            ),
            const SizedBox(height: 14),
            _LabActionCard(
              key: const Key('motion-lab-pro-gift'),
              icon: Icons.card_giftcard_rounded,
              title: context.tr('Pro 开通礼包'),
              subtitle: context.tr('礼包从底部升起，绽放后自然落下。'),
              actionLabel: context.tr('播放礼包效果'),
              onPressed: _playGift,
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            child: Row(
              children: [
                IconButton(
                  key: const Key('motion-lab-back'),
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: '返回',
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('动效调试'),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CardBurstCelebration(
            trigger: _cardBurstTrigger,
            cards: _uCards,
          ),
        ),
        Positioned.fill(
          child: ProGiftCelebration(trigger: _giftTrigger, showCopy: false),
        ),
      ],
    );
  }
}

class _LabActionCard extends StatelessWidget {
  const _LabActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.cyan),
        ),
        const SizedBox(height: 15),
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
}
