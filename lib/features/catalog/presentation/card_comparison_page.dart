import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/pro/widgets/pro_crown_badge.dart';
import 'package:cardfi/features/pro/data/pro_workspace_controller.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

typedef ComparisonDetailLoader = Future<CardDetail> Function(CardSummary card);

String comparisonCashback(CardSummary card) {
  final value = card.cashbackRate.trim();
  return value.isEmpty ? '未提供' : value;
}

String comparisonTier(CardDetail detail) {
  return detail.tags.firstWhere(
    (tag) => tag.trim().startsWith('评级：'),
    orElse: () => '未提供',
  );
}

List<String> orderedComparisonFeeLabels(Iterable<CardDetail> details) {
  final labels = <String>{
    for (final detail in details)
      for (final fee in detail.fees) fee.label,
  }.toList();
  const priorities = <String>['开卡费', '年费', '月费', '外汇费', '取现手续费'];
  int rank(String label) {
    final index = priorities.indexOf(label);
    return index < 0 ? priorities.length : index;
  }

  labels.sort((left, right) {
    final rankComparison = rank(left).compareTo(rank(right));
    return rankComparison != 0 ? rankComparison : left.compareTo(right);
  });
  return labels;
}

class CardComparisonPage extends StatefulWidget {
  const CardComparisonPage({
    required this.cards,
    required this.loadDetail,
    required this.onBack,
    this.initialCard,
    this.initialCards,
    this.workspaceController,
    this.maxCards = 2,
    super.key,
  });

  final List<CardSummary> cards;
  final CardSummary? initialCard;
  final List<CardSummary>? initialCards;
  final ProWorkspaceController? workspaceController;
  final int maxCards;
  final ComparisonDetailLoader loadDetail;
  final VoidCallback onBack;

  @override
  State<CardComparisonPage> createState() => _CardComparisonPageState();
}

class _CardComparisonPageState extends State<CardComparisonPage> {
  final List<CardSummary> _selectedCards = [];
  Future<List<CardDetail>>? _details;

  @override
  void initState() {
    super.initState();
    _selectInitialCards();
  }

  @override
  void didUpdateWidget(covariant CardComparisonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards != widget.cards ||
        oldWidget.initialCard?.id != widget.initialCard?.id ||
        oldWidget.initialCards?.map((card) => card.id).join('|') !=
            widget.initialCards?.map((card) => card.id).join('|')) {
      _selectInitialCards();
    }
  }

  void _selectInitialCards() {
    final cards = widget.cards;
    if (cards.isEmpty) {
      _selectedCards.clear();
      _details = null;
      return;
    }
    final byId = {for (final card in cards) card.id: card};
    final requestedCards = <CardSummary>[
      ...?widget.initialCards,
      if (widget.initialCard != null) widget.initialCard!,
    ];
    final selectedIds = <String>{};
    _selectedCards
      ..clear()
      ..addAll(
        requestedCards
            .map((card) => byId[card.id] ?? card)
            .where((card) => selectedIds.add(card.id))
            .take(widget.maxCards),
      );
    if (_selectedCards.isEmpty) _selectedCards.add(cards.first);
    if (_selectedCards.length < 2) {
      final second = cards
          .where((card) => !_selectedCards.any((item) => item.id == card.id))
          .firstOrNull;
      if (second != null) _selectedCards.add(second);
    }
    _loadDetails();
  }

  void _loadDetails() {
    _details = _selectedCards.length < 2
        ? null
        : Future.wait(_selectedCards.map(widget.loadDetail));
  }

  Future<void> _chooseCard({int? index}) async {
    final current = index == null ? null : _selectedCards[index];
    final excludedIds = _selectedCards
        .where((card) => card.id != current?.id)
        .map((card) => card.id)
        .toSet();
    final selected = await showAppDraggableSheet<CardSummary>(
      context: context,
      initialSize: .84,
      minSize: .48,
      maxSize: .94,
      barrierAlpha: .42,
      builder: (context, scrollController) => _CardPickerSheet(
        cards: widget.cards,
        selectedId: current?.id,
        excludedIds: excludedIds,
        scrollController: scrollController,
      ),
    );
    if (!mounted || selected == null || selected.id == current?.id) return;
    AppHaptics.selection();
    setState(() {
      if (index == null) {
        _selectedCards.add(selected);
      } else {
        _selectedCards[index] = selected;
      }
      _loadDetails();
    });
  }

  void _swapCards() {
    if (_selectedCards.length < 2) return;
    AppHaptics.selection();
    setState(() {
      final first = _selectedCards[0];
      _selectedCards[0] = _selectedCards[1];
      _selectedCards[1] = first;
      _loadDetails();
    });
  }

  void _removeCard(int index) {
    if (_selectedCards.length <= 2) return;
    AppHaptics.selection();
    setState(() {
      _selectedCards.removeAt(index);
      _loadDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('card-comparison-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, bottomInset + 40),
          children: [
            Text(
              widget.maxCards > 2
                  ? 'Pro 可同时选择 2–4 张卡片，差异项会被轻量标记。申请前仍请以官方最新规则为准。'
                  : '普通版支持同时对比 2 张卡片。申请前仍请以官方最新规则为准。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _CardSelectionPanel(
              cards: _selectedCards,
              maxCards: widget.maxCards,
              onChoose: (index) => _chooseCard(index: index),
              onAdd: () => _chooseCard(),
              onRemove: _removeCard,
              onSwap: _swapCards,
            ),
            const SizedBox(height: 16),
            _buildComparison(),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            height: 76,
            child: Row(
              children: [
                IconButton(
                  key: const Key('comparison-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(AppIcons.back, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: AppColors.text,
                    backgroundColor: AppColors.glassStrong,
                    side: BorderSide(color: AppColors.line),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '卡片对比',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
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
  }

  Widget _buildComparison() {
    if (_selectedCards.length < 2 || _details == null) {
      return _ComparisonMessage(
        icon: AppIcons.compare,
        title: '至少需要两张卡片',
        description: '当前目录中的卡片不足，暂时无法生成对比。',
      );
    }
    return FutureBuilder<List<CardDetail>>(
      key: ValueKey(_selectedCards.map((card) => card.id).join('-')),
      future: _details,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ComparisonLoading();
        }
        if (snapshot.hasError ||
            snapshot.data?.length != _selectedCards.length) {
          return _ComparisonMessage(
            icon: AppIcons.cloudUnavailable,
            title: '对比信息加载失败',
            description: '请检查网络后重试，本地已有资料仍可在详情页查看。',
            actionLabel: '重新加载',
            onAction: () => setState(_loadDetails),
          );
        }
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          child: _ComparisonResults(
            key: ValueKey(_selectedCards.map((card) => card.id).join(':')),
            cards: List.unmodifiable(_selectedCards),
            details: snapshot.data!,
            onSave: widget.workspaceController == null
                ? null
                : () async {
                    await widget.workspaceController!.saveComparison(
                      _selectedCards,
                    );
                    if (context.mounted) {
                      AppNotice.success(
                        context,
                        '这组卡片已保存，可在 Pro 工作区再次打开。',
                        title: '方案已保存',
                      );
                    }
                  },
          ),
        );
      },
    );
  }
}

class _CardSelectionPanel extends StatelessWidget {
  const _CardSelectionPanel({
    required this.cards,
    required this.maxCards,
    required this.onChoose,
    required this.onAdd,
    required this.onRemove,
    required this.onSwap,
  });

  final List<CardSummary> cards;
  final int maxCards;
  final ValueChanged<int> onChoose;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark
                ? const Color(0x24000000)
                : const Color(0x1763729F),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '已选 ${cards.length}/$maxCards',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (cards.length < maxCards)
                TextButton.icon(
                  key: const Key('comparison-add-card'),
                  onPressed: onAdd,
                  icon: const Icon(AppIcons.add, size: 18),
                  label: const Text('添加卡片'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(108, 44),
                    foregroundColor: AppColors.cyan,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: 132,
                child: _CardSlot(
                  key: Key(
                    index == 0
                        ? 'comparison-left-card'
                        : index == 1
                        ? 'comparison-right-card'
                        : 'comparison-card-${cards[index].id}',
                  ),
                  card: cards[index],
                  onTap: () => onChoose(index),
                  onRemove: cards.length > 2 ? () => onRemove(index) : null,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const Key('comparison-swap'),
              onPressed: cards.length < 2 ? null : onSwap,
              icon: const Icon(AppIcons.swap, size: 19),
              label: const Text('交换前两张'),
              style: TextButton.styleFrom(
                minimumSize: const Size(132, 44),
                foregroundColor: AppColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSlot extends StatelessWidget {
  const _CardSlot({
    required this.card,
    required this.onTap,
    this.onRemove,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: Semantics(
        button: true,
        label: '更换 ${card.name}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.58,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CardArtwork(
                            card: card,
                            showGeneratedLabels: false,
                          ),
                        ),
                      ),
                      if (onRemove != null)
                        Positioned(
                          right: -6,
                          top: -7,
                          child: IconButton(
                            key: Key('comparison-remove-${card.id}'),
                            onPressed: onRemove,
                            tooltip: '移除 ${card.name}',
                            icon: const Icon(AppIcons.close, size: 16),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              maximumSize: const Size(32, 32),
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.text,
                              backgroundColor: AppColors.glassStrong,
                              side: BorderSide(color: AppColors.line),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '点击更换',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonResults extends StatelessWidget {
  const _ComparisonResults({
    required this.cards,
    required this.details,
    required this.onSave,
    super.key,
  });

  final List<CardSummary> cards;
  final List<CardDetail> details;
  final Future<void> Function()? onSave;

  String _network(CardSummary card) => switch (card.network) {
    CardNetwork.visa => 'Visa',
    CardNetwork.mastercard => 'Mastercard',
    CardNetwork.other => card.label,
  };

  String _channels(CardDetail detail) => detail.paymentChannels.isEmpty
      ? '未提供'
      : detail.paymentChannels.map((channel) => channel.label).join('、');

  String _features(CardDetail detail) => detail.features.isEmpty
      ? '未提供'
      : detail.features.map((feature) => '• ${feature.text}').join('\n');

  String _tags(CardDetail detail) =>
      detail.tags.isEmpty ? '未提供' : detail.tags.join('、');

  @override
  Widget build(BuildContext context) {
    final feeMaps = [
      for (final detail in details)
        {for (final fee in detail.fees) fee.label: fee.value},
    ];
    final feeLabels = orderedComparisonFeeLabels(details);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumWidth = cards.length * 142.0;
        final tableWidth = constraints.maxWidth > minimumWidth
            ? constraints.maxWidth
            : minimumWidth;
        return SingleChildScrollView(
          key: const Key('comparison-results-scroll'),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ComparisonActions(
                  cards: cards,
                  details: details,
                  onSave: onSave,
                ),
                const SizedBox(height: 14),
                _ComparisonSection(
                  title: '基础信息',
                  cards: cards,
                  children: [
                    _ComparisonRow(
                      label: '卡片类型',
                      values: cards.map((card) => card.category.label).toList(),
                    ),
                    _ComparisonRow(
                      label: '卡组织',
                      values: cards.map(_network).toList(),
                    ),
                    _ComparisonRow(
                      label: '返现概览',
                      values: cards.map(comparisonCashback).toList(),
                    ),
                    _ComparisonRow(
                      label: '评级',
                      values: details.map(comparisonTier).toList(),
                    ),
                    _ComparisonRow(
                      label: '适用地区',
                      values: details.map((detail) => detail.region).toList(),
                    ),
                    _ComparisonRow(
                      label: '入金方式',
                      values: details.map((detail) => detail.funding).toList(),
                    ),
                    _ComparisonRow(
                      label: '开放状态',
                      values: details
                          .map((detail) => detail.availability)
                          .toList(),
                    ),
                    _ComparisonRow(
                      label: '标签',
                      values: details.map(_tags).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ComparisonSection(
                  title: '申请与使用',
                  cards: cards,
                  children: [
                    _ComparisonRow(
                      label: 'KYC 要求',
                      values: details.map((detail) => detail.kycNote).toList(),
                    ),
                    _ComparisonRow(
                      label: '支付渠道',
                      values: details.map(_channels).toList(),
                    ),
                    _ComparisonRow(
                      label: '主要特点',
                      values: details.map(_features).toList(),
                    ),
                  ],
                ),
                if (feeLabels.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ComparisonSection(
                    title: '费用对比',
                    cards: cards,
                    children: [
                      for (final label in feeLabels)
                        _ComparisonRow(
                          label: label,
                          values: feeMaps
                              .map((fees) => fees[label] ?? '未提供')
                              .toList(),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _FeeScenarioEstimator(cards: cards, details: details),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    '资料来源：${details.map((detail) => detail.sourceLabel).toSet().join(' / ')}\n卡片规则、费用和开放地区可能变化，本对比不构成申请或金融建议。',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonActions extends StatelessWidget {
  const _ComparisonActions({
    required this.cards,
    required this.details,
    required this.onSave,
  });

  final List<CardSummary> cards;
  final List<CardDetail> details;
  final Future<void> Function()? onSave;

  String _escape(String value) => '"${value.replaceAll('"', '""')}"';

  String _csv() {
    final rows = <List<String>>[
      ['字段', ...cards.map((card) => card.name)],
      ['发行方', ...cards.map((card) => card.issuer)],
      ['卡片类型', ...cards.map((card) => card.category.label)],
      ['返现概览', ...cards.map(comparisonCashback)],
      ['评级', ...details.map(comparisonTier)],
      ['适用地区', ...details.map((detail) => detail.region)],
      ['入金方式', ...details.map((detail) => detail.funding)],
      ['开放状态', ...details.map((detail) => detail.availability)],
      ['KYC 要求', ...details.map((detail) => detail.kycNote)],
      [
        '支付渠道',
        ...details.map(
          (detail) => detail.paymentChannels.isEmpty
              ? '未提供'
              : detail.paymentChannels.map((item) => item.label).join('、'),
        ),
      ],
      [
        '主要特点',
        ...details.map(
          (detail) => detail.features.isEmpty
              ? '未提供'
              : detail.features.map((feature) => feature.text).join('；'),
        ),
      ],
    ];
    final feeLabels = orderedComparisonFeeLabels(details);
    for (final label in feeLabels) {
      rows.add([
        label,
        for (final detail in details)
          detail.fees.where((fee) => fee.label == label).firstOrNull?.value ??
              '未提供',
      ]);
    }
    rows.add(['资料来源', ...details.map((detail) => detail.sourceLabel)]);
    return '\uFEFF${rows.map((row) => row.map(_escape).join(',')).join('\n')}';
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _csv()));
    if (context.mounted) {
      AppNotice.success(context, 'CSV 报告已复制，可粘贴到表格或文件中保存。', title: '导出完成');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('comparison-save-preset'),
              onPressed: onSave,
              icon: const Icon(AppIcons.bookmarkAdd, size: 18),
              label: const Text('保存方案'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('comparison-export-csv'),
              onPressed: () => _copy(context),
              icon: const Icon(AppIcons.export, size: 18),
              label: const Text('导出 CSV'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeScenarioEstimator extends StatefulWidget {
  const _FeeScenarioEstimator({required this.cards, required this.details});

  final List<CardSummary> cards;
  final List<CardDetail> details;

  @override
  State<_FeeScenarioEstimator> createState() => _FeeScenarioEstimatorState();
}

class _FeeScenarioEstimatorState extends State<_FeeScenarioEstimator> {
  double _monthlySpend = 1000;
  double _crossBorderRatio = .2;
  double _atmUses = 0;
  double _years = 1;

  _FeeEstimate _estimate(CardDetail detail) {
    var total = 0.0;
    var known = 0;
    final notes = <String>[];
    for (final fee in detail.fees) {
      final label = fee.label.toLowerCase();
      final value = fee.value.trim().toLowerCase();
      if (value.contains('免费') ||
          value.contains('免年费') ||
          value.contains('free') ||
          value.contains('no annual fee') ||
          value.contains('no fee')) {
        known++;
        continue;
      }
      final number = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
      if (number == null) continue;
      final amount = double.tryParse(number.group(1)!) ?? 0;
      if (label.contains('返现') || label.contains('奖励')) continue;
      if (label.contains('年费')) {
        total += amount * _years;
        known++;
      } else if (label.contains('开卡')) {
        total += amount;
        known++;
      } else if (label.contains('外汇') || label.contains('跨境')) {
        if (value.contains('%')) {
          total +=
              _monthlySpend * 12 * _years * _crossBorderRatio * amount / 100;
          known++;
        }
      } else if (label.contains('atm') || label.contains('取现')) {
        total += amount * _atmUses * 12 * _years;
        known++;
      }
    }
    if (known < detail.fees.length) notes.add('存在未结构化费用，未计入');
    return _FeeEstimate(
      total: total,
      known: known,
      totalLines: detail.fees.length,
      note: notes.join('；'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('comparison-fee-estimator'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '费用场景测算',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const ProCrownBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '仅计算资料中能够明确识别的数字费用；币种沿用原始资料，不参与汇率换算。',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          _ScenarioSlider(
            label: '每月消费',
            valueLabel: _monthlySpend == 0
                ? '不计'
                : _monthlySpend.toStringAsFixed(0),
            value: _monthlySpend,
            min: 0,
            max: 10000,
            divisions: 20,
            onChanged: (value) => setState(() => _monthlySpend = value),
          ),
          _ScenarioSlider(
            label: '跨境消费比例',
            valueLabel: '${(_crossBorderRatio * 100).round()}%',
            value: _crossBorderRatio,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: (value) => setState(() => _crossBorderRatio = value),
          ),
          _ScenarioSlider(
            label: '每月 ATM 次数',
            valueLabel: '${_atmUses.round()} 次',
            value: _atmUses,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (value) => setState(() => _atmUses = value),
          ),
          _ScenarioSlider(
            label: '持有时间',
            valueLabel: '${_years.round()} 年',
            value: _years,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (value) => setState(() => _years = value),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < widget.cards.length; index++) ...[
            Builder(
              builder: (context) {
                final estimate = _estimate(widget.details[index]);
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == widget.cards.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glassStrong,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.cards[index].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              estimate.note.isEmpty
                                  ? '已覆盖 ${estimate.known}/${estimate.totalLines} 项费用'
                                  : '${estimate.note} · 覆盖 ${estimate.known}/${estimate.totalLines}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        estimate.known == 0
                            ? '资料不足'
                            : '约 ${estimate.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: estimate.known == 0
                              ? AppColors.textMuted
                              : AppColors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ScenarioSlider extends StatelessWidget {
  const _ScenarioSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FeeEstimate {
  const _FeeEstimate({
    required this.total,
    required this.known,
    required this.totalLines,
    required this.note,
  });

  final double total;
  final int known;
  final int totalLines;
  final String note;
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.title,
    required this.cards,
    required this.children,
  });

  final String title;
  final List<CardSummary> cards;
  final List<Widget> children;

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
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
            child: Row(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index != 0) const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      cards[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final normalized = values
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final different = normalized.length > 1;
    return Container(
      key: Key('comparison-row-$label'),
      decoration: BoxDecoration(
        color: different
            ? AppColors.violet.withValues(alpha: AppColors.isDark ? .075 : .045)
            : Colors.transparent,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (different)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '有差异',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < values.length; index++) ...[
                if (index != 0)
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    color: AppColors.line,
                  ),
                Expanded(child: _ComparisonValue(value: values[index])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 11.5,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ComparisonLoading extends StatelessWidget {
  const _ComparisonLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('comparison-loading'),
      children: List.generate(
        3,
        (index) => Container(
          height: index == 0 ? 190 : 150,
          margin: const EdgeInsets.only(bottom: 14),
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

class _ComparisonMessage extends StatelessWidget {
  const _ComparisonMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.cyan, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _CardPickerSheet extends StatefulWidget {
  const _CardPickerSheet({
    required this.cards,
    required this.selectedId,
    required this.excludedIds,
    required this.scrollController,
  });

  final List<CardSummary> cards;
  final String? selectedId;
  final Set<String> excludedIds;
  final ScrollController scrollController;

  @override
  State<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends State<_CardPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cards = widget.cards
        .where(
          (card) =>
              !widget.excludedIds.contains(card.id) && card.matches(_query),
        )
        .toList(growable: false);
    return Container(
      key: const Key('comparison-card-picker'),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 8 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xF51C2030)
            : const Color(0xFAF8FAFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
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
              Expanded(
                child: Text(
                  '选择对比卡片',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('comparison-picker-search'),
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索卡片或发行方',
              prefixIcon: const Icon(AppIcons.search),
              filled: true,
              fillColor: AppColors.glassStrong,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      '没有匹配的卡片',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Stack(
                        children: [
                          CatalogCardRow(
                            card: card,
                            onTap: () => Navigator.pop(context, card),
                          ),
                          if (card.id == widget.selectedId)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: IgnorePointer(
                                child: Icon(
                                  AppIcons.checkCircle,
                                  color: AppColors.mint,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
