import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/home/presentation/mock_card.dart';
import 'package:flutter/material.dart';

class AddCardPage extends StatelessWidget {
  const AddCardPage({
    required this.addedCardIds,
    required this.onCardChanged,
    super.key,
  });

  final Set<String> addedCardIds;
  final void Function(MockCard card, bool added) onCardChanged;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      key: const Key('add-card-page'),
      physics: const BouncingScrollPhysics(),
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
                          key: const Key('add-card-title'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '从卡片目录添加到你的收藏',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const _RoundActionButton(),
                ],
              ),
              const SizedBox(height: 24),
              const _DemoNotice(),
              const SizedBox(height: 18),
              for (final card in mockCards) ...[
                _CardRow(
                  card: card,
                  added: addedCardIds.contains(card.id),
                  onChanged: (added) => onCardChanged(card, added),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '搜索卡片，演示版暂不可用',
      button: true,
      enabled: false,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.82),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '当前使用本地演示数据，不会连接账号或提交申请。',
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

  final MockCard card;
  final bool added;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              card.assetPath,
              width: 86,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.surfaceRaised,
                child: SizedBox(
                  width: 86,
                  height: 54,
                  child: Icon(
                    Icons.credit_card_rounded,
                    color: Color(card.tint),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
