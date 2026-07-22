import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/app_bottom_sheet.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/pro/data/pro_workspace_controller.dart';
import 'package:card_app/features/pro/widgets/pro_crown_badge.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class ProWorkspacePage extends StatelessWidget {
  const ProWorkspacePage({
    required this.controller,
    required this.cards,
    required this.collectionCards,
    required this.loadDetail,
    required this.onBack,
    required this.onOpenCard,
    required this.onOpenComparison,
    required this.onOpenBillAnalysis,
    super.key,
  });

  final ProWorkspaceController controller;
  final List<CardSummary> cards;
  final List<CardSummary> collectionCards;
  final Future<CardDetail> Function(CardSummary card) loadDetail;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<List<CardSummary>> onOpenComparison;
  final VoidCallback onOpenBillAnalysis;

  List<CardSummary> _cardsForIds(Iterable<String> ids) {
    final byId = {for (final card in cards) card.id: card};
    return ids.map((id) => byId[id]).whereType<CardSummary>().toList();
  }

  Future<void> _manageWatchlist(BuildContext context) async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .86,
      minSize: .48,
      maxSize: .94,
      barrierAlpha: .42,
      builder: (context, scrollController) => _WatchlistSheet(
        cards: cards,
        controller: controller,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _refreshOffline(BuildContext context) async {
    AppHaptics.selection();
    await controller.refreshOfflinePack(cards: cards, loadDetail: loadDetail);
    if (!context.mounted) return;
    final imageProviders = cards
        .where((card) => card.imageUrl?.isNotEmpty == true)
        .take(40)
        .map((card) => CachedNetworkImageProvider(card.imageUrl!));
    unawaited(
      Future.wait(
        imageProviders.map(
          (provider) => precacheImage(provider, context).catchError((_) {}),
        ),
      ),
    );
    final message = controller.message;
    if (message != null) AppNotice.info(context, message, title: '离线资料');
  }

  Future<void> _sync(BuildContext context) async {
    AppHaptics.selection();
    final success = await controller.sync();
    if (!context.mounted) return;
    final message = controller.message ?? '同步状态已更新。';
    if (success) {
      AppNotice.success(context, message, title: '同步完成');
    } else {
      AppNotice.info(context, message, title: '云同步');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final watchedCards = _cardsForIds(controller.watchedCardIds);
        return Stack(
          key: const Key('pro-workspace-page'),
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                topInset + 88,
                20,
                bottomInset + 38,
              ),
              children: [
                const _WorkspaceIntro(),
                const SizedBox(height: 14),
                _WorkspaceStats(
                  watched: controller.watchedCardIds.length,
                  presets: controller.comparisonPresets.length,
                  offline: controller.offlineCardCount,
                ),
                const SizedBox(height: 14),
                _CollectionReport(cards: collectionCards),
                const SizedBox(height: 14),
                _WorkspaceSection(
                  title: '消费账单分析',
                  subtitle: '从截图提取金额、币种、手续费和费率，并计算可验证的内部损耗',
                  child: _WorkspaceAction(
                    key: const Key('pro-open-bill-analysis'),
                    icon: Icons.document_scanner_outlined,
                    title: '上传消费截图',
                    description: '原图不写入账单记录；识别后先由你确认，再用于后续多账单对比。',
                    onTap: onOpenBillAnalysis,
                  ),
                ),
                const SizedBox(height: 14),
                _WorkspaceSection(
                  title: '规则变更关注',
                  subtitle: '保存关注项；正式账号与推送服务接入后同步提醒',
                  trailing: TextButton(
                    key: const Key('pro-manage-watchlist'),
                    onPressed: () => _manageWatchlist(context),
                    child: const Text('管理'),
                  ),
                  child: watchedCards.isEmpty
                      ? const _WorkspaceEmpty(
                          icon: Icons.notifications_none_rounded,
                          text: '还没有关注卡片',
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < watchedCards.length;
                              index++
                            ) ...[
                              _CompactCardRow(
                                card: watchedCards[index],
                                onTap: () => onOpenCard(watchedCards[index]),
                                onRemove: () => controller.toggleWatched(
                                  watchedCards[index],
                                ),
                              ),
                              if (index != watchedCards.length - 1)
                                Divider(height: 1, color: AppColors.line),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _WorkspaceSection(
                  title: '保存的对比方案',
                  subtitle: '快速恢复常用的多卡对比组合',
                  child: controller.comparisonPresets.isEmpty
                      ? const _WorkspaceEmpty(
                          icon: Icons.compare_arrows_rounded,
                          text: '在对比页保存方案后会显示在这里',
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < controller.comparisonPresets.length;
                              index++
                            ) ...[
                              _PresetRow(
                                preset: controller.comparisonPresets[index],
                                onOpen: () {
                                  final selected = _cardsForIds(
                                    controller.comparisonPresets[index].cardIds,
                                  );
                                  if (selected.length >= 2) {
                                    onOpenComparison(selected);
                                  }
                                },
                                onDelete: () => controller.removeComparison(
                                  controller.comparisonPresets[index].id,
                                ),
                              ),
                              if (index !=
                                  controller.comparisonPresets.length - 1)
                                Divider(height: 1, color: AppColors.line),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _WorkspaceSection(
                  title: '离线资料包',
                  subtitle: controller.offlineUpdatedAt == null
                      ? '尚未下载公开卡片资料'
                      : '上次更新 ${_dateLabel(controller.offlineUpdatedAt!)} · ${controller.offlineCardCount} 张',
                  child: _WorkspaceAction(
                    key: const Key('pro-refresh-offline'),
                    icon: Icons.offline_pin_outlined,
                    title: controller.offlineRefreshing ? '正在更新…' : '更新离线资料',
                    description: '缓存卡片字段与常用卡面；网络不可用时优先读取最近资料。',
                    onTap: controller.offlineRefreshing
                        ? null
                        : () => _refreshOffline(context),
                    loading: controller.offlineRefreshing,
                  ),
                ),
                const SizedBox(height: 14),
                _WorkspaceSection(
                  title: '云同步与备份',
                  subtitle: '接口已预留，只有安全账号和有效 Pro 权益才能访问',
                  child: _WorkspaceAction(
                    key: const Key('pro-sync-workspace'),
                    icon: Icons.cloud_sync_outlined,
                    title: controller.syncing ? '正在同步…' : '同步 Pro 工作区',
                    description: '同步关注项和对比方案；离线资料仍只保存在本机。',
                    onTap: controller.syncing ? null : () => _sync(context),
                    loading: controller.syncing,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: StickyPageHeader(
                height: 76,
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('pro-workspace-back'),
                      onPressed: onBack,
                      tooltip: '返回',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pro 工作区',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const ProCrownBadge(showLabel: true),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WorkspaceIntro extends StatelessWidget {
  const _WorkspaceIntro();

  @override
  Widget build(BuildContext context) {
    return Text(
      '集中管理高级对比、变更关注、离线资料和云备份。这里的评分只衡量卡包结构与资料完整度，不代表收益或申请成功率。',
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        height: 1.55,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _WorkspaceStats extends StatelessWidget {
  const _WorkspaceStats({
    required this.watched,
    required this.presets,
    required this.offline,
  });

  final int watched;
  final int presets;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in [
          ('关注', watched),
          ('方案', presets),
          ('离线', offline),
        ]) ...[
          if (item.$1 != '关注') const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Text(
                    '${item.$2}',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CollectionReport extends StatelessWidget {
  const _CollectionReport({required this.cards});

  final List<CardSummary> cards;

  @override
  Widget build(BuildContext context) {
    final categories = cards.map((card) => card.category).toSet().length;
    final networks = cards.map((card) => card.network).toSet().length;
    final issuers = cards.map((card) => card.issuer).toSet().length;
    final documents = cards.expand((card) => card.kycDocuments).toSet().length;
    final components = <(String, int, int)>[
      ('卡片数量', cards.length.clamp(0, 10) * 2, 20),
      ('类型覆盖', (categories / 4 * 25).round(), 25),
      ('卡组织覆盖', (networks / 3 * 20).round(), 20),
      ('发行方多样性', (issuers.clamp(0, 5) / 5 * 20).round(), 20),
      ('申请材料覆盖', (documents / 2 * 15).round(), 15),
    ];
    final score = components.fold<int>(0, (sum, item) => sum + item.$2);
    return _WorkspaceSection(
      title: '卡包结构报告',
      subtitle: cards.isEmpty ? '添加卡片后生成透明分项评分' : '基于 ${cards.length} 张本机卡片',
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      color: const Color(0xFFF4A51C),
                      backgroundColor: AppColors.line,
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  cards.isEmpty
                      ? '当前没有可分析的本机卡片。'
                      : '评分反映类型、卡组织、发行方和申请材料覆盖，不评价金融质量。',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in components)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${item.$2}/${item.$3}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 11, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.line),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _WorkspaceAction extends StatelessWidget {
  const _WorkspaceAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      enabled: onTap != null,
      child: Material(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(icon, color: AppColors.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onTap == null
                              ? AppColors.textMuted
                              : AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEmpty extends StatelessWidget {
  const _WorkspaceEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 27),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _CompactCardRow extends StatelessWidget {
  const _CompactCardRow({
    required this.card,
    required this.onTap,
    required this.onRemove,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: Key('pro-watched-${card.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: onTap,
          leading: Icon(
            Icons.notifications_active_outlined,
            color: AppColors.cyan,
          ),
          title: Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            card.issuer,
            style: TextStyle(color: AppColors.textMuted),
          ),
          trailing: IconButton(
            onPressed: onRemove,
            tooltip: '取消关注',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.onOpen,
    required this.onDelete,
  });

  final ProComparisonPreset preset;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: Key('pro-preset-${preset.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: onOpen,
          leading: Icon(Icons.compare_arrows_rounded, color: AppColors.cyan),
          title: Text(
            preset.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${preset.cardIds.length} 张 · ${_dateLabel(preset.updatedAt)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
          trailing: IconButton(
            onPressed: onDelete,
            tooltip: '删除方案',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
    );
  }
}

class _WatchlistSheet extends StatefulWidget {
  const _WatchlistSheet({
    required this.cards,
    required this.controller,
    required this.scrollController,
  });

  final List<CardSummary> cards;
  final ProWorkspaceController controller;
  final ScrollController scrollController;

  @override
  State<_WatchlistSheet> createState() => _WatchlistSheetState();
}

class _WatchlistSheetState extends State<_WatchlistSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.cards
        .where((card) => card.matches(_query))
        .toList(growable: false);
    return Container(
      key: const Key('pro-watchlist-sheet'),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xF51C2030)
            : const Color(0xFAF8FAFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '管理规则变更关注',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '完成',
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('pro-watchlist-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '搜索卡片或发行方',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.glassStrong,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = filtered[index];
                final watched = widget.controller.isWatched(card.id);
                return CatalogCardRow(
                  card: card,
                  added: watched,
                  onTap: () async {
                    await widget.controller.toggleWatched(card);
                    if (mounted) setState(() {});
                  },
                  onToggleAdded: (_) async {
                    await widget.controller.toggleWatched(card);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
