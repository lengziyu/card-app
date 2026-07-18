import 'dart:math' as math;

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/domain/ranking_data.dart';
import 'package:card_app/features/shell/widgets/animated_glass_segment.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum RankingTab { ranking, charts, metrics, articles }

final _testStablecoinDashboard = StablecoinDashboard(
  sourceLabel: '演示数据',
  updatedAt: null,
  totalMarketCap: '\$314.00B',
  totalVolume: '—',
  trackedAssets: 0,
  history: const [286, 291, 298, 304, 314],
  assets: const [
    StablecoinAsset(
      id: '1',
      symbol: 'USDT',
      name: 'Tether',
      marketCap: '\$184B',
      dominance: 64,
      color: 0xFF8B91FF,
    ),
  ],
  chains: const [
    StablecoinChain(name: 'Ethereum', value: '\$167.5B', share: 53.4),
  ],
);

final _testMetricsDashboard = CardMetricsDashboard(
  source: 'demo',
  updatedAt: null,
  methodology: '测试数据',
  items: const [
    CardMetric(
      id: 'etherfi',
      name: 'EtherFi',
      cardId: 'etherfi-core',
      logoText: 'ETH',
      sevenDay: 26590000,
      thirtyDay: 103700000,
      total: 1175000000,
      transactions: 791000,
      addresses: 95635,
    ),
  ],
);

class RankingPage extends StatefulWidget {
  const RankingPage({
    required this.cards,
    required this.onOpenCard,
    required this.onOpenArticle,
    required this.repository,
    required this.enableRemoteData,
    super.key,
  });

  final List<CardSummary> cards;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<LocalArticle> onOpenArticle;
  final RemoteRankingRepository repository;
  final bool enableRemoteData;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  RankingTab _tab = RankingTab.ranking;
  List<RankingGroup>? _groups;
  StablecoinDashboard? _stablecoins;
  CardMetricsDashboard? _metrics;
  List<ArticleFeedItem>? _articles;
  final Set<RankingTab> _failed = {};
  int _contentDirection = 1;

  @override
  void initState() {
    super.initState();
    if (!widget.enableRemoteData) {
      _failed.addAll([RankingTab.ranking, RankingTab.articles]);
      _stablecoins = _testStablecoinDashboard;
      _metrics = _testMetricsDashboard;
    } else {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _load(
        RankingTab.ranking,
        widget.repository.loadRankings,
        (value) => _groups = value,
      ),
      _load(
        RankingTab.charts,
        widget.repository.loadStablecoins,
        (value) => _stablecoins = value,
      ),
      _load(
        RankingTab.metrics,
        widget.repository.loadMetrics,
        (value) => _metrics = value,
      ),
      _load(
        RankingTab.articles,
        widget.repository.loadArticles,
        (value) => _articles = value,
      ),
    ]);
  }

  Future<void> _load<T>(
    RankingTab tab,
    Future<T> Function() request,
    void Function(T value) assign,
  ) async {
    try {
      final value = await request();
      if (!mounted) return;
      setState(() {
        assign(value);
        _failed.remove(tab);
      });
    } catch (_) {
      if (mounted) setState(() => _failed.add(tab));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return CustomScrollView(
      key: const Key('ranking-page'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedGlassHeaderDelegate(
            height: 66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: _RankingTabs(selected: _tab, onChanged: _selectTab),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20,
            _tab == RankingTab.ranking ? 22 : 10,
            20,
            132 + bottomInset,
          ),
          sliver: SliverList.list(
            children: [
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: Offset(0.055 * _contentDirection, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    RankingTab.ranking => _rankingContent(),
                    RankingTab.charts => _stablecoinContent(),
                    RankingTab.metrics => _metricsContent(),
                    RankingTab.articles => _articleContent(),
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectTab(RankingTab tab) {
    if (tab == _tab) return;
    setState(() {
      _contentDirection = tab.index > _tab.index ? 1 : -1;
      _tab = tab;
    });
  }

  Widget _rankingContent() {
    if (_failed.contains(RankingTab.ranking)) {
      return _H5EmptyState(
        key: ValueKey('ranking-unavailable'),
        title: '排行榜暂时没加载出来',
        description: '请检查网络后重新加载。',
        onRetry: _reloadRankings,
      );
    }
    if (_groups == null) return const _LoadingPanel();
    return _LiveTierList(
      groups: _groups!,
      cards: widget.cards,
      onOpenCard: widget.onOpenCard,
    );
  }

  Future<void> _reloadRankings() async {
    setState(() {
      _groups = null;
      _failed.remove(RankingTab.ranking);
    });
    await _load(
      RankingTab.ranking,
      widget.repository.loadRankings,
      (value) => _groups = value,
    );
  }

  Widget _stablecoinContent() {
    if (_failed.contains(RankingTab.charts)) {
      return const _H5EmptyState(title: '稳定币数据暂时不可用', description: '稍后刷新看看。');
    }
    if (_stablecoins == null) return const _LoadingPanel();
    return _StablecoinPanel(
      key: const ValueKey('stablecoin-data'),
      dashboard: _stablecoins!,
      repository: widget.repository,
      enableRemoteData: widget.enableRemoteData,
    );
  }

  Widget _articleContent() {
    if (_failed.contains(RankingTab.articles)) {
      return const _H5EmptyState(
        title: '文章暂时没加载出来',
        description: '稍后刷新看看，或者等后台发布新的文章。',
      );
    }
    if (_articles == null) return const _LoadingPanel();
    return _LiveArticleList(items: _articles!, onOpen: widget.onOpenArticle);
  }

  Widget _metricsContent() {
    if (_failed.contains(RankingTab.metrics)) {
      return const _H5EmptyState(title: '数据榜暂时不可用', description: '稍后刷新看看。');
    }
    if (_metrics == null) return const _LoadingPanel();
    return _MetricsTable(
      key: const ValueKey('metrics-table'),
      dashboard: _metrics!,
      cards: widget.cards,
      onOpenCard: widget.onOpenCard,
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    decoration: _panelDecoration(radius: 18),
    alignment: Alignment.center,
    child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2),
  );
}

class _LiveTierList extends StatelessWidget {
  const _LiveTierList({
    required this.groups,
    required this.cards,
    required this.onOpenCard,
  });

  final List<RankingGroup> groups;
  final List<CardSummary> cards;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final card in cards) card.id: card};
    if (groups.isEmpty) {
      return const _H5EmptyState(title: '排行榜暂无内容', description: '后台还没有发布排行。');
    }
    return Column(
      key: const Key('ranking-live'),
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          _TierRow(
            label: _tierLabel(groupIndex),
            color: _tierColor(groupIndex),
            child: Wrap(
              spacing: 7,
              runSpacing: 9,
              alignment: WrapAlignment.center,
              children: [
                for (final id in groups[groupIndex].cardIds)
                  if (byId[id] case final card?)
                    InkWell(
                      key: Key('rank-card-${card.id}'),
                      onTap: () => onOpenCard(card),
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 62,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: AspectRatio(
                                aspectRatio: 1.586,
                                child: CardArtwork(
                                  card: card,
                                  showGeneratedLabels: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _tierLabel(int index) => const ['S', 'A', 'B', 'C', 'D'][index % 5];

  List<Color> _tierColor(int index) => switch (index % 5) {
    0 => const [Color(0xFFFF1524), Color(0xFFE10614)],
    1 => const [Color(0xFFFF7B1A), Color(0xFFFF5A0A)],
    2 => const [Color(0xFFFFC928), Color(0xFFFFAE12)],
    3 => const [Color(0xFF36A5FF), Color(0xFF1D83EE)],
    _ => const [Color(0xFFB7BECE), Color(0xFF9BA4B8)],
  };
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.label,
    required this.color,
    required this.child,
  });

  final String label;
  final List<Color> color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        width: 52,
        constraints: const BoxConstraints(minHeight: 96),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: color,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F5C66A0),
              blurRadius: 23,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: _panelDecoration(radius: 12),
          child: child,
        ),
      ),
    ],
  );
}

class _LiveArticleList extends StatelessWidget {
  const _LiveArticleList({required this.items, required this.onOpen});

  final List<ArticleFeedItem> items;
  final ValueChanged<LocalArticle> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _H5EmptyState(title: '暂无文章', description: '后台还没有发布文章。');
    }
    return Column(
      key: const Key('article-live-list'),
      children: [
        for (final item in items) ...[
          Material(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key('article-${item.slug}'),
              onTap: () => onOpen(item.article),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.coverImageUrl case final cover?) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          memCacheWidth: 1000,
                          maxWidthDiskCache: 1200,
                          fadeInDuration: const Duration(milliseconds: 180),
                          placeholder: (_, _) => AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ColoredBox(
                              color: AppColors.violet.withValues(alpha: 0.08),
                            ),
                          ),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      item.article.category,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.article.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '浏览 ${item.viewCount}  ·  点赞 ${item.likeCount}  ·  ${item.article.publishedLabel}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RankingTabs extends StatelessWidget {
  const _RankingTabs({required this.selected, required this.onChanged});

  final RankingTab selected;
  final ValueChanged<RankingTab> onChanged;

  static const labels = <RankingTab, String>{
    RankingTab.ranking: '热门榜',
    RankingTab.charts: '稳定币数据',
    RankingTab.metrics: '数据榜',
    RankingTab.articles: '资讯',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassSegment<RankingTab>(
      items: [
        for (final tab in RankingTab.values)
          GlassSegmentItem(
            value: tab,
            label: labels[tab]!,
            key: Key('ranking-tab-${tab.name}'),
          ),
      ],
      selected: selected,
      onChanged: onChanged,
      fontSize: 11,
    );
  }
}

class _H5EmptyState extends StatelessWidget {
  const _H5EmptyState({
    required this.title,
    required this.description,
    this.onRetry,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: _panelDecoration(radius: 18),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ],
      ),
    );
  }
}

class _StablecoinPanel extends StatelessWidget {
  const _StablecoinPanel({
    required this.dashboard,
    required this.repository,
    required this.enableRemoteData,
    super.key,
  });

  final StablecoinDashboard dashboard;
  final RemoteRankingRepository repository;
  final bool enableRemoteData;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('stablecoin-market-overview'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 16),
          decoration: _panelDecoration(radius: 18),
          child: Column(
            children: [
              Text(
                '稳定币总市值',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dashboard.totalMarketCap,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF55C89B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '当前区间趋势  ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _percent(dashboard.intervalChange),
                    style: const TextStyle(
                      color: Color(0xFF47A87D),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 42,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MiniTrendPainter(dashboard.history),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: '区间增长',
                value: _percent(dashboard.intervalChange),
              ),
            ),
            SizedBox(width: 9),
            Expanded(
              child: _SummaryMetric(
                label: '24h 交易量',
                value: dashboard.totalVolume,
              ),
            ),
            SizedBox(width: 9),
            Expanded(
              child: _SummaryMetric(
                label: '收录资产',
                value: '${dashboard.trackedAssets}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 3),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF62D5B4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '数据来源：${dashboard.sourceLabel}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '更新时间：${_time(dashboard.updatedAt)}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TrendChart(values: dashboard.history),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SharePanel(
                entries: dashboard.assets.take(4).toList(),
                onOpen: enableRemoteData
                    ? (asset) => _showStablecoinDetail(context, asset)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NetworkPanel(networks: dashboard.chains.take(4).toList()),
            ),
          ],
        ),
      ],
    );
  }

  String _percent(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';

  String _time(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showStablecoinDetail(BuildContext context, StablecoinAsset asset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StablecoinDetailSheet(
        asset: asset,
        request: repository.loadStablecoinDetail(asset.id),
      ),
    );
  }
}

class _StablecoinDetailSheet extends StatelessWidget {
  const _StablecoinDetailSheet({required this.asset, required this.request});

  final StablecoinAsset asset;
  final Future<StablecoinDetail> request;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      key: Key('stablecoin-detail-${asset.id}'),
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xFF14182A)
            : const Color(0xFFF9FAFF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
      ),
      child: FutureBuilder<StablecoinDetail>(
        future: request,
        builder: (context, snapshot) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${asset.name} · ${asset.symbol}',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '历史供应趋势 · DefiLlama',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: switch (snapshot.connectionState) {
                  ConnectionState.waiting => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  _ when snapshot.hasData => CustomPaint(
                    painter: _LargeTrendPainter(snapshot.data!.history),
                  ),
                  _ => Center(
                    child: Text(
                      '趋势数据加载失败',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(13),
      decoration: _panelDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: value.startsWith('+')
                  ? const Color(0xFF47A87D)
                  : AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _panelDecoration(radius: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '01 / 市场趋势',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '稳定币总市值',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const _PeriodSelector(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(painter: _LargeTrendPainter(values)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final label in const ['7D', '30D', '90D', '全部'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: label == '30D' ? AppColors.cyan : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: label == '30D' ? Colors.white : AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SharePanel extends StatelessWidget {
  const _SharePanel({required this.entries, this.onOpen});

  final List<StablecoinAsset> entries;
  final ValueChanged<StablecoinAsset>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(radius: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(index: '02', label: '供应占比', title: '市占率'),
          const SizedBox(height: 14),
          for (final entry in entries) ...[
            InkWell(
              key: Key('stablecoin-asset-${entry.id}'),
              onTap: onOpen == null ? null : () => onOpen!(entry),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.cyan.withValues(alpha: .16),
                      child: Text(
                        entry.symbol.isEmpty
                            ? '?'
                            : entry.symbol.substring(0, 1),
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.symbol,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.dominance.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onOpen != null) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (entry.dominance / 100).clamp(0, 1),
                minHeight: 5,
                color: Color(entry.color),
                backgroundColor: AppColors.glassStrong,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.networks});

  final List<StablecoinChain> networks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(radius: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(index: '03', label: '网络分布', title: '链上分布'),
          const SizedBox(height: 14),
          for (final item in networks) ...[
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violet.withValues(alpha: .18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.name.isEmpty ? '?' : item.name.substring(0, 1),
                    style: TextStyle(
                      color: AppColors.violet,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        item.value,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.share.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.index,
    required this.label,
    required this.title,
  });

  final String index;
  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index / $label',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricsTable extends StatelessWidget {
  const _MetricsTable({
    required this.dashboard,
    required this.cards,
    required this.onOpenCard,
    super.key,
  });

  final CardMetricsDashboard dashboard;
  final List<CardSummary> cards;
  final ValueChanged<CardSummary> onOpenCard;

  List<(String, String, String, String, String)> get rows => dashboard.items
      .map(
        (item) => (
          item.name,
          item.logoText.isNotEmpty
              ? item.logoText
              : item.name.isNotEmpty
              ? item.name.substring(0, 1)
              : '?',
          _number(item.sevenDay),
          _number(item.thirtyDay),
          _number(item.total),
        ),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('metrics-data-table'),
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      decoration: _panelDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主流 U 卡链上数据',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '来源 ${dashboard.source}   ${_time(dashboard.updatedAt)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC45D).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '● ${dashboard.source}',
                  style: const TextStyle(
                    color: Color(0xFFD89528),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.cyan,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 650,
                child: Column(
                  children: [
                    const _MetricHeader(),
                    for (var index = 0; index < rows.length; index++)
                      _MetricRow(
                        index: index,
                        row: rows[index],
                        onTap: () => _openMatchingCard(rows[index].$1),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMatchingCard(String name) {
    final needle = name.toLowerCase();
    for (final card in cards) {
      final candidate = '${card.name} ${card.issuer}'.toLowerCase();
      if (candidate.contains(needle) ||
          (needle == 'etherfi' && candidate.contains('etherfi')) ||
          (needle == 'metamask' && candidate.contains('metamask'))) {
        onOpenCard(card);
        return;
      }
    }
  }

  String _number(num value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _time(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: AppColors.glassStrong,
      child: const Row(
        children: [
          _TableCell(width: 164, text: 'U 卡', header: true),
          _TableCell(width: 144, text: '7 天充值量', header: true),
          _TableCell(width: 160, text: '30 天充值量', header: true),
          _TableCell(width: 182, text: '累计充值量', header: true),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.index,
    required this.row,
    required this.onTap,
  });

  final int index;
  final (String, String, String, String, String) row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final max = 67520000.0;
    final current = double.tryParse(row.$3.replaceAll(',', '')) ?? 0;
    return Material(
      color: index.isEven ? AppColors.glass : AppColors.glassStrong,
      child: InkWell(
        key: Key('metric-row-${row.$1.toLowerCase().replaceAll(' ', '-')}'),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              SizedBox(
                width: 164,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? const Color(0xFF111522)
                              : AppColors.cyan.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          row.$2,
                          style: TextStyle(
                            color: index.isEven ? Colors.white : AppColors.cyan,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          row.$1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.glassStrong,
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _MetricValueCell(
                width: 144,
                value: row.$3,
                ratio: math.max(.02, current / max),
                color: const Color(0xFF75D29F),
              ),
              _MetricValueCell(
                width: 160,
                value: row.$4,
                ratio: math.max(.02, current / max),
                color: const Color(0xFF76A8EA),
              ),
              _MetricValueCell(
                width: 182,
                value: row.$5,
                ratio: math.max(.02, current / max),
                color: const Color(0xFFAB8CE9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricValueCell extends StatelessWidget {
  const _MetricValueCell({
    required this.width,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final double width;
  final String value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .55),
                    color.withValues(alpha: .08),
                  ],
                ),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.width,
    required this.text,
    this.header = false,
  });

  final double width;
  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: header ? AppColors.text : AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trendPath(size, values);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cyan.withValues(alpha: .18), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LargeTrendPainter extends CustomPainter {
  const _LargeTrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = _trendPath(size, values);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cyan.withValues(alpha: .28), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
    final end = Offset(size.width - 1, size.height * .13);
    canvas.drawCircle(end, 5, Paint()..color = AppColors.glassStrong);
    canvas.drawCircle(
      end,
      5,
      Paint()
        ..color = AppColors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path _trendPath(Size size, List<double> source) {
  final samples = source.length > 48
      ? [
          for (var index = 0; index < 48; index++)
            source[(index * (source.length - 1) / 47).round()],
        ]
      : source;
  final values = samples.length < 2 ? const [0.0, 1.0] : samples;
  final minimum = values.reduce(math.min);
  final maximum = values.reduce(math.max);
  final range = maximum - minimum;
  final path = Path();
  for (var i = 0; i < values.length; i++) {
    final normalized = range == 0 ? .5 : (values[i] - minimum) / range;
    final point = Offset(
      size.width * i / (values.length - 1),
      size.height * (.88 - normalized * .76),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path;
}

BoxDecoration _panelDecoration({required double radius}) {
  return BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: [
      BoxShadow(
        color: AppColors.isDark
            ? const Color(0x33000000)
            : const Color(0x1F6673A8),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
