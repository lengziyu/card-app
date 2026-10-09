import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/searchable_card_picker.dart';
import 'package:cardfi/features/ledger/data/ledger_repository.dart';
import 'package:cardfi/features/ledger/domain/ledger_models.dart';
import 'package:cardfi/features/ledger/presentation/ledger_workspace_page.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

class PersonalCardEditor extends StatefulWidget {
  const PersonalCardEditor({
    required this.repository,
    required this.catalog,
    this.existing,
    this.initialProduct,
    super.key,
  });
  final LedgerRepository repository;
  final List<CardSummary> catalog;
  final PersonalCard? existing;
  final CardSummary? initialProduct;
  @override
  State<PersonalCardEditor> createState() => _PersonalCardEditorState();
}

class _PersonalCardEditorState extends State<PersonalCardEditor> {
  final _formKey = GlobalKey<FormState>();
  final _requestId = ledgerRequestId();
  late final _nickname = TextEditingController(text: widget.existing?.nickname);
  late final _last4 = TextEditingController(text: widget.existing?.last4);
  late CardSummary? _product =
      widget.initialProduct ??
      widget.catalog
          .where((card) => card.id == widget.existing?.catalogCardId)
          .firstOrNull;
  late String _form = widget.existing?.form ?? 'unspecified';
  late bool _archived = widget.existing?.archived ?? false;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _nickname.dispose();
    _last4.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_validateForm(_formKey)) return;
    if (_product == null && widget.existing == null) {
      setState(() => _error = '请选择卡片产品');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveCard(
        {
          'catalogCardId': widget.existing?.catalogCardId ?? _product!.id,
          'productName': widget.existing?.productName ?? _product!.name,
          'nickname': _nickname.text.trim(),
          'last4': _last4.text,
          'form': _form,
          'archived': _archived,
        },
        existing: widget.existing,
        requestId: _requestId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = ledgerError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || !await _confirmDelete(context, '删除这张个人卡片？有流水的卡片请使用归档。')) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteCard(widget.existing!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = ledgerError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: LedgerScaffold(
      key: const Key('personal-card-editor'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.existing == null ? '添加个人卡片' : '编辑卡片资料'),
      ),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.existing != null)
                    Text(
                      widget.existing!.productName,
                      style: Theme.of(context).textTheme.titleLarge,
                    )
                  else
                    SearchableCardPicker(
                      cards: widget.catalog
                          .where((card) => card.isAddableToCardWallet)
                          .toList(),
                      selected: _product,
                      onChanged: (card) => setState(() => _product = card),
                      label: '卡片产品',
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('personal-card-nickname'),
                    controller: _nickname,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: context.tr('卡片昵称'),
                      hintText: context.tr('例如：日常消费、旅行备用'),
                      errorMaxLines: 3,
                    ),
                    validator: (value) =>
                        containsSensitiveLedgerText(value ?? '')
                        ? context.tr('请勿填写完整卡号或其他敏感号码')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('personal-card-last4'),
                    controller: _last4,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            newValue.text.length <= 4 ? newValue : oldValue,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: context.tr('卡号末四位（选填）'),
                      helperText: context.tr('仅用于区分卡片，不填写完整卡号。'),
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                    ),
                    validator: (value) =>
                        value!.isEmpty || RegExp(r'^\d{4}$').hasMatch(value)
                        ? null
                        : context.tr('请填写 4 位数字，或留空'),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _form,
                    decoration: InputDecoration(labelText: context.tr('卡片形式')),
                    items: [
                      for (final item in const {
                        'unspecified': '未指定',
                        'physical': '实体卡',
                        'virtual': '虚拟卡',
                      }.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _form = value!),
                  ),
                  if (widget.existing != null)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('归档卡片'),
                      subtitle: const Text('归档后保留流水，可继续记录关联退款和返现。'),
                      value: _archived,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _archived = value),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('personal-card-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存'),
                  ),
                  if (widget.existing != null)
                    TextButton(
                      onPressed: _saving ? null : _delete,
                      child: const Text('删除个人卡片'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LedgerEditResult {
  const LedgerEditResult({this.saved});
  final LedgerEntry? saved;
}

class LedgerEntryEditor extends StatefulWidget {
  const LedgerEntryEditor({
    required this.repository,
    required this.cards,
    this.existing,
    this.related,
    this.initialType,
    this.initialCardId,
    this.importBill,
    super.key,
  });
  final LedgerRepository repository;
  final List<PersonalCard> cards;
  final LedgerEntry? existing, related;
  final String? initialType, initialCardId;
  final BillRecord? importBill;
  @override
  State<LedgerEntryEditor> createState() => _LedgerEntryEditorState();
}

class _LedgerEntryEditorState extends State<LedgerEntryEditor> {
  final _formKey = GlobalKey<FormState>();
  final _requestId = ledgerRequestId();
  late final Map<String, TextEditingController> _fields;
  String? _cardId, _error;
  late String _type, _state;
  late DateTime _date;
  bool _feeIncluded = true, _reviewed = false, _saving = false;
  bool _missingImportDate = false;
  @override
  void initState() {
    super.initState();
    final entry = widget.existing, bill = widget.importBill;
    final suggestions = bill == null
        ? <PersonalCard>[]
        : suggestedBillCards(widget.cards, bill);
    _cardId =
        entry?.userCardId ??
        widget.related?.userCardId ??
        widget.initialCardId ??
        (suggestions.length == 1 ? suggestions.single.id : null);
    if (entry == null &&
        widget.related == null &&
        _selected?.archived == true) {
      _cardId = null;
    }
    final parsedDate = ledgerDateFromText(
      entry?.occurredOn ?? bill?.confirmed.transactionAt,
    );
    _date = parsedDate ?? DateTime.now();
    _missingImportDate = bill != null && parsedDate == null;
    _type = entry?.type ?? widget.initialType ?? 'expense';
    _state = entry?.state ?? (bill != null ? 'draft' : 'posted');
    _feeIncluded = entry?.feeIncluded ?? true;
    final source = <String, String?>{
      'amount': entry?.money.amount ?? bill?.confirmed.deduction.amount,
      'currency':
          entry?.money.currency ??
          widget.related?.money.currency ??
          (bill == null ? 'CNY' : bill.confirmed.deduction.currency ?? ''),
      'originalAmount':
          entry?.original?.amount ?? bill?.confirmed.original.amount,
      'originalCurrency':
          entry?.original?.currency ?? bill?.confirmed.original.currency,
      'feeAmount': entry?.fee?.amount,
      'feeCurrency':
          entry?.fee?.currency ??
          entry?.money.currency ??
          bill?.confirmed.deduction.currency ??
          'CNY',
      'note': entry?.note,
    };
    _fields = source.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String _value(String name) => _fields[name]!.text.trim();
  PersonalCard? get _selected =>
      widget.cards.where((card) => card.id == _cardId).firstOrNull;
  String? get _relatedId =>
      widget.existing?.relatedEntryId ?? widget.related?.id;
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2199, 12, 31),
    );
    if (mounted && date != null) {
      setState(() {
        _date = date;
        _missingImportDate = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_validateForm(_formKey)) return;
    if (_selected == null) {
      setState(() => _error = '请选择个人卡片');
      return;
    }
    if (widget.importBill != null && !_reviewed) {
      setState(() => _error = '请先核对识别结果和卡片归属');
      return;
    }
    if (_type == 'expense' &&
        (_value('originalAmount').isEmpty !=
            _value('originalCurrency').isEmpty)) {
      setState(() => _error = '原始消费金额和币种需要一起填写');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveEntry(
        {
          'userCardId': _cardId,
          'type': _type,
          'state': _state,
          'occurredOn': ledgerDay(_date),
          'money': {
            'amount': _value('amount'),
            'currency': _value('currency').toUpperCase(),
          },
          'original': _type == 'expense' && _value('originalAmount').isNotEmpty
              ? {
                  'amount': _value('originalAmount'),
                  'currency': _value('originalCurrency').toUpperCase(),
                }
              : null,
          'fee': _type == 'expense' && _value('feeAmount').isNotEmpty
              ? {
                  'amount': _value('feeAmount'),
                  'currency': _value('feeCurrency').toUpperCase(),
                  'included': _feeIncluded,
                }
              : null,
          'note': _value('note'),
          'relatedEntryId': _relatedId,
          if (widget.importBill != null) 'sourceBillId': widget.importBill!.id,
        },
        existing: widget.existing,
        requestId: _requestId,
      );
      if (mounted) Navigator.of(context).pop(LedgerEditResult(saved: saved));
    } catch (error) {
      if (mounted) setState(() => _error = ledgerError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || !await _confirmDelete(context, '删除这笔流水？此操作无法撤销。')) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteEntry(widget.existing!);
      if (mounted) Navigator.of(context).pop(const LedgerEditResult());
    } catch (error) {
      if (mounted) setState(() => _error = ledgerError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _moneyFields(
    String amountName,
    String currencyName,
    String label, {
    bool optional = false,
    bool allowZero = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
        final fields = [
          TextFormField(
            key: Key('ledger-$amountName'),
            controller: _fields[amountName],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: largeText ? null : context.tr(label),
              errorMaxLines: 3,
            ),
            validator: (value) =>
                optional && value!.trim().isEmpty ||
                    validLedgerAmount(value!.trim(), allowZero: allowZero)
                ? null
                : context.tr('请输入有效金额（最多 8 位小数）'),
          ),
          TextFormField(
            key: Key('ledger-$currencyName'),
            controller: _fields[currencyName],
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.tr('币种'),
              errorMaxLines: 3,
            ),
            validator: (value) =>
                optional && _value(amountName).isEmpty ||
                    RegExp(
                      r'^[A-Z][A-Z0-9]{1,11}$',
                    ).hasMatch(value!.trim().toUpperCase())
                ? null
                : context.tr('请填写有效币种代码'),
          ),
        ];
        if (constraints.maxWidth < 330 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (largeText) ...[Text(label), const SizedBox(height: 8)],
              fields.first,
              const SizedBox(height: 12),
              fields.last,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: fields.first),
            const SizedBox(width: 12),
            Expanded(child: fields.last),
          ],
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final eligible = widget.cards
        .where(
          (card) =>
              !card.archived ||
              card.id == widget.existing?.userCardId ||
              card.id == widget.related?.userCardId,
        )
        .toList();
    final last4 = widget.importBill?.confirmed.cardLast4;
    final mismatch =
        widget.importBill != null &&
        selected != null &&
        ((last4 != null && last4.isNotEmpty && selected.last4 != last4) ||
            (widget.importBill!.cardBinding.cardId != null &&
                selected.catalogCardId !=
                    widget.importBill!.cardBinding.cardId));
    return PopScope(
      canPop: !_saving,
      child: LedgerScaffold(
        key: const Key('ledger-entry-editor'),
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          ),
          title: Text(widget.existing == null ? '记一笔' : '编辑流水'),
        ),
        body: SafeArea(
          top: false,
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey('ledger-entry-card-$_cardId'),
                      initialValue: selected?.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('个人卡片'),
                      ),
                      validator: (value) =>
                          value == null ? context.tr('请选择个人卡片') : null,
                      items: [
                        for (final card in eligible)
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
                      onChanged: _saving || _relatedId != null
                          ? null
                          : (value) => setState(() {
                              _cardId = value;
                              _reviewed = false;
                            }),
                    ),
                    if (mismatch)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('识别的卡片或末四位与所选卡片不同，请核对。'),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: context.tr('流水类型'),
                      ),
                      items: [
                        for (final item in ledgerTypeLabels.entries.where(
                          (item) =>
                              widget.existing != null ||
                              _relatedId != null ||
                              item.key == 'expense' ||
                              item.key == 'fee',
                        ))
                          DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                      ],
                      onChanged:
                          _saving ||
                              widget.existing != null ||
                              _relatedId != null ||
                              widget.importBill != null
                          ? null
                          : (value) => setState(() => _type = value!),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('发生日期'),
                      subtitle: Text(ledgerDay(_date)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: _saving ? null : _pickDate,
                    ),
                    if (_missingImportDate) const Text('识别账单缺少有效日期，请核对发生日期。'),
                    if (_relatedId != null)
                      Text(
                        widget.related == null
                            ? '已关联原消费'
                            : '${context.tr('关联原消费')} · ${widget.related!.occurredOn} · ${widget.related!.money.label}',
                      ),
                    _moneyFields(
                      'amount',
                      'currency',
                      _type == 'expense' ? '实际扣款金额' : '金额',
                    ),
                    if (_type == 'expense') ...[
                      _moneyFields(
                        'originalAmount',
                        'originalCurrency',
                        '原始消费金额（选填）',
                        optional: true,
                      ),
                      _moneyFields(
                        'feeAmount',
                        'feeCurrency',
                        '手续费金额（选填）',
                        optional: true,
                        allowZero: true,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('手续费已包含在扣款中'),
                        subtitle: const Text('关闭后作为额外扣款计入净支出。'),
                        value: _feeIncluded,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _feeIncluded = value),
                      ),
                      const Text('返现到账后，从消费流水的更多操作中记录返现。'),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: InputDecoration(
                        labelText: context.tr('流水状态'),
                      ),
                      items: [
                        for (final item in ledgerStateLabels.entries)
                          DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _state = value!),
                    ),
                    const SizedBox(height: 8),
                    const Text('仅已入账流水进入月度汇总；预计返现请选择处理中。'),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ledger-note'),
                      controller: _fields['note'],
                      maxLength: 200,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.tr('备注（选填）'),
                        errorMaxLines: 3,
                      ),
                      validator: (value) =>
                          containsSensitiveLedgerText(value ?? '')
                          ? context.tr('请勿填写完整卡号或其他敏感号码')
                          : null,
                    ),
                    if (widget.importBill != null) ...[
                      const Text('请核对手续费是否已含在扣款中；返现需另行确认到账。原始识别账单保持独立保存。'),
                      CheckboxListTile(
                        key: const Key('ledger-import-review'),
                        contentPadding: EdgeInsets.zero,
                        value: _reviewed,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _reviewed = value == true),
                        title: const Text('已核对金额、手续费和卡片归属'),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('ledger-entry-save'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '保存中…' : '保存'),
                    ),
                    if (widget.existing != null)
                      TextButton(
                        onPressed: _saving ? null : _delete,
                        child: const Text('删除流水'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Keep all fields mounted and reveal the first invalid input, even when the
// submit button is several screens below it.
bool _validateForm(GlobalKey<FormState> key) {
  FocusManager.instance.primaryFocus?.unfocus();
  final invalid = key.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  final field = invalid.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!field.mounted) return;
    Scrollable.ensureVisible(
      field.context,
      alignment: .15,
      duration: MediaQuery.disableAnimationsOf(field.context)
          ? Duration.zero
          : MotionTokens.fast,
    );
  });
  return false;
}

Future<bool> _confirmDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(message),
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
    ) ==
    true;
