import 'dart:math' as math;

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/domain/ranking_data.dart';
import 'package:card_app/features/shell/widgets/animated_glass_segment.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum RankingTab { ranking, charts, metrics, articles }

enum ArticleTab { news, benefit, openCard }

const _metricCollapseDuration = Duration(milliseconds: 280);
const _metricCollapseCurve = Cubic(0.22, 0.82, 0.28, 1);

const _stablecoinIconBySymbol = <String, String>{
  'USDT':
      'https://coin-images.coingecko.com/coins/images/325/large/Tether.png?1696501661',
  'USDC':
      'https://coin-images.coingecko.com/coins/images/6319/large/USDC.png?1769615602',
  'USDS':
      'https://coin-images.coingecko.com/coins/images/39926/large/usds.webp?1726666683',
  'DAI':
      'https://coin-images.coingecko.com/coins/images/9956/large/Badge_Dai.png?1696509996',
  'USD1':
      'https://coin-images.coingecko.com/coins/images/54977/large/USD1_1000x1000_transparent.png?1749297002',
  'USDE':
      'https://coin-images.coingecko.com/coins/images/33613/large/usde.png?1733810059',
  'USDG':
      'https://coin-images.coingecko.com/coins/images/51281/large/GDN_USDG_Token_200x200.png?1730484111',
  'PYUSD':
      'https://coin-images.coingecko.com/coins/images/31212/large/PYUSD_Token_Logo_2x.png?1765987788',
  'USDY':
      'https://coin-images.coingecko.com/coins/images/31700/large/usdy_%281%29.png?1696530524',
  'RLUSD':
      'https://coin-images.coingecko.com/coins/images/39651/large/RLUSD_200x200_%281%29.png?1727376633',
  'USDD':
      'https://coin-images.coingecko.com/coins/images/25380/large/UUSD.jpg?1696524513',
  'USDF':
      'https://coin-images.coingecko.com/coins/images/54558/large/ff_200_X_200.png?1740741076',
  'U':
      'https://coin-images.coingecko.com/coins/images/71157/large/united-stables-logo.jpg?1766061640',
};

const _chainIconByName = <String, String>{
  'Ethereum': 'https://icons.llamao.fi/icons/chains/rsz_Ethereum.jpg',
  'Tron': 'https://icons.llamao.fi/icons/chains/rsz_Tron.jpg',
  'Solana': 'https://icons.llamao.fi/icons/chains/rsz_Solana.jpg',
  'BSC': 'https://icons.llamao.fi/icons/chains/rsz_BSC.jpg',
  'Base': 'https://icons.llamao.fi/icons/chains/rsz_Base.jpg',
  'Arbitrum': 'https://icons.llamao.fi/icons/chains/rsz_Arbitrum.jpg',
  'Hyperliquid L1': 'https://icons.llamao.fi/icons/chains/rsz_Hyperliquid.jpg',
};

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
  ArticleTab _articleTab = ArticleTab.news;

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
    return AppPullToRefresh(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        key: const Key('ranking-page'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
      ),
    );
  }

  Future<void> _refreshAll() async {
    if (!widget.enableRemoteData) return;
    await _loadAll();
    if (!mounted || !_failed.contains(_tab)) return;
    throw StateError('${_tab.name} 数据刷新失败');
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
    final articles = _articles;
    final visibleItems = articles
        ?.where((item) => item.category == _articleTab.feedCategory)
        .toList(growable: false);
    return Column(
      key: const Key('article-content'),
      children: [
        _ArticleTabs(
          selected: _articleTab,
          onChanged: (tab) => setState(() => _articleTab = tab),
        ),
        const SizedBox(height: 14),
        if (visibleItems == null)
          const _ArticleListSkeleton()
        else if (visibleItems.isEmpty)
          _ArticleEmptyState(
            title: _articleTab.emptyTitle,
            description: _articleTab.emptyDescription,
          )
        else
          _LiveArticleList(items: visibleItems, onOpen: widget.onOpenArticle),
      ],
    );
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

extension on ArticleTab {
  ArticleFeedCategory get feedCategory => switch (this) {
    ArticleTab.news => ArticleFeedCategory.news,
    ArticleTab.benefit => ArticleFeedCategory.benefit,
    ArticleTab.openCard => ArticleFeedCategory.openCard,
  };

  String get label => switch (this) {
    ArticleTab.news => '资讯',
    ArticleTab.benefit => '福利',
    ArticleTab.openCard => '开卡',
  };

  String get emptyTitle => switch (this) {
    ArticleTab.news => '暂无资讯',
    ArticleTab.benefit => '暂无福利',
    ArticleTab.openCard => '暂无开卡内容',
  };

  String get emptyDescription => switch (this) {
    ArticleTab.news => '后台发布资讯后，这里会展示最新内容。',
    ArticleTab.benefit => '后台发布福利后，这里会展示最新内容。',
    ArticleTab.openCard => '后台发布开卡文章后，这里会展示最新内容。',
  };
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) =>
      const AppLoadingPanel(height: 104, label: '正在同步最新排行');
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
              alignment: WrapAlignment.start,
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
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
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
    ),
  );
}

class _LiveArticleList extends StatelessWidget {
  const _LiveArticleList({required this.items, required this.onOpen});

  final List<ArticleFeedItem> items;
  final ValueChanged<LocalArticle> onOpen;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                    if (item.coverImageUrl case final cover?
                        when cover.trim().isNotEmpty) ...[
                      AspectRatio(
                        key: Key('article-cover-frame-${item.slug}'),
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: cover,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 1000,
                            maxWidthDiskCache: 1200,
                            maxHeightDiskCache: 675,
                            fadeInDuration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            fadeOutDuration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            placeholder: (_, _) => AppShimmer(
                              key: Key(
                                'article-cover-placeholder-${item.slug}',
                              ),
                              child: ColoredBox(
                                color: AppColors.violet.withValues(alpha: 0.08),
                              ),
                            ),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: AppColors.violet.withValues(alpha: 0.06),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textMuted.withValues(
                                    alpha: .55,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (item.article.tags.isNotEmpty) ...[
                      Text(
                        item.article.tags.take(3).join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

class _ArticleListSkeleton extends StatelessWidget {
  const _ArticleListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      key: const Key('article-list-skeleton'),
      child: Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Container(
              key: Key('article-skeleton-card-$index'),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.glass,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ArticleSkeletonBar(widthFactor: .34, height: 9),
                  const SizedBox(height: 11),
                  _ArticleSkeletonBar(widthFactor: .82, height: 16),
                  const SizedBox(height: 10),
                  _ArticleSkeletonBar(widthFactor: 1, height: 10),
                  const SizedBox(height: 7),
                  _ArticleSkeletonBar(widthFactor: .72, height: 10),
                  const SizedBox(height: 12),
                  _ArticleSkeletonBar(widthFactor: .48, height: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ArticleEmptyState extends StatelessWidget {
  const _ArticleEmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('article-empty-state'),
      width: double.infinity,
      height: 178,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            width: 290,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('article-empty-glow'),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: .78,
                    colors: [
                      AppColors.violet.withValues(
                        alpha: AppColors.isDark ? .13 : .09,
                      ),
                      AppColors.cyan.withValues(
                        alpha: AppColors.isDark ? .035 : .025,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0, .4, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
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

class _ArticleSkeletonBar extends StatelessWidget {
  const _ArticleSkeletonBar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

class _ArticleTabs extends StatelessWidget {
  const _ArticleTabs({required this.selected, required this.onChanged});

  final ArticleTab selected;
  final ValueChanged<ArticleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedPillSegment<ArticleTab>(
      height: 30,
      gap: 10,
      fontSize: 11,
      items: [
        for (final tab in ArticleTab.values)
          GlassSegmentItem(
            value: tab,
            label: tab.label,
            key: Key('article-tab-${tab.name}'),
          ),
      ],
      selected: selected,
      onChanged: onChanged,
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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SharePanel(
                  entries: dashboard.assets.take(7).toList(),
                  onOpen: enableRemoteData
                      ? (asset) => _showStablecoinDetail(context, asset)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NetworkPanel(
                  networks: dashboard.chains.take(8).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StablecoinAssetList(
          assets: dashboard.assets.take(15).toList(growable: false),
          networks: dashboard.chains
              .map((item) => item.name)
              .toList(growable: false),
          onOpen: enableRemoteData
              ? (asset) => _showStablecoinDetail(context, asset)
              : null,
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

class _StablecoinAssetList extends StatefulWidget {
  const _StablecoinAssetList({
    required this.assets,
    required this.networks,
    required this.onOpen,
  });

  final List<StablecoinAsset> assets;
  final List<String> networks;
  final ValueChanged<StablecoinAsset>? onOpen;

  @override
  State<_StablecoinAssetList> createState() => _StablecoinAssetListState();
}

class _StablecoinAssetListState extends State<_StablecoinAssetList> {
  String _query = '';
  String _network = '全部';
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final filters = ['全部', ...widget.networks.where((item) => item.isNotEmpty)];
    final visible = widget.assets
        .where((asset) {
          final keyword = _query.trim().toLowerCase();
          final matchQuery =
              keyword.isEmpty ||
              '${asset.symbol} ${asset.name}'.toLowerCase().contains(keyword);
          final matchNetwork =
              _network == '全部' || asset.chains.contains(_network);
          return matchQuery && matchNetwork;
        })
        .toList(growable: false);
    return Container(
      key: const Key('stablecoin-asset-list'),
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 4),
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
                      '04 / 资产筛选',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '稳定币列表（前 15）',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 132,
                child: TextField(
                  key: const Key('stablecoin-search'),
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索稳定币',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    filled: true,
                    fillColor: AppColors.glassStrong,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.cyan),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in filters) ...[
                  ChoiceChip(
                    key: Key('stablecoin-filter-$filter'),
                    label: Text(filter),
                    selected: _network == filter,
                    onSelected: (_) => setState(() => _network = filter),
                    labelStyle: TextStyle(
                      color: _network == filter
                          ? Colors.white
                          : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    selectedColor: AppColors.cyan,
                    backgroundColor: AppColors.glassStrong,
                    side: BorderSide(color: AppColors.line),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _StablecoinTableHeader(),
          for (final asset in visible)
            _StablecoinAssetRow(
              asset: asset,
              expanded: _expandedId == asset.id,
              onTap: () => setState(() {
                _expandedId = _expandedId == asset.id ? null : asset.id;
              }),
              onOpen: widget.onOpen == null
                  ? null
                  : () => widget.onOpen!(asset),
            ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  '没有匹配的稳定币',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StablecoinTableHeader extends StatelessWidget {
  const _StablecoinTableHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
    child: Row(
      children: [
        Expanded(child: Text('资产', style: _stablecoinTableLabelStyle)),
        SizedBox(
          width: 64,
          child: Text(
            '市值',
            textAlign: TextAlign.right,
            style: _stablecoinTableLabelStyle,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '24H',
            textAlign: TextAlign.right,
            style: _stablecoinTableLabelStyle,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '网络',
            textAlign: TextAlign.right,
            style: _stablecoinTableLabelStyle,
          ),
        ),
      ],
    ),
  );
}

final _stablecoinTableLabelStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10,
  fontWeight: FontWeight.w800,
);

class _StablecoinMark extends StatelessWidget {
  const _StablecoinMark({required this.asset, required this.size});

  final StablecoinAsset asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconUrl =
        asset.imageUrl ?? _stablecoinIconBySymbol[asset.symbol.toUpperCase()];
    final fallback = Center(
      child: Text(
        asset.symbol.isEmpty ? '?' : asset.symbol.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      key: Key('stablecoin-icon-${asset.symbol.toLowerCase()}'),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(asset.color),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(asset.color).withValues(alpha: .16),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
      child: iconUrl == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

class _ChainMark extends StatelessWidget {
  const _ChainMark({required this.chain, required this.size});

  final StablecoinChain chain;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconUrl =
        chain.imageUrl ??
        _chainIconByName[chain.name] ??
        'https://icons.llamao.fi/icons/chains/rsz_${Uri.encodeComponent(chain.name)}.jpg';
    final color = chain.color == null ? AppColors.violet : Color(chain.color!);
    final fallback = Center(
      child: Text(
        chain.name.isEmpty ? '?' : chain.name.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      key: Key(
        'stablecoin-chain-icon-${chain.name.toLowerCase().replaceAll(' ', '-')}',
      ),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .12),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
      child: CachedNetworkImage(
        imageUrl: iconUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _StablecoinAssetRow extends StatelessWidget {
  const _StablecoinAssetRow({
    required this.asset,
    required this.expanded,
    required this.onTap,
    this.onOpen,
  });

  final StablecoinAsset asset;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final positive = asset.change >= 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('stablecoin-row-${asset.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            children: [
              Row(
                children: [
                  _StablecoinMark(asset: asset, size: 34),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.symbol,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          asset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      asset.marketCap,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${positive ? '+' : ''}${asset.change.toStringAsFixed(2)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: positive
                            ? const Color(0xFF45CFA6)
                            : const Color(0xFFF07083),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${asset.chains.length}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        Icon(
                          expanded
                              ? Icons.expand_less_rounded
                              : Icons.chevron_right_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.glassStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          asset.chains.isEmpty
                              ? '网络信息暂未提供'
                              : '支持网络：${asset.chains.join(' · ')}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      if (onOpen != null)
                        TextButton(
                          onPressed: onOpen,
                          child: const Text('查看详情'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
                  _StablecoinMark(asset: asset, size: 38),
                  const SizedBox(width: 10),
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
                    child: AppLoadingIndicator(size: 42),
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
      key: const Key('stablecoin-share-panel'),
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
                    _StablecoinMark(asset: entry, size: 16),
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
            AppProgressBar(
              value: (entry.dominance / 100).clamp(0, 1),
              height: 5,
              color: Color(entry.color),
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
      key: const Key('stablecoin-network-panel'),
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
                _ChainMark(chain: item, size: 18),
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

  List<_MetricDisplayRow> get rows => dashboard.items
      .map(
        (item) => _MetricDisplayRow(
          item: item,
          logoText: item.logoText.isNotEmpty
              ? item.logoText
              : item.name.isNotEmpty
              ? item.name.substring(0, 1)
              : '?',
          sevenDay: _number(item.sevenDay),
          thirtyDay: _number(item.thirtyDay),
          total: _number(item.total),
          transactions: _number(item.transactions),
          addresses: _number(item.addresses),
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
                      '按 30 天充值量排序 · 来源 ${dashboard.source}   ${_time(dashboard.updatedAt)}',
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
          _MetricsDataGrid(
            rows: rows,
            cards: cards,
            onOpenCard: _openMatchingCard,
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

class _MetricDisplayRow {
  const _MetricDisplayRow({
    required this.item,
    required this.logoText,
    required this.sevenDay,
    required this.thirtyDay,
    required this.total,
    required this.transactions,
    required this.addresses,
  });

  final CardMetric item;
  final String logoText;
  final String sevenDay;
  final String thirtyDay;
  final String total;
  final String transactions;
  final String addresses;
}

class _MetricsDataGrid extends StatefulWidget {
  const _MetricsDataGrid({
    required this.rows,
    required this.cards,
    required this.onOpenCard,
  });

  final List<_MetricDisplayRow> rows;
  final List<CardSummary> cards;
  final ValueChanged<String> onOpenCard;

  @override
  State<_MetricsDataGrid> createState() => _MetricsDataGridState();
}

class _MetricsDataGridState extends State<_MetricsDataGrid> {
  late final ScrollController _scrollController;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final next = _scrollController.offset > 8;
    if (next == _collapsed || !mounted) return;
    setState(() => _collapsed = next);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            key: const Key('metrics-fixed-card-column'),
            duration: reduceMotion ? Duration.zero : _metricCollapseDuration,
            curve: _metricCollapseCurve,
            width: _collapsed ? 54 : 164,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.line, width: 1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF1C2446,
                  ).withValues(alpha: AppColors.isDark ? .18 : .08),
                  blurRadius: _collapsed ? 18 : 8,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _MetricIdentityHeader(collapsed: _collapsed),
                for (var index = 0; index < widget.rows.length; index++)
                  _MetricIdentityRow(
                    index: index,
                    row: widget.rows[index],
                    cards: widget.cards,
                    collapsed: _collapsed,
                    onTap: () =>
                        widget.onOpenCard(widget.rows[index].item.name),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('metrics-scrollable-values'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 804,
                child: Column(
                  children: [
                    const _MetricValuesHeader(),
                    for (var index = 0; index < widget.rows.length; index++)
                      _MetricValuesRow(index: index, row: widget.rows[index]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _brandLogoFiles = <String, String>{
  'apple': 'apple-cash.png',
  'n26': 'n26.png',
  'boc': 'boc.gif',
  'hsbc': 'hsbc.png',
  'welab': 'welab.png',
  'bybit': 'bybit.png',
  'plasma': 'plasma.svg',
  'etherfi': 'etherfi.svg',
  'redotpay': 'redotpay.png',
  'safepal': 'safepal.png',
  'bitget': 'bitget.png',
  'mexc': 'mexc.png',
  'tria': 'tria.png',
  'kast': 'kast.png',
  'karta': 'karta.svg',
  'kolo': 'kolo.png',
  'crypto': 'crypto.png',
  'gnosis': 'gnosis.svg',
  'holyheld': 'holyheld.svg',
  'okx': 'okx.png',
  'ready': 'ready.svg',
  'tuyo': 'tuyo.svg',
  'exa': 'exa.svg',
  'avalanche': 'avalanche.svg',
  'phantom': 'phantom.svg',
  'solflare': 'solflare.svg',
  'cypher': 'cypher.svg',
  'metamask': 'metamask.png',
  'bfinance': 'bfinance.svg',
  'hyperbeat': 'hyperbeat.svg',
  'solayer': 'solayer.png',
  '1inch': '1inch.png',
  'avici': 'avici.png',
  'uuwallet': 'uuwallet.png',
  'savo': 'savo.png',
  'starryblu': 'starryblu.png',
  'backpack': 'backpack.png',
  'jeton': 'jeton.png',
  'coinbase': 'coinbase.png',
};

class _CardBrandMark extends StatelessWidget {
  const _CardBrandMark({
    required this.metric,
    required this.cards,
    required this.fallbackText,
  });

  final CardMetric metric;
  final List<CardSummary> cards;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final card = _matchingCard;
    final brandKey = _brandKey(card);
    final networkSource = card?.logoImageUrl;
    final assetFile = brandKey == null ? null : _brandLogoFiles[brandKey];
    final fallback = Center(
      child: Text(
        fallbackText,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: _fallbackForeground(brandKey),
          fontSize: fallbackText.length > 3 ? 6.5 : 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      key: Key('metric-brand-${metric.id}'),
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(3),
      clipBehavior: Clip.antiAlias,
      decoration: _brandDecoration(brandKey),
      child: networkSource != null && networkSource.isNotEmpty
          ? _logoFromNetwork(networkSource, fallback)
          : assetFile == null
          ? fallback
          : _logoFromAsset('assets/brand-logos/$assetFile', fallback),
    );
  }

  CardSummary? get _matchingCard {
    final cardId = metric.cardId;
    if (cardId != null) {
      for (final card in cards) {
        if (card.id == cardId) return card;
      }
    }
    final needle = metric.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    for (final card in cards) {
      final candidate = '${card.name}${card.issuer}'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (candidate.contains(needle) || needle.contains(candidate)) return card;
    }
    return null;
  }

  String? _brandKey(CardSummary? card) {
    final logoClass = metric.logo.trim().toLowerCase();
    if (logoClass.startsWith('logo-')) return logoClass.substring(5);
    final source =
        '${metric.cardId ?? ''} ${metric.name} ${card?.name ?? ''} ${card?.issuer ?? ''}'
            .toLowerCase()
            .replaceAll('.', '');
    const aliases = <String, String>{
      'etherfi': 'etherfi',
      'redot': 'redotpay',
      'meta mask': 'metamask',
      'crypto com': 'crypto',
      'bitget': 'bitget',
      'safe pal': 'safepal',
      'starry blu': 'starryblu',
    };
    for (final entry in aliases.entries) {
      if (source.contains(entry.key)) return entry.value;
    }
    for (final key in _brandLogoFiles.keys) {
      if (source.contains(key)) return key;
    }
    return null;
  }

  Widget _logoFromAsset(String source, Widget fallback) {
    if (source.endsWith('.svg')) {
      return SvgPicture.asset(
        source,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      );
    }
    return Image.asset(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _logoFromNetwork(String source, Widget fallback) {
    if (Uri.tryParse(source)?.path.toLowerCase().endsWith('.svg') ?? false) {
      return SvgPicture.network(
        source,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.contain,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  Color _fallbackForeground(String? key) => switch (key) {
    'holyheld' ||
    'exa' ||
    'solayer' ||
    'gnosis' ||
    'ready' ||
    'avalanche' ||
    'phantom' ||
    'solflare' ||
    'kast' ||
    'tria' ||
    'karta' ||
    'safepal' ||
    'hyperbeat' => Colors.white,
    _ => const Color(0xFF10131B),
  };

  BoxDecoration _brandDecoration(String? key) {
    final colors = switch (key) {
      'kolo' => const [Color(0xFF28D85A), Color(0xFF28D85A)],
      'holyheld' => const [Color(0xFF16171B), Color(0xFF2A2D33)],
      'tuyo' => const [Color(0xFFA9EC52), Color(0xFFA9EC52)],
      'exa' => const [Color(0xFF26302D), Color(0xFF3A4541)],
      'solayer' => const [Color(0xFF0D4B40), Color(0xFF1B6A58)],
      'gnosis' => const [Color(0xFF111827), Color(0xFF1B2940)],
      'ready' => const [Color(0xFF20283A), Color(0xFF3A4356)],
      'avalanche' => const [Color(0xFFF04652), Color(0xFFC12639)],
      'phantom' => const [Color(0xFF7B5CFF), Color(0xFFB45CFF)],
      'solflare' => const [Color(0xFFFF8A2B), Color(0xFFFF5F45)],
      'kast' ||
      'tria' ||
      'karta' => const [Color(0xFF050507), Color(0xFF232733)],
      'bitget' => const [Color(0xFF08D7D0), Color(0xFF68EFE6)],
      'safepal' => const [Color(0xFF0A0537), Color(0xFF2A1175)],
      'hyperbeat' => const [
        Color(0xFF111827),
        Color(0xFF2457FF),
        Color(0xFF1DF2CF),
      ],
      'plasma' || 'bfinance' => const [Color(0xFFF8FAFC), Color(0xFFF8FAFC)],
      _ => const [Colors.white, Colors.white],
    };
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0xFF1C2446,
          ).withValues(alpha: AppColors.isDark ? .24 : .08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _MetricIdentityHeader extends StatelessWidget {
  const _MetricIdentityHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _metricCollapseDuration;
    return Container(
      key: const Key('metrics-fixed-header'),
      height: 46,
      color: AppColors.glassStrong,
      alignment: Alignment.center,
      child: AnimatedSlide(
        duration: duration,
        curve: _metricCollapseCurve,
        offset: collapsed ? const Offset(-.18, 0) : Offset.zero,
        child: AnimatedOpacity(
          key: const Key('metrics-fixed-header-label-opacity'),
          duration: duration,
          curve: _metricCollapseCurve,
          opacity: collapsed ? 0 : 1,
          child: Text(
            'U 卡',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricValuesHeader extends StatelessWidget {
  const _MetricValuesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('metrics-values-header'),
      height: 46,
      color: AppColors.glassStrong,
      child: const Row(
        children: [
          _TableCell(width: 144, text: '7 天充值量', header: true),
          _TableCell(width: 160, text: '30 天充值量', header: true),
          _TableCell(width: 182, text: '累计充值量', header: true),
          _TableCell(width: 168, text: '链上交互笔数', header: true),
          _TableCell(width: 150, text: '可观测地址', header: true),
        ],
      ),
    );
  }
}

class _MetricIdentityRow extends StatelessWidget {
  const _MetricIdentityRow({
    required this.index,
    required this.row,
    required this.cards,
    required this.collapsed,
    required this.onTap,
  });

  final int index;
  final _MetricDisplayRow row;
  final List<CardSummary> cards;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _metricCollapseDuration;
    return Material(
      color: index.isEven ? AppColors.glass : AppColors.glassStrong,
      child: InkWell(
        key: Key(
          'metric-row-${row.item.name.toLowerCase().replaceAll(' ', '-')}',
        ),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: _metricCollapseCurve,
                left: collapsed ? 12 : 10,
                top: 10,
                child: AnimatedScale(
                  duration: duration,
                  curve: _metricCollapseCurve,
                  scale: collapsed ? .96 : 1,
                  child: _CardBrandMark(
                    metric: row.item,
                    cards: cards,
                    fallbackText: row.logoText,
                  ),
                ),
              ),
              Positioned(
                left: 49,
                top: 0,
                bottom: 0,
                width: 82,
                child: AnimatedSlide(
                  duration: duration,
                  curve: _metricCollapseCurve,
                  offset: collapsed ? const Offset(-.12, 0) : Offset.zero,
                  child: AnimatedOpacity(
                    key: Key('metric-name-visibility-${row.item.id}'),
                    duration: duration,
                    curve: _metricCollapseCurve,
                    opacity: collapsed ? 0 : 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row.item.name,
                        key: Key('metric-name-${row.item.id}'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 136,
                top: 16,
                child: AnimatedSlide(
                  duration: duration,
                  curve: _metricCollapseCurve,
                  offset: collapsed ? const Offset(-.2, 0) : Offset.zero,
                  child: AnimatedOpacity(
                    key: Key('metric-rank-visibility-${row.item.id}'),
                    duration: duration,
                    curve: _metricCollapseCurve,
                    opacity: collapsed ? 0 : 1,
                    child: Container(
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricValuesRow extends StatelessWidget {
  const _MetricValuesRow({required this.index, required this.row});

  final int index;
  final _MetricDisplayRow row;

  @override
  Widget build(BuildContext context) {
    final max = 67520000.0;
    final current = double.tryParse(row.sevenDay.replaceAll(',', '')) ?? 0;
    return Material(
      color: index.isEven ? AppColors.glass : AppColors.glassStrong,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            _MetricValueCell(
              width: 144,
              value: row.sevenDay,
              ratio: math.max(.02, current / max),
              color: const Color(0xFF75D29F),
            ),
            _MetricValueCell(
              width: 160,
              value: row.thirtyDay,
              ratio: math.max(.02, current / max),
              color: const Color(0xFF76A8EA),
            ),
            _MetricValueCell(
              width: 182,
              value: row.total,
              ratio: math.max(.02, current / max),
              color: const Color(0xFFAB8CE9),
            ),
            _MetricValueCell(
              width: 168,
              value: row.transactions,
              ratio: math.max(
                .02,
                (double.tryParse(row.transactions.replaceAll(',', '')) ?? 0) /
                    max,
              ),
              color: const Color(0xFF60D8B8),
            ),
            _MetricValueCell(
              width: 150,
              value: row.addresses,
              ratio: math.max(
                .02,
                (double.tryParse(row.addresses.replaceAll(',', '')) ?? 0) / max,
              ),
              color: const Color(0xFFFFC45D),
            ),
          ],
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
