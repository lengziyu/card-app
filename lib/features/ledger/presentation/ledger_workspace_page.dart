import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/ledger/data/ledger_repository.dart';
import 'package:cardfi/features/ledger/domain/ledger_models.dart';
import 'package:cardfi/features/ledger/presentation/ledger_editors.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:flutter/material.dart' hide Text;

Route<T> ledgerRoute<T>(BuildContext context, Widget page) =>
    _LedgerPageRoute<T>(
      builder: (_) => page,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );

class _LedgerPageRoute<T> extends MaterialPageRoute<T> {
  _LedgerPageRoute({required super.builder, required this.reduceMotion});
  final bool reduceMotion;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : MotionTokens.page;
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : MotionTokens.pageReverse;
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => reduceMotion
      ? child
      : super.buildTransitions(context, animation, secondaryAnimation, child);
}

/// Give ledger instructions and statuses sufficient contrast in both themes.
class LedgerScaffold extends StatelessWidget {
  const LedgerScaffold({required this.body, this.appBar, super.key});
  final Widget body;
  final PreferredSizeWidget? appBar;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyMedium: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: appBar,
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}

/// The entire nested navigator disappears on account switch, including any open
/// editor/dialog. Repositories also check the originating identity on completion.
class LedgerWorkspacePage extends StatefulWidget {
  const LedgerWorkspacePage({
    required this.repository,
    required this.catalog,
    required this.sessionChanges,
    required this.sessionValid,
    required this.onBack,
    this.initialProduct,
    this.importBill,
    this.onAnalyze,
    super.key,
  });
  final LedgerRepository repository;
  final List<CardSummary> catalog;
  final Listenable sessionChanges;
  final bool Function() sessionValid;
  final VoidCallback onBack;
  final CardSummary? initialProduct;
  final BillRecord? importBill;
  final VoidCallback? onAnalyze;
  @override
  State<LedgerWorkspacePage> createState() => _LedgerWorkspacePageState();
}

class _LedgerWorkspacePageState extends State<LedgerWorkspacePage> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sessionChanges,
    builder: (context, _) => !widget.sessionValid()
        ? LedgerScaffold(
            appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
            body: const Center(child: Text('账号已切换，请重新打开账本')),
          )
        : NavigatorPopHandler<void>(
            onPopWithResult: (_) => _navigator.currentState?.maybePop(),
            child: Navigator(
              key: _navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => widget.initialProduct != null
                    ? PersonalCardsPage(
                        repository: widget.repository,
                        catalog: widget.catalog,
                        initialProduct: widget.initialProduct,
                        onBack: widget.onBack,
                        onAnalyze: widget.onAnalyze,
                      )
                    : LedgerHomePage(
                        repository: widget.repository,
                        catalog: widget.catalog,
                        onBack: widget.onBack,
                        importBill: widget.importBill,
                        onAnalyze: widget.onAnalyze,
                      ),
              ),
            ),
          ),
  );
}

class PersonalCardsPage extends StatefulWidget {
  const PersonalCardsPage({
    required this.repository,
    required this.catalog,
    required this.onBack,
    this.initialProduct,
    this.onAnalyze,
    super.key,
  });
  final LedgerRepository repository;
  final List<CardSummary> catalog;
  final CardSummary? initialProduct;
  final VoidCallback onBack;
  final VoidCallback? onAnalyze;
  @override
  State<PersonalCardsPage> createState() => _PersonalCardsPageState();
}

class _PersonalCardsPageState extends State<PersonalCardsPage> {
  List<PersonalCard> _cards = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await widget.repository.cards();
      if (!mounted || generation != _generation) return;
      setState(
        () => _cards = cards
            .where(
              (card) =>
                  widget.initialProduct == null ||
                  card.catalogCardId == widget.initialProduct!.id,
            )
            .toList(),
      );
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = ledgerError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([PersonalCard? card]) async {
    final saved = await Navigator.of(context).push<bool>(
      ledgerRoute(
        context,
        PersonalCardEditor(
          repository: widget.repository,
          catalog: widget.catalog,
          existing: card,
          initialProduct: widget.initialProduct,
        ),
      ),
    );
    if (mounted && saved == true) await _load();
  }

  Future<void> _open(PersonalCard card) async {
    AppHaptics.selection();
    await Navigator.of(context).push<void>(
      ledgerRoute(
        context,
        LedgerHomePage(
          repository: widget.repository,
          catalog: widget.catalog,
          initialCard: card,
          onAnalyze: widget.onAnalyze,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => LedgerScaffold(
    key: const Key('personal-cards-page'),
    appBar: AppBar(
      title: const Text('管理我的卡片'),
      leading: BackButton(onPressed: widget.onBack),
      actions: [
        IconButton(
          key: const Key('personal-card-add'),
          onPressed: _loading || _error != null ? null : () => _edit(),
          tooltip: context.tr('添加个人卡片'),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.initialProduct != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.initialProduct!.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          const Text('同款卡可以添加多张，仅保存卡号末四位。'),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            LedgerErrorView(message: _error!, onRetry: _load)
          else if (_cards.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('还没有个人卡片，添加后即可记录消费。', textAlign: TextAlign.center),
            ),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('添加个人卡片'),
            ),
          ] else
            for (final card in _cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _cardTile(card),
              ),
        ],
      ),
    ),
  );
  Widget _cardTile(PersonalCard card) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 310 ||
          MediaQuery.textScalerOf(context).scale(16) > 24;
      final artwork = SizedBox(
        width: 76,
        child: AspectRatio(aspectRatio: 1.586, child: _artwork(card)),
      );
      final edit = IconButton(
        tooltip: context.tr('编辑卡片资料'),
        onPressed: () => _edit(card),
        icon: const Icon(Icons.edit_outlined),
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: Theme.of(context).textTheme.titleMedium),
          if (card.last4.isNotEmpty) Text('•••• ${card.last4}'),
          Text(card.archived ? '已归档' : card.productName),
        ],
      );
      return Material(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _open(card),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [artwork, const Spacer(), edit]),
                      const SizedBox(height: 12),
                      details,
                    ],
                  )
                : Row(
                    children: [
                      artwork,
                      const SizedBox(width: 16),
                      Expanded(child: details),
                      edit,
                    ],
                  ),
          ),
        ),
      );
    },
  );

  Widget _artwork(PersonalCard card) {
    final catalog = widget.catalog
        .where((item) => item.id == card.catalogCardId)
        .firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: catalog == null
          ? ColoredBox(
              color: AppColors.glassStrong,
              child: const Icon(Icons.credit_card),
            )
          : CardArtwork(card: catalog, showGeneratedLabels: false),
    );
  }
}

class LedgerHomePage extends StatefulWidget {
  const LedgerHomePage({
    required this.repository,
    required this.catalog,
    required this.onBack,
    this.initialCard,
    this.importBill,
    this.onAnalyze,
    super.key,
  });
  final LedgerRepository repository;
  final List<CardSummary> catalog;
  final VoidCallback onBack;
  final PersonalCard? initialCard;
  final BillRecord? importBill;
  final VoidCallback? onAnalyze;
  @override
  State<LedgerHomePage> createState() => _LedgerHomePageState();
}

class _LedgerHomePageState extends State<LedgerHomePage> {
  List<PersonalCard> _cards = [];
  List<LedgerEntry> _entries = [];
  LedgerSummary? _summary;
  DateTime _month = DateTime.now();
  String? _cardId, _state, _currency, _cursor, _error;
  bool _loading = true, _loadingMore = false, _importOpened = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _cardId = widget.initialCard?.id;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.repository.cards(),
        widget.repository.entries(
          month: ledgerMonth(_month),
          userCardId: _cardId,
          currency: _currency,
          state: _state,
        ),
        widget.repository.summary(
          month: ledgerMonth(_month),
          userCardId: _cardId,
          currency: _currency,
        ),
      ]);
      if (!mounted || generation != _generation) return;
      final page = result[1] as LedgerPage;
      final cards = result[0] as List<PersonalCard>;
      if (_cardId != null && !cards.any((card) => card.id == _cardId)) {
        _cardId = null;
        await _load();
        return;
      }
      setState(() {
        _cards = result[0] as List<PersonalCard>;
        _entries = page.entries;
        _cursor = page.nextCursor;
        _summary = result[2] as LedgerSummary;
      });
      if (!_importOpened && widget.importBill != null) {
        _importOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _edit(bill: widget.importBill);
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = ledgerError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _more() async {
    final cursor = _cursor, generation = _generation;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.entries(
        month: ledgerMonth(_month),
        userCardId: _cardId,
        currency: _currency,
        state: _state,
        cursor: cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = {
          for (final entry in _entries) entry.id: entry,
          for (final entry in page.entries) entry.id: entry,
        }.values.toList();
        _cursor = page.nextCursor == cursor ? null : page.nextCursor;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        AppNotice.error(context, ledgerError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _manageCards() async {
    await Navigator.of(context).push<void>(
      ledgerRoute(
        context,
        PersonalCardsPage(
          repository: widget.repository,
          catalog: widget.catalog,
          onBack: () => Navigator.of(context).pop(),
          onAnalyze: widget.onAnalyze,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _edit({
    LedgerEntry? entry,
    LedgerEntry? related,
    String? type,
    BillRecord? bill,
  }) async {
    if (bill?.confirmed.status == 'refunded') {
      AppNotice.info(context, '退款账单请从原消费的记录退款入口补录');
      return;
    }
    if (entry == null &&
        related == null &&
        !_cards.any((card) => !card.archived)) {
      AppNotice.info(context, '请先添加或恢复一张未归档的个人卡片');
      await _manageCards();
      if (!mounted || !_cards.any((card) => !card.archived)) return;
    }
    final result = await Navigator.of(context).push<LedgerEditResult>(
      ledgerRoute(
        context,
        LedgerEntryEditor(
          repository: widget.repository,
          cards: _cards,
          existing: entry,
          related: related,
          initialType: type,
          initialCardId: _cardId,
          importBill: bill,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final saved = result.saved;
    if (saved != null) {
      // Follow the saved record so a past-month import or changed filter does
      // not make a successful save appear to have vanished.
      _month = DateTime.parse(saved.occurredOn);
      if (_cardId != null) _cardId = saved.userCardId;
      if (_state != saved.state) _state = null;
      if (_currency != saved.money.currency) _currency = null;
    }
    await _load();
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _cards.where((card) => card.id == _cardId).firstOrNull;
    return LedgerScaffold(
      key: const Key('ledger-home-page'),
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('消费账本'),
        actions: [
          IconButton(
            key: const Key('ledger-manage-cards'),
            onPressed: _manageCards,
            tooltip: context.tr('管理我的卡片'),
            icon: const Icon(Icons.credit_card_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.tr('刷新'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey('ledger-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('ledger-card-${selected?.id}'),
              initialValue: selected?.id ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('个人卡片')),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部卡片')),
                for (final card in _cards)
                  DropdownMenuItem(
                    value: card.id,
                    child: Text(
                      card.selectionLabel,
                      semanticsLabel: card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _cardId = value == '' ? null : value);
                      _load();
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  key: const Key('ledger-previous-month'),
                  tooltip: context.tr('上个月'),
                  onPressed: _loading || ledgerMonth(_month) == '1900-01'
                      ? null
                      : () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    ledgerMonth(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('下个月'),
                  onPressed: _loading || ledgerMonth(_month) == '2199-12'
                      ? null
                      : () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              LedgerErrorView(message: _error!, onRetry: _load)
            else ...[
              const Text('月度汇总仅含已入账流水，按原币种分别统计。'),
              const SizedBox(height: 12),
              if (_summary?.currencies.isEmpty ?? true)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('本月暂无已入账流水'),
                ),
              for (final bucket
                  in _summary?.currencies ?? <Map<String, dynamic>>[])
                _SummaryPanel(bucket: bucket),
              const SizedBox(height: 8),
              if (selected?.archived == true)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('这张卡已归档，可查看流水并记录关联退款或返现。新增消费请先恢复卡片。'),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('ledger-add-entry'),
                    onPressed: selected?.archived == true
                        ? null
                        : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('记一笔'),
                  ),
                  if (widget.onAnalyze != null && selected?.archived != true)
                    OutlinedButton.icon(
                      onPressed: widget.onAnalyze,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('识别账单'),
                    ),
                ],
              ),
              if (widget.importBill != null)
                TextButton(
                  onPressed: () => _edit(bill: widget.importBill),
                  child: const Text('导入这笔识别账单'),
                ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey('ledger-state-$_state'),
                initialValue: _state ?? '',
                decoration: InputDecoration(labelText: context.tr('流水状态')),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部状态')),
                  for (final state in ledgerStateLabels.entries)
                    DropdownMenuItem(
                      value: state.key,
                      child: Text(state.value),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _state = value == '' ? null : value);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _currency ?? '',
                decoration: InputDecoration(
                  labelText: context.tr('筛选币种'),
                  hintText: 'CNY / USD / USDT',
                  suffixIcon: IconButton(
                    tooltip: context.tr('清除筛选'),
                    onPressed: () {
                      setState(() => _currency = null);
                      _load();
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
                key: ValueKey('currency-$_currency'),
                textCapitalization: TextCapitalization.characters,
                onFieldSubmitted: (value) {
                  setState(
                    () => _currency = value.trim().isEmpty
                        ? null
                        : value.trim().toUpperCase(),
                  );
                  _load();
                },
              ),
              const SizedBox(height: 16),
              if (_entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('没有符合条件的流水', textAlign: TextAlign.center),
                ),
              for (final entry in _entries)
                _EntryRow(
                  entry: entry,
                  onEdit: () => _edit(entry: entry),
                  onRelated: (type) => _edit(related: entry, type: type),
                ),
              if (_cursor != null)
                TextButton(
                  key: const Key('ledger-load-more'),
                  onPressed: _loadingMore ? null : _more,
                  child: _loadingMore
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('加载更多'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.bucket});
  final Map<String, dynamic> bucket;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bucket['currency'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final metric in const {
                    'spent': '消费扣款',
                    'refunds': '退款',
                    'fees': '已记录手续费',
                    'cashback': '已到账返现',
                    'net': '净支出',
                  }.entries)
                    SizedBox(
                      width:
                          constraints.maxWidth < 280 ||
                              MediaQuery.textScalerOf(context).scale(16) > 24
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.value,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          Text(
                            bucket[metric.key]?.toString() ?? '0',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onEdit,
    required this.onRelated,
  });
  final LedgerEntry entry;
  final VoidCallback onEdit;
  final ValueChanged<String> onRelated;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.glassStrong,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ledgerTypeLabels[entry.type] ?? entry.type,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (entry.type == 'expense' && entry.state == 'posted')
                    PopupMenuButton<String>(
                      tooltip: context.tr('更多操作'),
                      onSelected: onRelated,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'refund',
                          child: Text('记录退款'),
                        ),
                        const PopupMenuItem(
                          value: 'cashback',
                          child: Text('记录返现'),
                        ),
                      ],
                    ),
                ],
              ),
              Text(
                '${entry.isCredit ? '+' : '−'}${entry.money.label}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                entry.snapshotLabel,
                style: TextStyle(color: AppColors.textMuted),
              ),
              Wrap(
                spacing: 10,
                children: [
                  Text(entry.occurredOn),
                  Text(ledgerStateLabels[entry.state] ?? entry.state),
                  Text(entry.source == 'bill' ? '来自识别账单' : '手动录入'),
                ],
              ),
              if (entry.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entry.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String ledgerError(Object error) =>
    error is ApiException ? error.message : '消费账本暂不可用，请稍后重试';

class LedgerErrorView extends StatelessWidget {
  const LedgerErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
