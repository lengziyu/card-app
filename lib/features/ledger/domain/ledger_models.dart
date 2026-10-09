import 'dart:math';

import 'package:cardfi/features/pro/domain/bill_record.dart';

String ledgerRequestId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String ledgerDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String ledgerMonth(DateTime date) => ledgerDay(date).substring(0, 7);

DateTime? ledgerDateFromText(String? value) {
  // Use the date printed on the bill, without shifting it across a month
  // boundary when an ISO timestamp includes a timezone offset.
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})(?:$|[T ])',
  ).firstMatch(value ?? '');
  if (match == null) return null;
  final date = DateTime.tryParse(match[1]!);
  if (date == null ||
      date.year < 1900 ||
      date.year > 2199 ||
      ledgerDay(date) != match[1]) {
    return null;
  }
  return date;
}

bool validLedgerAmount(String value, {bool allowZero = false}) {
  if (!RegExp(r'^\d{1,12}(?:\.\d{1,8})?$').hasMatch(value)) return false;
  return allowZero || BigInt.parse(value.replaceAll('.', '')) > BigInt.zero;
}

bool containsSensitiveLedgerText(String value) =>
    RegExp(r'(?:[0-9\uFF10-\uFF19][\s\-\uFF0D]?){12,19}').hasMatch(value);

class PersonalCard {
  const PersonalCard({
    required this.id,
    required this.catalogCardId,
    required this.productName,
    required this.nickname,
    required this.last4,
    required this.form,
    required this.archived,
    required this.revision,
  });
  factory PersonalCard.fromJson(Map<String, dynamic> json) => PersonalCard(
    id: json['id'] as String,
    catalogCardId: json['catalogCardId'] as String,
    productName: json['productName'] as String,
    nickname: json['nickname'] as String? ?? '',
    last4: RegExp(r'^\d{4}$').hasMatch(json['last4']?.toString() ?? '')
        ? json['last4'] as String
        : '',
    form: json['form'] as String? ?? 'unspecified',
    archived: json['archived'] == true,
    revision: json['revision'] as int,
  );
  final String id, catalogCardId, productName, nickname, last4, form;
  final bool archived;
  final int revision;
  String get title => nickname.isEmpty ? productName : nickname;
  String get label => [title, if (last4.isNotEmpty) '•••• $last4'].join(' · ');
  // Keep the disambiguating digits visible when a compact selector truncates.
  String get selectionLabel =>
      [if (last4.isNotEmpty) '•••• $last4', title].join(' · ');
  Map<String, Object?> toInput() => {
    'catalogCardId': catalogCardId,
    'productName': productName,
    'nickname': nickname,
    'last4': last4,
    'form': form,
    'archived': archived,
  };
}

class LedgerMoney {
  const LedgerMoney(this.amount, this.currency);
  factory LedgerMoney.fromJson(Map<String, dynamic> json) =>
      LedgerMoney(json['amount'] as String, json['currency'] as String);
  final String amount, currency;
  String get label => '$amount $currency';
  Map<String, Object?> toJson() => {'amount': amount, 'currency': currency};
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.userCardId,
    required this.type,
    required this.state,
    required this.occurredOn,
    required this.money,
    required this.note,
    required this.revision,
    this.original,
    this.fee,
    this.feeIncluded = true,
    this.relatedEntryId,
    this.sourceBillId,
    this.source = 'manual',
    this.snapshotLabel = '',
  });
  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final snapshot = json['cardSnapshot'] as Map<String, dynamic>? ?? {};
    final last4 = snapshot['last4']?.toString() ?? '';
    final nickname = snapshot['nickname']?.toString() ?? '';
    return LedgerEntry(
      id: json['id'] as String,
      userCardId: json['userCardId'] as String,
      type: json['type'] as String,
      state: json['state'] as String,
      occurredOn: json['occurredOn'] as String,
      money: LedgerMoney.fromJson(json['money'] as Map<String, dynamic>),
      original: json['original'] == null
          ? null
          : LedgerMoney.fromJson(json['original'] as Map<String, dynamic>),
      fee: json['fee'] == null
          ? null
          : LedgerMoney.fromJson(json['fee'] as Map<String, dynamic>),
      feeIncluded: (json['fee'] as Map<String, dynamic>?)?['included'] == true,
      note: json['note'] as String? ?? '',
      revision: json['revision'] as int,
      relatedEntryId: json['relatedEntryId'] as String?,
      sourceBillId: json['sourceBillId'] as String?,
      source: json['source'] as String? ?? 'manual',
      snapshotLabel: [
        nickname.isNotEmpty
            ? nickname
            : snapshot['productName']?.toString() ?? '',
        if (RegExp(r'^\d{4}$').hasMatch(last4)) '•••• $last4',
      ].join(' · '),
    );
  }
  final String id,
      userCardId,
      type,
      state,
      occurredOn,
      note,
      source,
      snapshotLabel;
  final int revision;
  final LedgerMoney money;
  final LedgerMoney? original, fee;
  final bool feeIncluded;
  final String? relatedEntryId, sourceBillId;
  bool get isCredit => type == 'refund' || type == 'cashback';
  Map<String, Object?> toInput() => {
    'userCardId': userCardId,
    'type': type,
    'state': state,
    'occurredOn': occurredOn,
    'money': money.toJson(),
    'original': original?.toJson(),
    'fee': fee == null ? null : {...fee!.toJson(), 'included': feeIncluded},
    'note': note,
    'relatedEntryId': relatedEntryId,
  };
}

const ledgerTypeLabels = {
  'expense': '消费',
  'refund': '退款',
  'fee': '手续费',
  'cashback': '返现',
};
const ledgerStateLabels = {
  'draft': '待确认',
  'pending': '处理中',
  'posted': '已入账',
  'failed': '失败',
};

class LedgerPage {
  const LedgerPage(this.entries, this.nextCursor);
  final List<LedgerEntry> entries;
  final String? nextCursor;
}

class LedgerSummary {
  const LedgerSummary(this.currencies, this.pendingCount);
  factory LedgerSummary.fromJson(Map<String, dynamic> json) => LedgerSummary(
    (json['currencies'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(),
    json['pendingCount'] as int? ?? 0,
  );
  final List<Map<String, dynamic>> currencies;
  final int pendingCount;
}

/// A recommendation, never an automatic binding: last four digits can collide.
List<PersonalCard> suggestedBillCards(
  List<PersonalCard> cards,
  BillRecord bill,
) => cards
    .where(
      (card) =>
          !card.archived &&
          (bill.cardBinding.cardId == null ||
              card.catalogCardId == bill.cardBinding.cardId) &&
          (bill.confirmed.cardLast4 == null ||
              bill.confirmed.cardLast4!.isEmpty ||
              card.last4 == bill.confirmed.cardLast4),
    )
    .toList();
