import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/core/widgets/scroll_to_top_button.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/catalog/widgets/global_account_catalog_card.dart';
import 'package:cardfi/features/pro/widgets/pro_crown_badge.dart';
import 'package:cardfi/features/shell/widgets/animated_glass_segment.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

enum _MarketGroup { uCard, globalAccount, other }

enum _UCardFilter { all, newest, idCard, passport }

enum _OtherCardFilter {
  all('全部'),
  hk('港卡', CardMarketRegion.hk),
  us('美卡', CardMarketRegion.us),
  cn('内地卡', CardMarketRegion.cn),
  more('更多', CardMarketRegion.more);

  const _OtherCardFilter(this.label, [this.region]);

  final String label;
  final CardMarketRegion? region;
}

enum _GlobalAccountTypeFilter { all, traditional, cryptoRelated }

enum _GlobalAccountKycFilter {
  all,
  available,
  conditional,
  unavailable,
  unknown,
}

enum _GlobalAccountCapabilityFilter { all, usd, cryptoDeposit, bankTransfer }

typedef MarketCardOpenTransition =
    void Function(CardSummary card, CatalogCardSourceGeometry geometry);

class MarketPage extends StatefulWidget {
  const MarketPage({
    required this.repository,
    required this.onSearch,
    required this.onOpenCard,
    this.onOpenCardTransition,
    this.transitioningCardId,
    this.onCompare,
    this.onOpenCanvas,
    this.onOpenAiAdvisor,
    super.key,
  });

  final CardCatalogRepository repository;
  final VoidCallback onSearch;
  final VoidCallback? onCompare;
  final ValueChanged<CardSummary> onOpenCard;
  final MarketCardOpenTransition? onOpenCardTransition;
  final String? transitioningCardId;
  final VoidCallback? onOpenCanvas;
  final VoidCallback? onOpenAiAdvisor;

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  late final ScrollController _scrollController;
  _MarketGroup _group = _MarketGroup.uCard;
  _UCardFilter _filter = _UCardFilter.all;
  _OtherCardFilter _otherFilter = _OtherCardFilter.all;
  _GlobalAccountTypeFilter _globalAccountTypeFilter =
      _GlobalAccountTypeFilter.all;
  _GlobalAccountKycFilter _globalAccountKycFilter = _GlobalAccountKycFilter.all;
  _GlobalAccountCapabilityFilter _globalAccountCapabilityFilter =
      _GlobalAccountCapabilityFilter.all;
  List<CardSummary>? _cards;
  Object? _error;
  int _contentDirection = 1;
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(_updateScrollTopVisibility);
    _loadCards();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateScrollTopVisibility)
      ..dispose();
    super.dispose();
  }

  void _updateScrollTopVisibility() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final next = position.pixels > position.viewportDimension;
    if (next == _showScrollTop || !mounted) return;
    setState(() => _showScrollTop = next);
  }

  Future<void> _scrollToTop() => _scrollController.animateTo(
    0,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotionTokens.page,
    curve: MotionTokens.standardEnter,
  );

  Future<void> _loadCards({
    bool force = false,
    bool rethrowOnError = false,
  }) async {
    setState(() => _error = null);
    try {
      final cards = await widget.repository.loadCards(force: force);
      if (!mounted) return;
      setState(() => _cards = cards);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _error = error);
      if (rethrowOnError) Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<CardSummary> get _filteredCards {
    final cards = _cards ?? const <CardSummary>[];
    if (_group == _MarketGroup.globalAccount) {
      // Keep the provider-curated order. Crypto-related services receive a
      // disclosure on their cards, but must not be silently pushed below the
      // first screen of the directory.
      return cards
          .where(
            (card) => card.isGlobalAccount && _matchesGlobalAccountFilter(card),
          )
          .toList();
    }
    if (_group == _MarketGroup.other) {
      return cards
          .where(
            (card) =>
                !card.category.isUCard &&
                !card.isGlobalAccount &&
                (_otherFilter.region == null ||
                    card.marketRegion == _otherFilter.region),
          )
          .toList();
    }
    return cards.where((card) {
      if (!card.category.isUCard) return false;
      return switch (_filter) {
        _UCardFilter.all => true,
        _UCardFilter.newest => card.isNew,
        _UCardFilter.idCard => card.kycDocuments.contains(KycDocument.idCard),
        _UCardFilter.passport => card.kycDocuments.contains(
          KycDocument.passport,
        ),
      };
    }).toList();
  }

  bool _matchesGlobalAccountFilter(CardSummary card) =>
      _matchesTypeFilter(card) &&
      _matchesKycFilter(card) &&
      _matchesCapabilityFilter(card);

  bool _matchesTypeFilter(CardSummary card) =>
      switch (_globalAccountTypeFilter) {
        _GlobalAccountTypeFilter.all => true,
        _GlobalAccountTypeFilter.traditional => !card.isCryptoRelated,
        _GlobalAccountTypeFilter.cryptoRelated => card.isCryptoRelated,
      };

  bool _matchesKycFilter(CardSummary card) => switch (_globalAccountKycFilter) {
    _GlobalAccountKycFilter.all => true,
    _GlobalAccountKycFilter.available => card.chinaKycStatus == 'available',
    _GlobalAccountKycFilter.conditional => card.chinaKycStatus == 'conditional',
    _GlobalAccountKycFilter.unavailable => card.chinaKycStatus == 'unavailable',
    _GlobalAccountKycFilter.unknown => card.chinaKycStatus == 'unknown',
  };

  bool _matchesCapabilityFilter(CardSummary card) =>
      switch (_globalAccountCapabilityFilter) {
        _GlobalAccountCapabilityFilter.all => true,
        _GlobalAccountCapabilityFilter.usd => card.transferCurrencies.contains(
          'USD',
        ),
        _GlobalAccountCapabilityFilter.cryptoDeposit =>
          card.receivingMethods.contains('crypto'),
        _GlobalAccountCapabilityFilter.bankTransfer =>
          card.receivingMethods.any(
            const {'ach', 'local', 'sepa', 'swift', 'wire'}.contains,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final mainSegment = _MainSegment(
      selected: _group,
      // H5 在目录接口不可用时不显示 0，避免把“未知”误报成空统计。
      uCardCount: _cards?.where((card) => card.category.isUCard).length,
      globalAccountCount: _cards?.where((card) => card.isGlobalAccount).length,
      otherCount: _cards
          ?.where((card) => !card.category.isUCard && !card.isGlobalAccount)
          .length,
      onSelected: _selectGroup,
    );
    return Material(
      color: Colors.transparent,
      child: AppPullToRefresh(
        onRefresh: () => _loadCards(force: true, rethrowOnError: true),
        child: Stack(
          children: [
            CustomScrollView(
              key: const Key('market-page'),
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 5),
                  sliver: SliverToBoxAdapter(
                    child: _MarketHeader(
                      onSearch: widget.onSearch,
                      onCompare: widget.onCompare,
                      onOpenCanvas: widget.onOpenCanvas,
                      onOpenAiAdvisor: widget.onOpenAiAdvisor,
                    ),
                  ),
                ),
                // U 卡进入列表后只保留其二级筛选固定；主分类随内容自然
                // 离开。全球账户和其他则继续固定主分类，方便跨列表切换。
                if (_group == _MarketGroup.uCard)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 5, 24, 5),
                      child: mainSegment,
                    ),
                  )
                else
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PinnedGlassHeaderDelegate(
                      // Regional pills keep a 44px touch target; the account
                      // dropdowns use their existing 38px compact layout.
                      height: _group == _MarketGroup.globalAccount ? 105 : 111,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 5, 24, 7),
                        child: _group == _MarketGroup.globalAccount
                            ? Column(
                                children: [
                                  mainSegment,
                                  const SizedBox(height: 7),
                                  _GlobalAccountFilterPanel(
                                    accounts: (_cards ?? const <CardSummary>[])
                                        .where((card) => card.isGlobalAccount)
                                        .toList(growable: false),
                                    selectedType: _globalAccountTypeFilter,
                                    selectedKyc: _globalAccountKycFilter,
                                    selectedCapability:
                                        _globalAccountCapabilityFilter,
                                    onTypeSelected:
                                        _selectGlobalAccountTypeFilter,
                                    onKycSelected:
                                        _selectGlobalAccountKycFilter,
                                    onCapabilitySelected:
                                        _selectGlobalAccountCapabilityFilter,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  mainSegment,
                                  const SizedBox(height: 7),
                                  _OtherCardSegment(
                                    selected: _otherFilter,
                                    onSelected: _selectOtherFilter,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                if (_group == _MarketGroup.uCard)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PinnedGlassHeaderDelegate(
                      height: 46,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _SubSegment(
                          selected: _filter,
                          onSelected: _selectFilter,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 132 + bottomInset),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : MotionTokens.contentSwitch,
                      switchInCurve: MotionTokens.standardEnter,
                      switchOutCurve: MotionTokens.standardExit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0.035 * _contentDirection, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              key: const Key('market-scroll-to-top'),
              right: 20,
              bottom: bottomInset + 88,
              child: ScrollToTopButton(
                visible: _showScrollTop,
                onTap: _scrollToTop,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectGroup(_MarketGroup group) {
    if (group == _group) return;
    setState(() {
      _contentDirection = group.index > _group.index ? 1 : -1;
      _group = group;
      if (group == _MarketGroup.other) {
        _filter = _UCardFilter.all;
      }
    });
  }

  void _selectFilter(_UCardFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _contentDirection = filter.index > _filter.index ? 1 : -1;
      _filter = filter;
    });
  }

  void _selectOtherFilter(_OtherCardFilter filter) {
    if (filter == _otherFilter) return;
    setState(() {
      _contentDirection = filter.index > _otherFilter.index ? 1 : -1;
      _otherFilter = filter;
    });
  }

  void _selectGlobalAccountTypeFilter(_GlobalAccountTypeFilter filter) {
    if (filter == _globalAccountTypeFilter) return;
    setState(() {
      _contentDirection = filter.index > _globalAccountTypeFilter.index
          ? 1
          : -1;
      _globalAccountTypeFilter = filter;
    });
  }

  void _selectGlobalAccountKycFilter(_GlobalAccountKycFilter filter) {
    if (filter == _globalAccountKycFilter) return;
    setState(() {
      _contentDirection = filter.index > _globalAccountKycFilter.index ? 1 : -1;
      _globalAccountKycFilter = filter;
    });
  }

  void _selectGlobalAccountCapabilityFilter(
    _GlobalAccountCapabilityFilter filter,
  ) {
    if (filter == _globalAccountCapabilityFilter) return;
    setState(() {
      _contentDirection = filter.index > _globalAccountCapabilityFilter.index
          ? 1
          : -1;
      _globalAccountCapabilityFilter = filter;
    });
  }

  Widget _buildContent() {
    if (_error != null) {
      return _MarketMessage(
        key: Key('market-error'),
        icon: Icons.cloud_off_rounded,
        title: '暂时无法加载卡片',
        description: '请检查网络状态后重试。',
        actionLabel: '重新加载',
        onAction: _loadCards,
      );
    }
    if (_cards == null) {
      return const _MarketSkeleton(key: Key('market-loading'));
    }
    final cards = _filteredCards;
    if (cards.isEmpty) {
      return const _MarketMessage(
        key: Key('market-empty'),
        title: '没有找到匹配卡片',
        description: '换个关键词或分类试试',
      );
    }
    return Column(
      key: ValueKey(
        '${_group.name}-${_filter.name}-${_otherFilter.name}-${_globalAccountTypeFilter.name}-${_globalAccountKycFilter.name}-${_globalAccountCapabilityFilter.name}',
      ),
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (cards[index].isGlobalAccount)
            GlobalAccountCatalogCard(
              card: cards[index],
              onTap: () => widget.onOpenCard(cards[index]),
              sharedContentHidden:
                  widget.transitioningCardId == cards[index].id,
              onTapWithGeometry: widget.onOpenCardTransition == null
                  ? null
                  : (geometry) =>
                        widget.onOpenCardTransition!(cards[index], geometry),
            )
          else
            CatalogCardRow(
              card: cards[index],
              onTap: () => widget.onOpenCard(cards[index]),
              enableMotion: true,
              sharedContentHidden:
                  widget.transitioningCardId == cards[index].id,
              onTapWithGeometry: widget.onOpenCardTransition == null
                  ? null
                  : (geometry) =>
                        widget.onOpenCardTransition!(cards[index], geometry),
            ),
          if (index != cards.length - 1) SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({
    required this.onSearch,
    this.onOpenCanvas,
    this.onCompare,
    this.onOpenAiAdvisor,
  });

  final VoidCallback onSearch;
  final VoidCallback? onCompare;
  final VoidCallback? onOpenCanvas;
  final VoidCallback? onOpenAiAdvisor;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '市场',
          key: const Key('market-title'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '探索热门的卡片',
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
    final actions = _MarketHeaderActions(
      onSearch: onSearch,
      onCompare: onCompare,
      onOpenCanvas: onOpenCanvas,
      onOpenAiAdvisor: onOpenAiAdvisor,
    );

    // 操作区始终固定在标题右侧。窄屏时由标题的 FittedBox 压缩副标题，
    // 不能把整组入口落到下一行。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        actions,
      ],
    );
  }
}

class _MarketHeaderActions extends StatelessWidget {
  const _MarketHeaderActions({
    required this.onSearch,
    this.onOpenCanvas,
    this.onCompare,
    this.onOpenAiAdvisor,
  });

  final VoidCallback onSearch;
  final VoidCallback? onCompare;
  final VoidCallback? onOpenCanvas;
  final VoidCallback? onOpenAiAdvisor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCompare != null) ...[
          _MarketHeaderAction(
            key: const Key('market-compare-button'),
            icon: AppIcons.compare,
            semanticLabel: context.tr('卡片对比，普通版支持两张卡片'),
            onTap: onCompare!,
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenAiAdvisor != null) ...[
          _MarketHeaderAction(
            key: const Key('market-ai-advisor-button'),
            icon: Icons.auto_awesome_rounded,
            semanticLabel: context.tr('AI 助手，Pro 会员功能'),
            onTap: onOpenAiAdvisor!,
            showProBadge: true,
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenCanvas != null) ...[
          _MarketHeaderAction(
            key: const Key('market-canvas-button'),
            icon: AppIcons.canvas,
            semanticLabel: context.tr('打开卡片画布'),
            onTap: onOpenCanvas!,
          ),
          const SizedBox(width: 8),
        ],
        _MarketHeaderAction(
          key: const Key('market-search-button'),
          icon: Icons.search_rounded,
          semanticLabel: context.tr('搜索卡片'),
          onTap: onSearch,
        ),
      ],
    );
  }
}

class _MarketHeaderAction extends StatelessWidget {
  const _MarketHeaderAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.showProBadge = false,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool showProBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.glassStrong,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Center(
                    child: Icon(icon, color: AppColors.text, size: 22),
                  ),
                ),
              ),
            ),
            if (showProBadge)
              const Positioned(right: -4, top: -4, child: ProCrownBadge()),
          ],
        ),
      ),
    );
  }
}

class _MainSegment extends StatelessWidget {
  const _MainSegment({
    required this.selected,
    required this.uCardCount,
    required this.globalAccountCount,
    required this.otherCount,
    required this.onSelected,
  });

  final _MarketGroup selected;
  final int? uCardCount;
  final int? globalAccountCount;
  final int? otherCount;
  final ValueChanged<_MarketGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassSegment<_MarketGroup>(
      height: 48,
      padding: 5,
      radius: 24,
      items: [
        GlassSegmentItem(
          value: _MarketGroup.uCard,
          label: 'U卡${uCardCount == null ? '' : ' ($uCardCount)'}',
          key: const Key('market-group-ucard'),
        ),
        GlassSegmentItem(
          value: _MarketGroup.globalAccount,
          label:
              '全球账户${globalAccountCount == null ? '' : ' ($globalAccountCount)'}',
          key: const Key('market-group-global-account'),
        ),
        GlassSegmentItem(
          value: _MarketGroup.other,
          label: '其他${otherCount == null ? '' : ' ($otherCount)'}',
          key: const Key('market-group-other'),
        ),
      ],
      selected: selected,
      onChanged: onSelected,
    );
  }
}

class _SubSegment extends StatelessWidget {
  const _SubSegment({required this.selected, required this.onSelected});

  final _UCardFilter selected;
  final ValueChanged<_UCardFilter> onSelected;

  static const _labels = <_UCardFilter, String>{
    _UCardFilter.all: '全部',
    _UCardFilter.newest: '上新',
    _UCardFilter.idCard: '身份证可开',
    _UCardFilter.passport: '护照可开',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedPillSegment<_UCardFilter>(
      height: 30,
      gap: 10,
      fontSize: 11,
      items: [
        for (final filter in _UCardFilter.values)
          GlassSegmentItem(
            value: filter,
            label: _labels[filter]!,
            key: Key('market-filter-${filter.name}'),
          ),
      ],
      selected: selected,
      onChanged: onSelected,
    );
  }
}

class _OtherCardSegment extends StatelessWidget {
  const _OtherCardSegment({required this.selected, required this.onSelected});

  final _OtherCardFilter selected;
  final ValueChanged<_OtherCardFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const fontSize = 11.0;
    const gap = 8.0;
    var itemWidth = 44.0;
    for (final filter in _OtherCardFilter.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: context.tr(filter.label),
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width + 16;
      if (width > itemWidth) itemWidth = width;
      painter.dispose();
    }
    final minimumWidth =
        itemWidth * _OtherCardFilter.values.length +
        gap * (_OtherCardFilter.values.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('market-other-filters'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minimumWidth > constraints.maxWidth
              ? minimumWidth
              : constraints.maxWidth,
          child: AnimatedPillSegment<_OtherCardFilter>(
            height: 30,
            gap: gap,
            fontSize: fontSize,
            items: [
              for (final filter in _OtherCardFilter.values)
                GlassSegmentItem(
                  value: filter,
                  label: filter.label,
                  key: Key('market-other-filter-${filter.name}'),
                ),
            ],
            selected: selected,
            onChanged: onSelected,
          ),
        ),
      ),
    );
  }
}

class _GlobalAccountFilterPanel extends StatelessWidget {
  const _GlobalAccountFilterPanel({
    required this.accounts,
    required this.selectedType,
    required this.selectedKyc,
    required this.selectedCapability,
    required this.onTypeSelected,
    required this.onKycSelected,
    required this.onCapabilitySelected,
  });

  final List<CardSummary> accounts;
  final _GlobalAccountTypeFilter selectedType;
  final _GlobalAccountKycFilter selectedKyc;
  final _GlobalAccountCapabilityFilter selectedCapability;
  final ValueChanged<_GlobalAccountTypeFilter> onTypeSelected;
  final ValueChanged<_GlobalAccountKycFilter> onKycSelected;
  final ValueChanged<_GlobalAccountCapabilityFilter> onCapabilitySelected;

  static const _typeLabels = <_GlobalAccountTypeFilter, String>{
    _GlobalAccountTypeFilter.all: '全部类型',
    _GlobalAccountTypeFilter.traditional: '传统账户',
    _GlobalAccountTypeFilter.cryptoRelated: '加密相关',
  };
  static const _kycLabels = <_GlobalAccountKycFilter, String>{
    _GlobalAccountKycFilter.all: '全部资格',
    _GlobalAccountKycFilter.available: '已确认可申请',
    _GlobalAccountKycFilter.conditional: '条件待确认',
    _GlobalAccountKycFilter.unavailable: '大陆不可用',
    _GlobalAccountKycFilter.unknown: '资格未确认',
  };
  static const _capabilityLabels = <_GlobalAccountCapabilityFilter, String>{
    _GlobalAccountCapabilityFilter.all: '全部能力',
    _GlobalAccountCapabilityFilter.usd: '支持 USD',
    _GlobalAccountCapabilityFilter.cryptoDeposit: '支持链上转入',
    _GlobalAccountCapabilityFilter.bankTransfer: '支持银行转入',
  };

  bool _matchesType(CardSummary card, _GlobalAccountTypeFilter filter) =>
      switch (filter) {
        _GlobalAccountTypeFilter.all => true,
        _GlobalAccountTypeFilter.traditional => !card.isCryptoRelated,
        _GlobalAccountTypeFilter.cryptoRelated => card.isCryptoRelated,
      };

  bool _matchesKyc(
    CardSummary card,
    _GlobalAccountKycFilter filter,
  ) => switch (filter) {
    _GlobalAccountKycFilter.all => true,
    _GlobalAccountKycFilter.available => card.chinaKycStatus == 'available',
    _GlobalAccountKycFilter.conditional => card.chinaKycStatus == 'conditional',
    _GlobalAccountKycFilter.unavailable => card.chinaKycStatus == 'unavailable',
    _GlobalAccountKycFilter.unknown => card.chinaKycStatus == 'unknown',
  };

  bool _matchesCapability(
    CardSummary card,
    _GlobalAccountCapabilityFilter filter,
  ) => switch (filter) {
    _GlobalAccountCapabilityFilter.all => true,
    _GlobalAccountCapabilityFilter.usd => card.transferCurrencies.contains(
      'USD',
    ),
    _GlobalAccountCapabilityFilter.cryptoDeposit =>
      card.receivingMethods.contains('crypto'),
    _GlobalAccountCapabilityFilter.bankTransfer => card.receivingMethods.any(
      const {'ach', 'local', 'sepa', 'swift', 'wire'}.contains,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('筛选全球账户'),
      child: Row(
        key: const Key('global-account-filter-panel'),
        children: [
          Expanded(
            child: _CompactGlobalAccountDropdown<_GlobalAccountTypeFilter>(
              key: const Key('global-account-type-filter'),
              selected: selectedType,
              values: _GlobalAccountTypeFilter.values,
              labels: _typeLabels,
              count: (filter) =>
                  accounts.where((card) => _matchesType(card, filter)).length,
              onChanged: onTypeSelected,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _CompactGlobalAccountDropdown<_GlobalAccountKycFilter>(
              key: const Key('global-account-kyc-filter'),
              selected: selectedKyc,
              values: _GlobalAccountKycFilter.values,
              labels: _kycLabels,
              count: (filter) =>
                  accounts.where((card) => _matchesKyc(card, filter)).length,
              onChanged: onKycSelected,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child:
                _CompactGlobalAccountDropdown<_GlobalAccountCapabilityFilter>(
                  key: const Key('global-account-capability-filter'),
                  selected: selectedCapability,
                  values: _GlobalAccountCapabilityFilter.values,
                  labels: _capabilityLabels,
                  count: (filter) => accounts
                      .where((card) => _matchesCapability(card, filter))
                      .length,
                  onChanged: onCapabilitySelected,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompactGlobalAccountDropdown<T> extends StatelessWidget {
  const _CompactGlobalAccountDropdown({
    required this.selected,
    required this.values,
    required this.labels,
    required this.count,
    required this.onChanged,
    super.key,
  });

  final T selected;
  final List<T> values;
  final Map<T, String> labels;
  final int Function(T value) count;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0x786A758F)
            : const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.isDark
              ? const Color(0x66E6EDFF)
              : AppColors.line.withValues(alpha: .8),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          dropdownColor: AppColors.isDark
              ? const Color(0xFF30384C)
              : const Color(0xFFF9FBFF),
          borderRadius: BorderRadius.circular(14),
          style: TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
          selectedItemBuilder: (context) => [
            for (final value in values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  labels[value]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          items: [
            for (final value in values)
              DropdownMenuItem(
                value: value,
                child: Text('${labels[value]!} (${count(value)})'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketSkeleton extends StatelessWidget {
  const _MarketSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          4,
          (index) => Container(
            height: 88,
            margin: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketMessage extends StatelessWidget {
  const _MarketMessage({
    required this.title,
    required this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
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
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.cyan, size: 28),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
