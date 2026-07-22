import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/localization/app_localizations.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/catalog/widgets/global_account_catalog_card.dart';
import 'package:card_app/features/pro/widgets/pro_crown_badge.dart';
import 'package:card_app/features/shell/widgets/animated_glass_segment.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

enum _MarketGroup { uCard, globalAccount, other }

enum _UCardFilter { all, newest, idCard, passport }

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
  _MarketGroup _group = _MarketGroup.uCard;
  _UCardFilter _filter = _UCardFilter.all;
  List<CardSummary>? _cards;
  Object? _error;
  int _contentDirection = 1;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

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
      return cards.where((card) => card.isGlobalAccount).toList();
    }
    if (_group == _MarketGroup.other) {
      return cards
          .where((card) => !card.category.isUCard && !card.isGlobalAccount)
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: Colors.transparent,
      child: AppPullToRefresh(
        onRefresh: () => _loadCards(force: true, rethrowOnError: true),
        child: CustomScrollView(
          key: const Key('market-page'),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 1),
              sliver: SliverToBoxAdapter(
                child: _MainSegment(
                  selected: _group,
                  // H5 在目录接口不可用时不显示 0，避免把“未知”误报成空统计。
                  uCardCount: _cards
                      ?.where((card) => card.category.isUCard)
                      .length,
                  globalAccountCount: _cards
                      ?.where((card) => card.isGlobalAccount)
                      .length,
                  otherCount: _cards
                      ?.where(
                        (card) =>
                            !card.category.isUCard && !card.isGlobalAccount,
                      )
                      .length,
                  onSelected: _selectGroup,
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
              padding: EdgeInsets.fromLTRB(
                24,
                _group == _MarketGroup.uCard ? 1 : 12,
                24,
                132 + bottomInset,
              ),
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
      key: ValueKey('${_group.name}-${_filter.name}'),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '市场',
                key: Key('market-title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 5),
              Text(
                '探索市面上热门的卡片',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        if (onCompare != null) ...[
          _MarketHeaderAction(
            key: const Key('market-compare-button'),
            icon: Icons.compare_arrows_rounded,
            semanticLabel: context.tr('卡片对比，Pro 会员功能'),
            onTap: onCompare!,
            showProBadge: true,
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenAiAdvisor != null) ...[
          _MarketHeaderAction(
            key: const Key('market-ai-advisor-button'),
            icon: Icons.auto_awesome_rounded,
            semanticLabel: context.tr('AI 选卡'),
            onTap: onOpenAiAdvisor!,
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenCanvas != null) ...[
          _MarketHeaderAction(
            key: const Key('market-canvas-button'),
            icon: Icons.scatter_plot_rounded,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.glassStrong,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, color: AppColors.text, size: 22)),
                if (showProBadge)
                  const Positioned(right: -4, top: -4, child: ProCrownBadge()),
              ],
            ),
          ),
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
