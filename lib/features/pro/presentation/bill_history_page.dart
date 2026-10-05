import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/searchable_card_picker.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/data/bill_history_repository.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/domain/bill_cny_rates.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

Future<BillRecord?> openBillRecordEditorPage({
  required BuildContext context,
  required BillHistoryRepository repository,
  required BillRecord record,
  required List<CardSummary> cards,
  BillBenchmarkRepository? benchmarkRepository,
}) async {
  final result = await Navigator.of(context).push<_BillEditResult>(
    MaterialPageRoute(
      builder: (routeContext) => Scaffold(
        backgroundColor: AppColors.canvas,
        body: _BillRecordEditor(
          repository: repository,
          benchmarkRepository: benchmarkRepository,
          record: record,
          cards: cards,
          pageMode: true,
        ),
      ),
    ),
  );
  return result?.record;
}

class BillHistoryPage extends StatefulWidget {
  const BillHistoryPage({
    required this.repository,
    required this.cards,
    required this.onBack,
    this.benchmarkRepository,
    super.key,
  });

  final BillHistoryRepository repository;
  final BillBenchmarkRepository? benchmarkRepository;
  final List<CardSummary> cards;
  final VoidCallback onBack;

  @override
  State<BillHistoryPage> createState() => _BillHistoryPageState();
}

enum _BillHistoryViewMode { monthly, regular }

class _BillHistoryPageState extends State<BillHistoryPage> {
  List<BillRecord> _records = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  String? _expandedMonth;
  String? _error;
  _BillHistoryViewMode _viewMode = _BillHistoryViewMode.monthly;
  late final ScrollController _scrollController;
  final Map<String, BillBenchmarkQuote> _referenceQuotes = {};
  final Set<String> _loadingReferenceQuotes = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    unawaited(_loadMore());
  }

  void _scheduleAutomaticLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.extentAfter <= 280) {
        unawaited(_loadMore());
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.list(limit: 20);
      final records = _sortedRecords(page.records);
      if (mounted) {
        setState(() {
          _records = records;
          _nextCursor = page.nextCursor;
          final months = _groupRecordsByMonth(records);
          _expandedMonth = months.isEmpty ? null : months.first.key;
        });
        _primeReferenceQuotes(records);
        _scheduleAutomaticLoadMore();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '历史账单加载失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    var loaded = false;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.list(cursor: cursor, limit: 30);
      if (!mounted) return;
      setState(() {
        final byId = <String, BillRecord>{
          for (final record in _records) record.id: record,
          for (final record in page.records) record.id: record,
        };
        _records = _sortedRecords(byId.values);
        _nextCursor = page.nextCursor == cursor ? null : page.nextCursor;
      });
      _primeReferenceQuotes(page.records);
      loaded = true;
    } on ApiException catch (error) {
      if (mounted) AppNotice.error(context, error.message, title: '加载失败');
    } catch (_) {
      if (mounted) AppNotice.error(context, '更多账单加载失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        if (loaded) _scheduleAutomaticLoadMore();
      }
    }
  }

  void _toggleViewMode() {
    AppHaptics.selection();
    setState(() {
      _viewMode = _viewMode == _BillHistoryViewMode.monthly
          ? _BillHistoryViewMode.regular
          : _BillHistoryViewMode.monthly;
    });
    _scheduleAutomaticLoadMore();
  }

  void _primeReferenceQuotes(Iterable<BillRecord> records) {
    if (widget.benchmarkRepository == null) return;
    for (final record in records) {
      final original = record.confirmed.original.currency;
      final deduction = record.confirmed.deduction.currency;
      _loadReferenceQuote(original, deduction);
      _loadReferenceQuote(deduction, 'CNY');
    }
  }

  void _loadReferenceQuote(String? from, String? to) {
    final key = _quoteKey(from, to);
    final repository = widget.benchmarkRepository;
    if (key == null ||
        repository == null ||
        _referenceQuotes.containsKey(key) ||
        !_loadingReferenceQuotes.add(key)) {
      return;
    }
    unawaited(() async {
      BillBenchmarkQuote? quote;
      try {
        quote = await repository.loadCurrentPair(from: from, to: to);
      } catch (_) {
        // Realtime references are supplementary; saved bills remain usable.
      }
      if (!mounted) return;
      setState(() {
        _loadingReferenceQuotes.remove(key);
        if (quote != null) _referenceQuotes[key] = quote;
      });
    }());
  }

  BillBenchmarkQuote? _referenceQuote(String? from, String? to) {
    final key = _quoteKey(from, to);
    return key == null ? null : _referenceQuotes[key];
  }

  Future<void> _openDetail(BillRecord record) async {
    AppHaptics.selection();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          backgroundColor: AppColors.canvas,
          body: _BillRecordDetailPage(
            repository: widget.repository,
            benchmarkRepository: widget.benchmarkRepository,
            record: record,
            cards: widget.cards,
            onBack: () => Navigator.of(routeContext).pop(),
            onChanged: (result) {
              if (!mounted) return;
              setState(() {
                if (result.deleted) {
                  _records = _records
                      .where((item) => item.id != record.id)
                      .toList();
                } else if (result.record != null) {
                  _records = _sortedRecords([
                    result.record!,
                    ..._records.where((item) => item.id != record.id),
                  ]);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final monthGroups = _groupRecordsByMonth(_records);
    return Stack(
      key: const Key('bill-history-page'),
      children: [
        RefreshIndicator(
          key: const Key('bill-history-refresh-indicator'),
          onRefresh: _load,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topInset + 70)),
              if (_loading && _records.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(42),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                )
              else if (_error != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _HistoryMessage(message: _error!, onRetry: _load),
                  ),
                )
              else if (_records.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(child: _HistoryEmpty()),
                )
              else if (_viewMode == _BillHistoryViewMode.monthly) ...[
                for (final group in monthGroups)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _BillMonthSection(
                            group: group,
                            expanded: _expandedMonth == group.key,
                            cards: widget.cards,
                            quoteFor: _referenceQuote,
                            onToggle: () => setState(() {
                              _expandedMonth = _expandedMonth == group.key
                                  ? null
                                  : group.key;
                            }),
                            onOpen: _openDetail,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                _BillRegularList(
                  records: _records,
                  cards: widget.cards,
                  quoteFor: _referenceQuote,
                  onOpen: _openDetail,
                ),
              ],
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    key: Key('bill-history-loading-more'),
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomInset + 38)),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            height: 76,
            child: Row(
              children: [
                IconButton(
                  key: const Key('bill-history-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '历史账单',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  key: const Key('bill-history-view-toggle'),
                  onPressed: _records.isEmpty ? null : _toggleViewMode,
                  tooltip: _viewMode == _BillHistoryViewMode.monthly
                      ? '切换为常规列表'
                      : '切换为按月分组',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _viewMode == _BillHistoryViewMode.monthly
                          ? Icons.format_list_bulleted_rounded
                          : Icons.calendar_month_outlined,
                      key: ValueKey(_viewMode),
                      size: 23,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('bill-history-refresh'),
                  onPressed: _loading ? null : _load,
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BillMonthGroup {
  const _BillMonthGroup({
    required this.key,
    required this.label,
    required this.records,
  });

  final String key;
  final String label;
  final List<BillRecord> records;
}

class _BillMonthSection extends StatelessWidget {
  const _BillMonthSection({
    required this.group,
    required this.expanded,
    required this.cards,
    required this.quoteFor,
    required this.onToggle,
    required this.onOpen,
  });

  final _BillMonthGroup group;
  final bool expanded;
  final List<CardSummary> cards;
  final BillBenchmarkQuote? Function(String? from, String? to) quoteFor;
  final VoidCallback onToggle;
  final ValueChanged<BillRecord> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('bill-month-${group.key}'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${group.records.length} 笔',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: expanded
            ? Column(
                children: [
                  for (final record in group.records) ...[
                    _BillRecordCard(
                      record: record,
                      card: _cardFor(record, cards),
                      benchmarkQuote: quoteFor(
                        record.confirmed.original.currency,
                        record.confirmed.deduction.currency,
                      ),
                      cnyQuote: quoteFor(
                        record.confirmed.deduction.currency,
                        'CNY',
                      ),
                      onTap: () => onOpen(record),
                    ),
                    if (record != group.records.last)
                      const SizedBox(height: 10),
                  ],
                ],
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}

List<BillRecord> _sortedRecords(Iterable<BillRecord> records) {
  final result = records.toList(growable: false);
  result.sort((left, right) => _recordDate(right).compareTo(_recordDate(left)));
  return result;
}

List<_BillMonthGroup> _groupRecordsByMonth(List<BillRecord> records) {
  final groups = <String, List<BillRecord>>{};
  for (final record in records) {
    final date = _recordDate(record);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    groups.putIfAbsent(key, () => []).add(record);
  }
  return groups.entries
      .map((entry) {
        final date = _recordDate(entry.value.first);
        return _BillMonthGroup(
          key: entry.key,
          label: '${date.year}年${date.month}月',
          records: entry.value,
        );
      })
      .toList(growable: false);
}

DateTime _recordDate(BillRecord record) =>
    DateTime.tryParse(record.confirmed.transactionAt ?? '') ??
    record.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 46),
    decoration: _decoration(),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 38),
        const SizedBox(height: 12),
        const Text('还没有历史账单', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          '完成一次账单识别后会自动保存为待确认记录。',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _BillRegularList extends StatelessWidget {
  const _BillRegularList({
    required this.records,
    required this.cards,
    required this.quoteFor,
    required this.onOpen,
  });

  final List<BillRecord> records;
  final List<CardSummary> cards;
  final BillBenchmarkQuote? Function(String? from, String? to) quoteFor;
  final ValueChanged<BillRecord> onOpen;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverList(
      key: const Key('bill-history-regular-list'),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) return const SizedBox(height: 12);
          final record = records[index ~/ 2];
          return _BillRegularRow(
            record: record,
            card: _cardFor(record, cards),
            benchmarkQuote: quoteFor(
              record.confirmed.original.currency,
              record.confirmed.deduction.currency,
            ),
            cnyQuote: quoteFor(record.confirmed.deduction.currency, 'CNY'),
            onTap: () => onOpen(record),
          );
        },
        childCount: records.isEmpty ? 0 : records.length * 2 - 1,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
      ),
    ),
  );
}

class _BillRegularRow extends StatelessWidget {
  const _BillRegularRow({
    required this.record,
    required this.card,
    required this.benchmarkQuote,
    required this.cnyQuote,
    required this.onTap,
  });

  final BillRecord record;
  final CardSummary? card;
  final BillBenchmarkQuote? benchmarkQuote;
  final BillBenchmarkQuote? cnyQuote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    final cardLabel = record.cardBinding.isBound
        ? record.cardBinding.cardNameSnapshot ?? '已绑定卡片'
        : data.cardName ?? record.recognized.cardName ?? '未绑定卡片';
    final cashbackCnyRate = cnyQuote == null
        ? '等待人民币参考'
        : record.metrics.cashbackValue == null
        ? '待补录返现'
        : _cashbackAdjustedCnyRateLabel(
            record,
            cnyQuote!,
            benchmarkQuote: benchmarkQuote,
          );
    return Container(
      key: Key('bill-list-card-${record.id}'),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark ? .14 : .05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('bill-list-record-${record.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecordCardThumbnail(card: card, label: cardLabel),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cardLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 118,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    data.deduction.isComplete
                                        ? data.deduction.label
                                        : data.original.label,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                key: Key('bill-list-chevron-${record.id}'),
                                Icons.arrow_forward_ios_rounded,
                                color: AppColors.textMuted,
                                size: 13,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${data.provider ?? '未知平台'} · ${_compactBillDate(record)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _BillRegularMetric(
                        label: '损耗',
                        value: _lossWithRate(
                          record,
                          benchmarkQuote: benchmarkQuote,
                        ),
                        color: AppColors.pink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _BillRegularMetric(
                        label: '净返现',
                        value: _actualCashbackAfterLoss(
                          record,
                          benchmarkQuote: benchmarkQuote,
                        ),
                        color: record.metrics.cashbackValue == null
                            ? AppColors.textMuted
                            : AppColors.mint,
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_yen_rounded,
                        size: 15,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '返现后人民币汇率',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            cashbackCnyRate,
                            maxLines: 1,
                            style: TextStyle(
                              color: cashbackCnyRate.startsWith('1 ')
                                  ? AppColors.mint
                                  : AppColors.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillRegularMetric extends StatelessWidget {
  const _BillRegularMetric({
    required this.label,
    required this.value,
    required this.color,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 8.5)),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _BillRecordCard extends StatelessWidget {
  const _BillRecordCard({
    required this.record,
    required this.card,
    required this.benchmarkQuote,
    required this.cnyQuote,
    required this.onTap,
  });

  final BillRecord record;
  final CardSummary? card;
  final BillBenchmarkQuote? benchmarkQuote;
  final BillBenchmarkQuote? cnyQuote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    final date = _compactBillDate(record);
    final netCashbackCny = _netCashbackCnyLabel(
      record,
      benchmarkQuote: benchmarkQuote,
      cnyQuote: cnyQuote,
    );
    final cardLabel = record.cardBinding.isBound
        ? record.cardBinding.cardNameSnapshot ?? '已绑定卡片'
        : data.cardName ?? record.recognized.cardName ?? '未绑定卡片';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('bill-record-${record.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.glassStrong,
                AppColors.surface.withValues(alpha: .82),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppColors.isDark ? .16 : .055,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordCardThumbnail(card: card, label: cardLabel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cardLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.textMuted,
                              size: 14,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.deduction.isComplete
                              ? data.deduction.label
                              : data.original.label,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [
                            data.provider ?? '未知平台',
                            date,
                            if (netCashbackCny != null) '净返现 $netCashbackCny',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Divider(
                height: 1,
                color: AppColors.textMuted.withValues(alpha: .09),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _RecordMetric(
                      label: '损耗',
                      value: _lossWithRate(
                        record,
                        benchmarkQuote: benchmarkQuote,
                      ),
                      color:
                          _marketLossValue(
                                record,
                                benchmarkQuote: benchmarkQuote,
                              ) ==
                              null
                          ? AppColors.textMuted
                          : AppColors.pink,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: AppColors.textMuted.withValues(alpha: .09),
                  ),
                  Expanded(
                    child: _RecordMetric(
                      label: '净返现',
                      value: _actualCashbackAfterLoss(
                        record,
                        benchmarkQuote: benchmarkQuote,
                      ),
                      color: record.metrics.cashbackValue == null
                          ? AppColors.textMuted
                          : AppColors.mint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordCardThumbnail extends StatelessWidget {
  const _RecordCardThumbnail({required this.card, required this.label});

  final CardSummary? card;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 72,
      height: 45,
      child: card == null
          ? _FallbackCardArtwork(label: label)
          : CardArtwork(
              card: card!,
              memCacheWidth: 220,
              showGeneratedLabels: false,
            ),
    ),
  );
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 8.5)),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );
}

CardSummary? _cardFor(BillRecord record, List<CardSummary> cards) {
  final cardId = record.cardBinding.cardId;
  if (cardId != null) {
    for (final card in cards) {
      if (card.id == cardId) return card;
    }
  }
  final candidates = [
    record.cardBinding.cardNameSnapshot,
    record.confirmed.cardName,
    record.recognized.cardName,
  ].whereType<String>().map(_cardMatchKey).where((value) => value.isNotEmpty);
  for (final candidate in candidates) {
    for (final card in cards) {
      final name = _cardMatchKey(card.name);
      if (name == candidate) return card;
      final brand = candidate.replaceFirst(RegExp(r'card$'), '');
      if (brand.isNotEmpty && _cardMatchKey(card.issuer) == brand) return card;
    }
  }
  return null;
}

String _cardMatchKey(String value) => value.trim().toLowerCase().replaceAll(
  RegExp(r'[^a-z0-9\u4e00-\u9fff]'),
  '',
);

class _FallbackCardArtwork extends StatelessWidget {
  const _FallbackCardArtwork({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF725CF7), Color(0xFF3A67F7)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            Icons.credit_card_rounded,
            color: Colors.white.withValues(alpha: .9),
            size: 15,
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BillRecordDetailPage extends StatefulWidget {
  const _BillRecordDetailPage({
    required this.repository,
    required this.record,
    required this.cards,
    required this.onBack,
    required this.onChanged,
    this.benchmarkRepository,
  });

  final BillHistoryRepository repository;
  final BillBenchmarkRepository? benchmarkRepository;
  final BillRecord record;
  final List<CardSummary> cards;
  final VoidCallback onBack;
  final ValueChanged<_BillEditResult> onChanged;

  @override
  State<_BillRecordDetailPage> createState() => _BillRecordDetailPageState();
}

class _BillRecordDetailPageState extends State<_BillRecordDetailPage> {
  late BillRecord _record = widget.record;
  BillBenchmarkQuote? _benchmarkQuote;
  BillBenchmarkQuote? _cnyQuote;
  bool _benchmarkLoading = false;
  bool _cnyLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadQuotes());
  }

  CardSummary? get _card => _cardFor(_record, widget.cards);

  Future<void> _loadQuotes() async {
    final repository = widget.benchmarkRepository;
    if (repository == null) return;
    setState(() {
      _benchmarkLoading = true;
      _cnyLoading = true;
    });
    BillBenchmarkQuote? benchmarkQuote;
    BillBenchmarkQuote? quote;
    await Future.wait([
      () async {
        try {
          benchmarkQuote = await repository.loadCurrent(_record.confirmed);
        } catch (_) {
          // The saved bill can still be viewed without a live benchmark.
        }
      }(),
      () async {
        try {
          quote = await repository.loadCurrentPair(
            from: _record.confirmed.deduction.currency,
            to: 'CNY',
          );
        } catch (_) {
          // RMB reference is supplementary.
        }
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      _benchmarkQuote = benchmarkQuote;
      _cnyQuote = quote;
      _benchmarkLoading = false;
      _cnyLoading = false;
    });
  }

  Future<void> _openEditor() async {
    AppHaptics.selection();
    final result = await Navigator.of(context).push<_BillEditResult>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          backgroundColor: AppColors.canvas,
          body: _BillRecordEditor(
            repository: widget.repository,
            benchmarkRepository: widget.benchmarkRepository,
            record: _record,
            cards: widget.cards,
            pageMode: true,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    widget.onChanged(result);
    if (result.deleted) {
      widget.onBack();
    } else if (result.record != null) {
      setState(() => _record = result.record!);
      unawaited(_loadQuotes());
    }
  }

  Future<void> _openShare() async {
    AppHaptics.selection();
    await showAppBottomSheet<void>(
      context: context,
      builder: (context) => _BillShareSheet(
        record: _record,
        card: _card,
        benchmarkQuote: _benchmarkQuote,
        cnyQuote: _cnyQuote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('bill-record-detail-page'),
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, bottomInset + 32),
          children: [
            _BillDetailHero(record: _record, card: _card),
            const SizedBox(height: 14),
            _BillDetailMetrics(
              record: _record,
              card: _card,
              benchmarkQuote: _benchmarkQuote,
              benchmarkLoading: _benchmarkLoading,
              cnyQuote: _cnyQuote,
              cnyLoading: _cnyLoading,
            ),
            const SizedBox(height: 14),
            _BillDetailInformation(record: _record),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('bill-record-open-editor'),
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑账单信息'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            if (_cnyQuote case final quote?) ...[
              const SizedBox(height: 12),
              Text(
                '实时人民币参考来源：${_quoteSource(quote)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            height: 76,
            child: Row(
              children: [
                IconButton(
                  key: const Key('bill-record-detail-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '账单详情',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  key: const Key('bill-record-share'),
                  onPressed: _openShare,
                  tooltip: '分享账单',
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BillDetailHero extends StatelessWidget {
  const _BillDetailHero({required this.record, required this.card});

  final BillRecord record;
  final CardSummary? card;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    final cardLabel =
        record.cardBinding.cardNameSnapshot ??
        data.cardName ??
        record.recognized.cardName ??
        card?.name ??
        '未绑定卡片';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1.586,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: card == null
                  ? _FallbackCardArtwork(label: cardLabel)
                  : CardArtwork(card: card!, memCacheWidth: 900),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppColors.isDark ? .1 : .035,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cardLabel,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.deduction.isComplete
                    ? data.deduction.label
                    : data.original.label,
                key: const Key('bill-detail-deduction'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '原始消费 ${data.original.label}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillDetailMetrics extends StatelessWidget {
  const _BillDetailMetrics({
    required this.record,
    required this.card,
    required this.benchmarkQuote,
    required this.benchmarkLoading,
    required this.cnyQuote,
    required this.cnyLoading,
  });

  final BillRecord record;
  final CardSummary? card;
  final BillBenchmarkQuote? benchmarkQuote;
  final bool benchmarkLoading;
  final BillBenchmarkQuote? cnyQuote;
  final bool cnyLoading;

  @override
  Widget build(BuildContext context) => _DetailSection(
    title: '费率与返现',
    icon: Icons.analytics_outlined,
    rows: _shareRows(
      record,
      card: card,
      benchmarkQuote: benchmarkQuote,
      benchmarkLoading: benchmarkLoading,
      cnyQuote: cnyQuote,
      cnyLoading: cnyLoading,
    ),
  );
}

class _BillDetailInformation extends StatelessWidget {
  const _BillDetailInformation({required this.record});

  final BillRecord record;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    return _DetailSection(
      title: '交易信息',
      icon: Icons.receipt_long_outlined,
      rows: [
        ('平台/发卡方', data.provider ?? '未识别'),
        ('交易时间', data.transactionAt ?? _date(record.createdAt)),
        ('交易状态', _transactionStatus(data.status)),
        ('结算金额', data.settlement.label),
        ('截图明示手续费', _feesLabel(data.fees)),
        if (data.cardLast4 != null) ('卡号', '•••• ${data.cardLast4}'),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: _decoration(),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    row.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        row.$2,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _BillShareSheet extends StatefulWidget {
  const _BillShareSheet({
    required this.record,
    required this.card,
    required this.benchmarkQuote,
    required this.cnyQuote,
  });

  final BillRecord record;
  final CardSummary? card;
  final BillBenchmarkQuote? benchmarkQuote;
  final BillBenchmarkQuote? cnyQuote;

  @override
  State<_BillShareSheet> createState() => _BillShareSheetState();
}

class _BillShareSheetState extends State<_BillShareSheet> {
  final GlobalKey _posterKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) throw StateError('生成账单图片失败');
      final permitted = await Gal.hasAccess();
      if (!permitted && !await Gal.requestAccess()) {
        throw StateError('未获得保存到相册的权限');
      }
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: 'cardfi-bill-${widget.record.id}',
      );
      if (mounted) {
        AppNotice.success(context, '账单分享图已保存到相册。', title: '保存成功');
      }
    } on GalException catch (error) {
      if (mounted) AppNotice.error(context, error.type.message, title: '保存失败');
    } catch (error) {
      if (mounted) AppNotice.error(context, '$error', title: '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .92,
    child: Material(
      key: const Key('bill-share-sheet'),
      color: AppColors.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '分享账单',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.textMuted.withValues(alpha: .09),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: RepaintBoundary(
                    key: _posterKey,
                    child: _BillSharePoster(
                      record: widget.record,
                      card: widget.card,
                      benchmarkQuote: widget.benchmarkQuote,
                      cnyQuote: widget.cnyQuote,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: FilledButton.icon(
                key: const Key('bill-share-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_saving ? '正在保存…' : '保存到相册'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BillSharePoster extends StatelessWidget {
  const _BillSharePoster({
    required this.record,
    required this.card,
    required this.benchmarkQuote,
    required this.cnyQuote,
  });

  final BillRecord record;
  final CardSummary? card;
  final BillBenchmarkQuote? benchmarkQuote;
  final BillBenchmarkQuote? cnyQuote;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    final cardLabel =
        record.cardBinding.cardNameSnapshot ??
        data.cardName ??
        record.recognized.cardName ??
        card?.name ??
        '消费卡片';
    final currency = data.deduction.currency ?? '';
    final deduction = double.tryParse(data.deduction.amount ?? '');
    final cashback = double.tryParse(record.metrics.cashbackValue ?? '');
    final loss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
    final netCashback = cashback == null || loss == null
        ? null
        : cashback - loss;
    final lossRate =
        _percentageValue(record.metrics.base.marketLossRate) ??
        _percentOf(
          loss,
          _benchmarkExpectedDeduction(record, benchmarkQuote: benchmarkQuote),
        );
    final cashbackRate = _percentOf(cashback, deduction);
    final netCashbackRate = _percentOf(netCashback, deduction);
    final lossCny = cnyQuote == null || loss == null
        ? null
        : _lossCnyLabel(record, cnyQuote!, benchmarkQuote: benchmarkQuote);
    final netCashbackCny = _netCashbackCnyLabel(
      record,
      benchmarkQuote: benchmarkQuote,
      cnyQuote: cnyQuote,
    );
    final detailRows =
        _shareRows(
          record,
          card: card,
          benchmarkQuote: benchmarkQuote,
          cnyQuote: cnyQuote,
        ).where(
          (row) => const {
            '实际综合汇率',
            '当前参考汇率',
            '实时人民币参考',
            '磨损后人民币汇率',
            '返现后人民币汇率',
            '卡片宣称返现',
            '截图明示手续费',
          }.contains(row.$1),
        );
    String amountLabel(double? value, {bool signed = false}) {
      if (value == null) return '待补充';
      final sign = signed && value > 0 ? '+' : '';
      return '$sign${_formatDisplayDecimal(value)} $currency'.trim();
    }

    String supportingLabel(
      String? percent,
      String? cny, {
      bool signed = false,
    }) {
      final values = [
        if (percent != null)
          '${signed && !percent.startsWith('-') ? '+' : ''}$percent%',
        ?cny,
      ];
      return values.isEmpty ? '待补充' : values.join(' · ');
    }

    return Container(
      key: const Key('bill-share-poster'),
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7FF),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F7FF), Color(0xFFEDF4FF)],
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF151522)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  key: const Key('bill-share-logo'),
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/branding/cardfi-icon-master.png',
                    width: 42,
                    height: 42,
                    cacheWidth: 126,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CardFi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '消费账单分析',
                        style: TextStyle(
                          color: Color(0xFF77798C),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _compactBillDate(record),
                  style: const TextStyle(
                    color: Color(0xFF8B8DA0),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E8F4)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 128,
                    child: AspectRatio(
                      aspectRatio: 1.586,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: card == null
                            ? _FallbackCardArtwork(label: cardLabel)
                            : CardArtwork(card: card!, memCacheWidth: 520),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF66687A),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.deduction.isComplete
                                ? data.deduction.label
                                : data.original.label,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '原始消费 ${data.original.label}',
                          style: const TextStyle(
                            color: Color(0xFF77798C),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShareMetricTile(
                    key: const Key('bill-share-loss-metric'),
                    label: '汇率损耗',
                    value: amountLabel(loss),
                    supporting: supportingLabel(lossRate, lossCny),
                    color: const Color(0xFFE65A9B),
                    icon: Icons.trending_down_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShareMetricTile(
                    key: const Key('bill-share-cashback-metric'),
                    label: '本笔返现',
                    value: amountLabel(cashback),
                    supporting: cashbackRate == null ? '待补充' : '$cashbackRate%',
                    color: const Color(0xFF6F63E9),
                    icon: Icons.redeem_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShareMetricTile(
                    key: const Key('bill-share-net-metric'),
                    label: '磨损后净返现',
                    value: amountLabel(netCashback, signed: true),
                    supporting: supportingLabel(
                      netCashbackRate,
                      netCashbackCny,
                      signed: true,
                    ),
                    color: const Color(0xFF00A98F),
                    icon: Icons.savings_outlined,
                    emphasized: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E8F4)),
              ),
              child: Column(
                children: [
                  for (final row in detailRows)
                    _ShareDetailRow(label: row.$1, value: row.$2),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${data.provider ?? '未知平台'} · ${data.transactionAt ?? _date(record.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF77798C),
                      fontSize: 8.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '由 CardFi 生成',
                  style: TextStyle(
                    color: Color(0xFF6F63E9),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '参考汇率仅用于费用核对，最终以发卡方交易记录为准。',
              style: TextStyle(color: Color(0xFF999BAD), fontSize: 7.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareMetricTile extends StatelessWidget {
  const _ShareMetricTile({
    required this.label,
    required this.value,
    required this.supporting,
    required this.color,
    required this.icon,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final String value;
  final String supporting;
  final Color color;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    height: 82,
    padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: emphasized ? .13 : .085),
          color.withValues(alpha: emphasized ? .055 : .025),
        ],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: emphasized ? .2 : .12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 12),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F7184),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            supporting,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF77798C),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ShareDetailRow extends StatelessWidget {
  const _ShareDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF77798C), fontSize: 9.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 9.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

List<(String, String)> _shareRows(
  BillRecord record, {
  CardSummary? card,
  BillBenchmarkQuote? benchmarkQuote,
  bool benchmarkLoading = false,
  BillBenchmarkQuote? cnyQuote,
  bool cnyLoading = false,
}) {
  final data = record.confirmed;
  final metrics = record.metrics;
  final from = data.original.currency;
  final to = data.deduction.currency;
  final effective = metrics.base.effectiveDeductionPerOriginal;
  final benchmark =
      record.calculationInputs.benchmarkRate ?? benchmarkQuote?.rate;
  final advertisedCashback = _advertisedCashback(record, card);
  final marketLoss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
  return [
    (
      '实际综合汇率',
      effective == null || from == null || to == null
          ? '信息不足'
          : '1 $from = $effective $to',
    ),
    (
      '当前参考汇率',
      benchmarkLoading && benchmark == null
          ? '正在获取…'
          : benchmark == null || from == null || to == null
          ? '未填写'
          : '1 $from = $benchmark $to',
    ),
    (
      '实时人民币参考',
      cnyLoading && cnyQuote == null
          ? '正在获取…'
          : cnyQuote == null
          ? '未填写'
          : _cnyRateLabel(cnyQuote),
    ),
    (
      '磨损后人民币汇率',
      cnyLoading && cnyQuote == null
          ? '正在获取…'
          : cnyQuote == null
          ? '信息不足'
          : _lossAdjustedCnyRateLabel(
              record,
              cnyQuote,
              benchmarkQuote: benchmarkQuote,
            ),
    ),
    (
      '返现后人民币汇率',
      cnyLoading && cnyQuote == null
          ? '正在获取…'
          : cnyQuote == null
          ? '信息不足'
          : record.metrics.cashbackValue == null
          ? '待补录返现'
          : _cashbackAdjustedCnyRateLabel(
              record,
              cnyQuote,
              benchmarkQuote: benchmarkQuote,
            ),
    ),
    ('当前参考损耗', _lossWithRate(record, benchmarkQuote: benchmarkQuote)),
    if (cnyQuote != null && marketLoss != null)
      (
        '损耗折合人民币',
        _lossCnyLabel(record, cnyQuote, benchmarkQuote: benchmarkQuote),
      ),
    if (advertisedCashback != null) ('卡片宣称返现', advertisedCashback),
    ('本笔实际返现', _cashbackWithRate(record)),
    (
      '扣除损耗后净返现',
      _actualCashbackAfterLoss(record, benchmarkQuote: benchmarkQuote),
    ),
    ('截图明示手续费', _feesLabel(data.fees)),
  ];
}

String _feesLabel(List<BillFee> fees) {
  if (fees.isEmpty) return '截图未显示';
  return fees
      .map(
        (fee) => [
          if (fee.label?.isNotEmpty == true) fee.label!,
          if (fee.amount?.isNotEmpty == true) fee.amount!,
          if (fee.currency?.isNotEmpty == true) fee.currency!,
        ].join(' '),
      )
      .join('、');
}

String _transactionStatus(String status) => switch (status) {
  'success' => '交易成功',
  'failed' => '交易失败',
  'pending' => '处理中',
  'refunded' => '已退款',
  _ => '未知',
};

class _BillMetricsOverview extends StatelessWidget {
  const _BillMetricsOverview({required this.record, required this.card});

  final BillRecord record;
  final CardSummary? card;

  @override
  Widget build(BuildContext context) {
    final data = record.confirmed;
    final metrics = record.metrics;
    final originalCurrency = data.original.currency;
    final deductionCurrency = data.deduction.currency;
    final effective = metrics.base.effectiveDeductionPerOriginal;
    final advertisedCashback = _advertisedCashback(record, card);
    return Container(
      key: const Key('bill-history-metrics'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark ? .1 : .035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  color: AppColors.violet,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计算预览',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('保存后按确认值重新计算', style: TextStyle(fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: AppColors.textMuted.withValues(alpha: .09)),
          const SizedBox(height: 13),
          _metricRow(
            '实际汇率',
            effective == null ||
                    originalCurrency == null ||
                    deductionCurrency == null
                ? '信息不足'
                : '1 $originalCurrency = $effective $deductionCurrency',
          ),
          _metricRow('实际损耗', _lossWithRate(record)),
          if (advertisedCashback != null)
            _metricRow('卡片宣称返现', advertisedCashback),
          _metricRow('本笔实际返现', _cashbackWithRate(record)),
          _metricRow(
            '扣除损耗后净返现',
            _actualCashbackAfterLoss(record),
            emphasized: metrics.netLoss != null,
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: emphasized ? AppColors.mint : AppColors.text,
                  fontSize: 11,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

String _actualCashbackAfterLoss(
  BillRecord record, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final currency = record.confirmed.deduction.currency ?? '';
  final cashback = double.tryParse(record.metrics.cashbackValue ?? '');
  if (cashback == null) return '待补录返现';
  final loss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
  if (loss == null) {
    return '等待当前参考汇率';
  }
  final valueNumber = cashback - loss;
  final value = _formatDisplayDecimal(valueNumber);
  final percent = _percentOf(
    double.tryParse(value),
    double.tryParse(record.confirmed.deduction.amount ?? ''),
  );
  final sign = value.startsWith('-') || value == '0' ? '' : '+';
  final percentLabel = percent == null
      ? ''
      : ' (${percent.startsWith('-') || percent == '0' ? '' : '+'}$percent%)';
  return '$sign$value $currency$percentLabel'.trim();
}

String _lossWithRate(BillRecord record, {BillBenchmarkQuote? benchmarkQuote}) {
  final loss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
  if (loss == null) return '等待当前参考汇率';
  final currency = record.confirmed.deduction.currency ?? '';
  final rate =
      _percentageValue(record.metrics.base.marketLossRate) ??
      _percentOf(
        loss,
        double.tryParse(
          record.metrics.benchmarkExpectedDeduction ??
              _benchmarkExpectedDeduction(
                record,
                benchmarkQuote: benchmarkQuote,
              )?.toString() ??
              record.confirmed.deduction.amount ??
              '',
        ),
      );
  final displayLoss = _formatDisplayDecimal(loss);
  return '$displayLoss $currency${rate == null ? '' : ' ($rate%)'}'.trim();
}

double? _marketLossValue(
  BillRecord record, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final saved = double.tryParse(record.metrics.base.marketLoss ?? '');
  if (saved != null) return saved;
  final expected = _benchmarkExpectedDeduction(
    record,
    benchmarkQuote: benchmarkQuote,
  );
  final deduction = double.tryParse(record.confirmed.deduction.amount ?? '');
  if (expected == null || deduction == null) return null;
  return deduction - expected;
}

double? _benchmarkExpectedDeduction(
  BillRecord record, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final saved = double.tryParse(
    record.metrics.benchmarkExpectedDeduction ?? '',
  );
  if (saved != null) return saved;
  final original = double.tryParse(record.confirmed.original.amount ?? '');
  final rate = double.tryParse(
    record.calculationInputs.benchmarkRate ?? benchmarkQuote?.rate ?? '',
  );
  if (original == null || rate == null) return null;
  return original * rate;
}

String _cashbackWithRate(BillRecord record) {
  final cashback = record.metrics.cashbackValue;
  if (cashback == null) return '待补录返现比例或到账金额';
  final currency = record.confirmed.deduction.currency ?? '';
  final displayCashback = _formatDisplayDecimal(double.tryParse(cashback) ?? 0);
  final rate = _percentOf(
    double.tryParse(cashback),
    double.tryParse(record.confirmed.deduction.amount ?? ''),
  );
  return '$displayCashback $currency${rate == null ? '' : ' ($rate%)'}'.trim();
}

String _cnyRateLabel(BillBenchmarkQuote quote) {
  final rate = double.tryParse(quote.rate);
  return rate == null
      ? quote.rateLabel
      : '1 ${quote.from} ≈ ¥${_formatDisplayDecimal(rate)}';
}

String _lossCnyLabel(
  BillRecord record,
  BillBenchmarkQuote quote, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final loss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
  final rate = double.tryParse(quote.rate);
  if (loss == null || rate == null) return '暂不可用';
  final value = loss * rate;
  final sign = value < 0 ? '-' : '';
  return '≈ $sign¥${_formatDisplayDecimal(value.abs(), digits: 2)}';
}

String? _netCashbackCnyLabel(
  BillRecord record, {
  required BillBenchmarkQuote? benchmarkQuote,
  required BillBenchmarkQuote? cnyQuote,
}) {
  final cashback = double.tryParse(record.metrics.cashbackValue ?? '');
  final loss = _marketLossValue(record, benchmarkQuote: benchmarkQuote);
  final cnyRate = double.tryParse(cnyQuote?.rate ?? '');
  if (cashback == null || loss == null || cnyRate == null) return null;
  final value = (cashback - loss) * cnyRate;
  final sign = value < 0
      ? '-'
      : value > 0
      ? '+'
      : '';
  return '$sign¥${_formatDisplayDecimal(value.abs(), digits: 2)}';
}

String _lossAdjustedCnyRateLabel(
  BillRecord record,
  BillBenchmarkQuote quote, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final rates = _billCnyRates(record, quote, benchmarkQuote: benchmarkQuote);
  final currency = record.confirmed.deduction.currency;
  if (rates == null || currency == null) return '暂不可用';
  return '1 $currency ≈ ¥${formatBillCnyRate(rates.lossAdjusted)}';
}

String _cashbackAdjustedCnyRateLabel(
  BillRecord record,
  BillBenchmarkQuote quote, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  final rates = _billCnyRates(record, quote, benchmarkQuote: benchmarkQuote);
  final currency = record.confirmed.deduction.currency;
  if (rates?.cashbackAdjusted == null || currency == null) return '暂不可用';
  return '1 $currency ≈ ¥${formatBillCnyRate(rates!.cashbackAdjusted!)}';
}

BillCnyRates? _billCnyRates(
  BillRecord record,
  BillBenchmarkQuote quote, {
  BillBenchmarkQuote? benchmarkQuote,
}) {
  return calculateBillCnyRates(
    currentCnyRate: double.tryParse(quote.rate),
    benchmarkExpectedDeduction: _benchmarkExpectedDeduction(
      record,
      benchmarkQuote: benchmarkQuote,
    ),
    actualDeduction: double.tryParse(record.confirmed.deduction.amount ?? ''),
    cashback: double.tryParse(record.metrics.cashbackValue ?? ''),
  );
}

String? _quoteKey(String? from, String? to) {
  final normalizedFrom = from?.trim().toUpperCase();
  final normalizedTo = to?.trim().toUpperCase();
  if (normalizedFrom == null ||
      normalizedFrom.isEmpty ||
      normalizedTo == null ||
      normalizedTo.isEmpty) {
    return null;
  }
  return '$normalizedFrom/$normalizedTo';
}

String? _advertisedCashback(BillRecord record, CardSummary? card) {
  final manualRate = _percentageValue(record.calculationInputs.cashbackRate);
  if (manualRate != null) return '$manualRate%';
  final value = card?.cashbackRate.trim();
  if (value == null || value.isEmpty) return null;
  final match = RegExp(r'(^|[^\d.])(\d+(?:\.\d+)?)\s*%').firstMatch(value);
  final parsed = _percentageValue(match?.group(2));
  return parsed == null ? null : '$parsed%';
}

String? _percentOf(double? value, double? basis) {
  if (value == null || basis == null || basis == 0) return null;
  return _percentageValue((value / basis * 100).toString());
}

String? _percentageValue(String? value) {
  final parsed = double.tryParse(value ?? '');
  if (parsed == null || !parsed.isFinite) return null;
  return parsed
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatDisplayDecimal(double value, {int digits = 4}) => value
    .toStringAsFixed(digits)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

class _BillRecordEditor extends StatefulWidget {
  const _BillRecordEditor({
    required this.repository,
    required this.record,
    required this.cards,
    this.benchmarkRepository,
    this.pageMode = false,
  });

  final BillHistoryRepository repository;
  final BillBenchmarkRepository? benchmarkRepository;
  final BillRecord record;
  final List<CardSummary> cards;
  final bool pageMode;

  @override
  State<_BillRecordEditor> createState() => _BillRecordEditorState();
}

class _BillRecordEditorState extends State<_BillRecordEditor> {
  late final Map<String, TextEditingController> _fields;
  CardSummary? _selectedCard;
  bool _bindingCleared = false;
  bool _confirmed = false;
  bool _saving = false;
  bool _loadingBenchmark = false;
  String? _benchmarkHint;
  String? _error;

  @override
  void initState() {
    super.initState();
    final data = widget.record.confirmed;
    final inputs = widget.record.calculationInputs;
    _confirmed = widget.record.status == 'confirmed';
    _selectedCard = widget.cards.cast<CardSummary?>().firstWhere(
      (card) => card?.id == widget.record.cardBinding.cardId,
      orElse: () => null,
    );
    _fields = {
      'provider': _controller(data.provider),
      'cardName': _controller(data.cardName),
      'transactionAt': _controller(data.transactionAt),
      'transactionStatus': _controller(data.status),
      'originalAmount': _controller(data.original.amount),
      'originalCurrency': _controller(data.original.currency),
      'settlementAmount': _controller(data.settlement.amount),
      'settlementCurrency': _controller(data.settlement.currency),
      'deductionAmount': _controller(data.deduction.amount),
      'deductionCurrency': _controller(data.deduction.currency),
      'cardLast4': _controller(data.cardLast4),
      'fees': _controller(
        data.fees
            .map(
              (fee) =>
                  '${fee.type}|${fee.label ?? ''}|${fee.amount ?? ''}|${fee.currency ?? ''}',
            )
            .join('\n'),
      ),
      'rates': _controller(
        data.exchangeRates
            .map(
              (rate) =>
                  '${rate.from ?? ''}|${rate.to ?? ''}|${rate.rate ?? ''}',
            )
            .join('\n'),
      ),
      'benchmarkRate': _controller(inputs.benchmarkRate),
      'cashbackRate': _controller(inputs.cashbackRate),
      'cashbackAmount': _controller(
        inputs.cashbackAmount.amount ??
            (data.cashback.currency == data.deduction.currency
                ? data.cashback.amount
                : null),
      ),
    };
    if (inputs.benchmarkRate == null) {
      _loadingBenchmark = widget.benchmarkRepository != null;
      unawaited(_prefillCurrentBenchmark());
    } else {
      _benchmarkHint = '已使用账单中保存的参考汇率，可直接修改。';
    }
  }

  Future<void> _prefillCurrentBenchmark() async {
    final repository = widget.benchmarkRepository;
    if (repository == null) return;
    try {
      final quote = await repository.loadCurrent(_extraction());
      if (!mounted) return;
      setState(() {
        if (_value('benchmarkRate') == null) {
          _fields['benchmarkRate']!.text = quote.rate;
          _benchmarkHint =
              '已采用 ${quote.rateLabel} · ${_quoteSource(quote)}；可直接修改。';
        } else {
          _benchmarkHint = '已保留你输入的参考汇率。';
        }
      });
    } on ApiException {
      if (mounted) {
        setState(() => _benchmarkHint = '当前参考汇率暂不可用，请手动填写。');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _benchmarkHint = '当前参考汇率暂不可用，请手动填写。');
      }
    } finally {
      if (mounted) setState(() => _loadingBenchmark = false);
    }
  }

  TextEditingController _controller(String? value) =>
      TextEditingController(text: value ?? '');
  String? _value(String key) =>
      _fields[key]!.text.trim().isEmpty ? null : _fields[key]!.text.trim();

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<BillFee> _fees() => _fields['fees']!.text
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        final parts = line.split('|');
        return BillFee(
          type: parts.elementAtOrNull(0)?.trim() ?? 'other',
          label: parts.elementAtOrNull(1)?.trim(),
          amount: parts.elementAtOrNull(2)?.trim(),
          currency: parts.elementAtOrNull(3)?.trim().toUpperCase(),
        );
      })
      .toList(growable: false);

  List<BillExchangeRate> _rates() => _fields['rates']!.text
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        final parts = line.split('|');
        return BillExchangeRate(
          from: parts.elementAtOrNull(0)?.trim().toUpperCase(),
          to: parts.elementAtOrNull(1)?.trim().toUpperCase(),
          rate: parts.elementAtOrNull(2)?.trim(),
        );
      })
      .toList(growable: false);

  BillExtraction _extraction() => BillExtraction(
    provider: _value('provider'),
    cardName: _value('cardName'),
    status: _value('transactionStatus') ?? 'unknown',
    transactionAt: _value('transactionAt'),
    original: BillMoney(
      amount: _value('originalAmount'),
      currency: _value('originalCurrency')?.toUpperCase(),
    ),
    settlement: BillMoney(
      amount: _value('settlementAmount'),
      currency: _value('settlementCurrency')?.toUpperCase(),
    ),
    deduction: BillMoney(
      amount: _value('deductionAmount'),
      currency: _value('deductionCurrency')?.toUpperCase(),
    ),
    cashback: widget.record.confirmed.cashback,
    fees: _fees(),
    exchangeRates: _rates(),
    cardLast4: _value('cardLast4'),
    confidence: widget.record.confirmed.confidence,
    needsReview: _confirmed ? const [] : widget.record.confirmed.needsReview,
  );

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final record = await widget.repository.update(
        record: widget.record,
        confirmed: _extraction(),
        calculationInputs: BillCalculationInputs(
          benchmarkRate: _value('benchmarkRate'),
          cashbackRate: _value('cashbackRate'),
          cashbackAmount: BillMoney(
            amount: _value('cashbackAmount'),
            currency: _value('cashbackAmount') == null
                ? null
                : _value('deductionCurrency')?.toUpperCase(),
          ),
        ),
        cardBinding: _selectedCard != null
            ? BillCardBinding(
                cardId: _selectedCard!.id,
                cardNameSnapshot: _selectedCard!.name,
              )
            : widget.record.cardBinding.isBound && !_bindingCleared
            ? widget.record.cardBinding
            : const BillCardBinding.unbound(),
        confirmedByUser: _confirmed,
      );
      if (mounted) Navigator.of(context).pop(_BillEditResult(record: record));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validate() {
    final decimal = RegExp(r'^-?\d+(?:\.\d+)?$');
    for (final key in const [
      'originalAmount',
      'settlementAmount',
      'deductionAmount',
    ]) {
      final value = _value(key);
      if (value != null && !decimal.hasMatch(value)) return '金额只能填写十进制数字。';
    }
    final nonNegative = RegExp(r'^\d+(?:\.\d+)?$');
    for (final key in const [
      'benchmarkRate',
      'cashbackRate',
      'cashbackAmount',
    ]) {
      final value = _value(key);
      if (value != null && !nonNegative.hasMatch(value)) {
        return '基准汇率和返现参数只能填写非负十进制数字。';
      }
    }
    final benchmark = double.tryParse(_value('benchmarkRate') ?? '1');
    if (_value('benchmarkRate') != null &&
        (benchmark == null || benchmark <= 0)) {
      return '基准汇率必须大于 0。';
    }
    final currency = RegExp(r'^[A-Za-z0-9]{1,12}$');
    for (final key in const [
      'originalCurrency',
      'settlementCurrency',
      'deductionCurrency',
    ]) {
      final value = _value(key);
      if (value != null && !currency.hasMatch(value)) return '币种请填写 1–12 位代码。';
    }
    final last4 = _value('cardLast4');
    if (last4 != null && !RegExp(r'^\d{4}$').hasMatch(last4)) {
      return '卡号末四位必须是 4 位数字，或留空。';
    }
    const statuses = {'success', 'failed', 'pending', 'refunded', 'unknown'};
    if (!statuses.contains(_value('transactionStatus') ?? 'unknown')) {
      return '交易状态请填写 success、failed、pending、refunded 或 unknown。';
    }
    for (final line
        in _fields['fees']!.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)) {
      final parts = line.split('|');
      const types = {'transaction', 'fx', 'cross_border', 'network', 'other'};
      if (parts.length != 4 ||
          !types.contains(parts[0].trim()) ||
          (parts[2].trim().isNotEmpty && !decimal.hasMatch(parts[2].trim())) ||
          (parts[3].trim().isNotEmpty && !currency.hasMatch(parts[3].trim()))) {
        return '手续费请按“类型|名称|金额|币种”每行一项填写。';
      }
    }
    for (final line
        in _fields['rates']!.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)) {
      final parts = line.split('|');
      if (parts.length != 3 ||
          !currency.hasMatch(parts[0].trim()) ||
          !currency.hasMatch(parts[1].trim()) ||
          !nonNegative.hasMatch(parts[2].trim())) {
        return '汇率请按“源币种|目标币种|汇率”每行一项填写。';
      }
    }
    final cashbackAmount = _value('cashbackAmount');
    if (cashbackAmount != null && _value('deductionCurrency') == null) {
      return '填写返现金额前，请先确认最终扣款币种。';
    }
    return null;
  }

  Future<void> _delete() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单记录？'),
        content: const Text('删除后无法恢复，原截图并未保存在服务器。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.delete(widget.record.id);
      if (mounted) {
        Navigator.of(context).pop(const _BillEditResult(deleted: true));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('bill-record-editor'),
    color: AppColors.canvas,
    borderRadius: widget.pageMode
        ? BorderRadius.zero
        : const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.pageMode ? 8 : 18,
            (widget.pageMode ? MediaQuery.paddingOf(context).top : 0) + 10,
            10,
            12,
          ),
          child: Column(
            children: [
              if (!widget.pageMode) ...[
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (widget.pageMode)
                    IconButton(
                      key: const Key('bill-record-editor-back'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      tooltip: '返回',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                    ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '核对账单记录',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '默认采用当前参考汇率，也可以手动修改。',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.pageMode)
                    IconButton(
                      key: const Key('bill-record-editor-close'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      tooltip: '关闭',
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.textMuted.withValues(alpha: .12)),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.paddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom +
                  24,
            ),
            children: [
              _BillMetricsOverview(
                record: widget.record,
                card: _selectedCard ?? _cardFor(widget.record, widget.cards),
              ),
              const SizedBox(height: 14),
              _cardBindingSection(),
              _section(
                '金额与币种',
                [
                  'originalAmount',
                  'originalCurrency',
                  'deductionAmount',
                  'deductionCurrency',
                ],
                const ['原始金额', '原始币种', '最终扣款', '扣款币种'],
                description: '先核对原始消费和最终扣款，这是所有汇率与损耗计算的基础。',
              ),
              _section(
                '汇率、损耗与返现',
                ['benchmarkRate', 'cashbackRate', 'cashbackAmount'],
                const ['当前参考汇率', '宣称返现比例', '实际返现金额'],
                description:
                    '${_loadingBenchmark ? '正在获取当前参考汇率…\n' : ''}'
                    '${_benchmarkHint == null ? '' : '${_benchmarkHint!}\n'}'
                    '参考汇率可直接修改。宣称返现只填百分比数字，例如 1；实际返现金额按到账价值填写，币种与最终扣款一致。',
              ),
              _section(
                '交易信息',
                [
                  'provider',
                  'cardName',
                  'transactionAt',
                  'transactionStatus',
                  'settlementAmount',
                  'settlementCurrency',
                  'cardLast4',
                ],
                const [
                  '平台/发卡方',
                  '截图卡名',
                  '交易时间',
                  '交易状态',
                  '结算金额',
                  '结算币种',
                  '卡号后四位',
                ],
              ),
              _advancedSection(),
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: _decoration(),
                child: SwitchListTile.adaptive(
                  value: _confirmed,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _confirmed = value),
                  title: const Text(
                    '已由我核对确认',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('关闭时记录保持“待确认”状态'),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF4D67),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                key: const Key('bill-record-save'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(_saving ? '保存中…' : '保存并重新计算'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: const Text('删除这条记录'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _cardBindingSection() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '关联卡片',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '关联后会展示卡面；不关联也可以独立保存这笔账单。',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SearchableCardPicker(
          label: '选择卡片',
          cards: widget.cards
              .where((card) => card.isAddableToCardWallet)
              .toList(),
          selected: _selectedCard,
          onChanged: (card) => setState(() {
            _selectedCard = card;
            _bindingCleared = false;
          }),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('bill-edit-unbind-card'),
            onTap: _saving
                ? null
                : () => setState(() {
                    _selectedCard = null;
                    _bindingCleared = true;
                  }),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: _selectedCard == null
                    ? AppColors.violet.withValues(alpha: .075)
                    : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedCard == null
                      ? AppColors.violet.withValues(alpha: .28)
                      : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    size: 20,
                    color: _selectedCard == null
                        ? AppColors.violet
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '不关联卡片',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text('仅保存账单识别与计算结果', style: TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  ),
                  if (_selectedCard == null)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.violet,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section(
    String title,
    List<String> keys,
    List<String> labels, {
    String? description,
    int maxLines = 1,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var index = 0; index < keys.length; index++) ...[
          Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 108,
                child: Padding(
                  padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: Key('bill-edit-${keys[index]}'),
                  controller: _fields[keys[index]],
                  enabled: !_saving,
                  maxLines: maxLines,
                  textAlign: maxLines == 1 ? TextAlign.right : TextAlign.start,
                  keyboardType: _keyboardType(keys[index]),
                  decoration: InputDecoration(
                    hintText: '未填写',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.isDark
                        ? AppColors.surfaceRaised
                        : const Color(0xFFF5F7FC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.isDark
                            ? AppColors.textMuted.withValues(alpha: .12)
                            : const Color(0xFFD7DDEA),
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.isDark
                            ? AppColors.textMuted.withValues(alpha: .07)
                            : const Color(0xFFE5E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.violet,
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (index != keys.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: AppColors.textMuted.withValues(alpha: .08),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _advancedSection() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: _decoration(),
    child: ExpansionTile(
      key: const Key('bill-edit-advanced'),
      title: const Text(
        '高级识别字段',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
      ),
      subtitle: const Text('仅在截图手续费或汇率识别有误时修改'),
      childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        TextField(
          key: const Key('bill-edit-fees'),
          controller: _fields['fees'],
          enabled: !_saving,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: '手续费：每行 类型|名称|金额|币种',
            filled: true,
            fillColor: AppColors.surfaceRaised,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('bill-edit-rates'),
          controller: _fields['rates'],
          enabled: !_saving,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: '截图汇率：每行 源币种|目标币种|汇率',
            filled: true,
            fillColor: AppColors.surfaceRaised,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
  );

  TextInputType? _keyboardType(String key) {
    if (key.endsWith('Amount') ||
        key == 'benchmarkRate' ||
        key == 'cashbackRate') {
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    }
    return null;
  }
}

String _quoteSource(BillBenchmarkQuote quote) {
  final updatedAt = quote.updatedAt?.toLocal();
  if (updatedAt == null) return quote.sourceLabel;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${quote.sourceLabel} · 更新 ${updatedAt.year}-'
      '${twoDigits(updatedAt.month)}-${twoDigits(updatedAt.day)} '
      '${twoDigits(updatedAt.hour)}:${twoDigits(updatedAt.minute)}';
}

class _BillEditResult {
  const _BillEditResult({this.record, this.deleted = false});
  final BillRecord? record;
  final bool deleted;
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _decoration(),
    child: Column(
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

String _date(DateTime? value) {
  if (value == null) return '未知时间';
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _compactBillDate(BillRecord record) {
  final raw = record.confirmed.transactionAt ?? '';
  final rawMatch = RegExp(
    r'^\d{4}-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (rawMatch != null) {
    return '${rawMatch.group(1)}-${rawMatch.group(2)} '
        '${rawMatch.group(3)}:${rawMatch.group(4)}';
  }
  final date = _recordDate(record).toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.month)}-${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

BoxDecoration _decoration() => BoxDecoration(
  color: AppColors.glassStrong,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? .1 : .03),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ],
);
