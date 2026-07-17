import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:flutter/material.dart';

enum _MarketGroup { uCard, other }

enum _UCardFilter { all, newest, idCard, passport }

class MarketPage extends StatefulWidget {
  const MarketPage({
    required this.repository,
    required this.onSearch,
    required this.onOpenCard,
    super.key,
  });

  final CardCatalogRepository repository;
  final VoidCallback onSearch;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  _MarketGroup _group = _MarketGroup.uCard;
  _UCardFilter _filter = _UCardFilter.all;
  List<CardSummary>? _cards;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards({bool force = false}) async {
    setState(() => _error = null);
    try {
      final cards = await widget.repository.loadCards(force: force);
      if (!mounted) return;
      setState(() => _cards = cards);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  List<CardSummary> get _filteredCards {
    final cards = _cards ?? const <CardSummary>[];
    if (_group == _MarketGroup.other) {
      return cards.where((card) => !card.category.isUCard).toList();
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
    return Material(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: () => _loadCards(force: true),
        color: AppColors.violet,
        backgroundColor: AppColors.glassStrong,
        child: ListView(
          key: Key('market-page'),
          physics: AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(24, 18, 24, 132 + bottomInset),
          children: [
            _MarketHeader(onSearch: widget.onSearch),
            SizedBox(height: 14),
            _MainSegment(
              selected: _group,
              // H5 在目录接口不可用时不显示 0，避免把“未知”误报成空统计。
              uCardCount: _cards?.where((card) => card.category.isUCard).length,
              otherCount: _cards
                  ?.where((card) => !card.category.isUCard)
                  .length,
              onSelected: (group) => setState(() {
                _group = group;
                if (group == _MarketGroup.other) {
                  _filter = _UCardFilter.all;
                }
              }),
            ),
            if (_group == _MarketGroup.uCard) ...[
              SizedBox(height: 12),
              _SubSegment(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
            ],
            SizedBox(height: 18),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 220),
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
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
          CatalogCardRow(
            card: cards[index],
            onTap: () => widget.onOpenCard(cards[index]),
          ),
          if (index != cards.length - 1) SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({required this.onSearch});

  final VoidCallback onSearch;

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
              SizedBox(height: 8),
              Text('探索市面上热门的卡片', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        SizedBox(width: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('market-search-button'),
            onTap: onSearch,
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
                color: AppColors.text,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainSegment extends StatelessWidget {
  const _MainSegment({
    required this.selected,
    required this.uCardCount,
    required this.otherCount,
    required this.onSelected,
  });

  final _MarketGroup selected;
  final int? uCardCount;
  final int? otherCount;
  final ValueChanged<_MarketGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _SegmentButton(
            key: Key('market-group-ucard'),
            label: 'U卡${uCardCount == null ? '' : ' ($uCardCount)'}',
            selected: selected == _MarketGroup.uCard,
            onTap: () => onSelected(_MarketGroup.uCard),
          ),
          _SegmentButton(
            key: Key('market-group-other'),
            label: '其他${otherCount == null ? '' : ' ($otherCount)'}',
            selected: selected == _MarketGroup.other,
            onTap: () => onSelected(_MarketGroup.other),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Duration(milliseconds: 220),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [Color(0x706B78FF), Color(0x5053D8FF)])
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
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
    return Row(
      children: [
        for (final filter in _UCardFilter.values) ...[
          Expanded(
            child: InkWell(
              key: Key('market-filter-${filter.name}'),
              onTap: () => onSelected(filter),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected == filter
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: AppColors.isDark
                              ? const [Color(0x4D99A0E8), Color(0x6B6069B2)]
                              : const [Color(0xFFFFFFFF), Color(0xF2FFFFFF)],
                        )
                      : null,
                  color: selected == filter
                      ? null
                      : AppColors.isDark
                      ? const Color(0x24FFFFFF)
                      : const Color(0x94FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected == filter
                        ? AppColors.cyan.withValues(alpha: .24)
                        : AppColors.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.isDark
                          ? const Color(0x24000000)
                          : const Color(0x146E82AE),
                      blurRadius: selected == filter ? 18 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  _labels[filter]!,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected == filter
                        ? AppColors.cyan
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: selected == filter
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (filter != _UCardFilter.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MarketSkeleton extends StatelessWidget {
  const _MarketSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          height: 88,
          margin: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
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
