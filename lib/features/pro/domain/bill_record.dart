import 'package:cardfi/features/pro/domain/bill_analysis.dart';

class BillCardBinding {
  const BillCardBinding({required this.cardId, required this.cardNameSnapshot});

  factory BillCardBinding.fromJson(Map<String, dynamic> json) =>
      BillCardBinding(
        cardId: json['cardId']?.toString(),
        cardNameSnapshot: json['cardNameSnapshot']?.toString(),
      );

  const BillCardBinding.unbound() : cardId = null, cardNameSnapshot = null;

  final String? cardId;
  final String? cardNameSnapshot;

  bool get isBound => cardId?.isNotEmpty == true;

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'cardNameSnapshot': cardNameSnapshot,
  };
}

class BillCalculationInputs {
  const BillCalculationInputs({
    required this.benchmarkRate,
    required this.cashbackRate,
    required this.cashbackAmount,
  });

  factory BillCalculationInputs.fromJson(Map<String, dynamic> json) =>
      BillCalculationInputs(
        benchmarkRate: json['benchmarkRate']?.toString(),
        cashbackRate: json['cashbackRate']?.toString(),
        cashbackAmount: BillMoney.fromJson(_map(json['cashbackAmount'])),
      );

  const BillCalculationInputs.empty()
    : benchmarkRate = null,
      cashbackRate = null,
      cashbackAmount = const BillMoney(amount: null, currency: null);

  final String? benchmarkRate;
  final String? cashbackRate;
  final BillMoney cashbackAmount;

  Map<String, dynamic> toJson() => {
    'benchmarkRate': benchmarkRate,
    'cashbackRate': cashbackRate,
    'cashbackAmount': cashbackAmount.toJson(),
  };
}

class BillRecordMetrics {
  const BillRecordMetrics({
    required this.base,
    required this.benchmarkRate,
    required this.benchmarkExpectedDeduction,
    required this.cashbackValue,
    required this.netLoss,
    required this.netLossRate,
  });

  factory BillRecordMetrics.fromJson(Map<String, dynamic> json) =>
      BillRecordMetrics(
        base: BillMetrics.fromJson(json),
        benchmarkRate: json['benchmarkRate']?.toString(),
        benchmarkExpectedDeduction: json['benchmarkExpectedDeduction']
            ?.toString(),
        cashbackValue: json['cashbackValue']?.toString(),
        netLoss: json['netLoss']?.toString(),
        netLossRate: json['netLossRate']?.toString(),
      );

  final BillMetrics base;
  final String? benchmarkRate;
  final String? benchmarkExpectedDeduction;
  final String? cashbackValue;
  final String? netLoss;
  final String? netLossRate;
}

class BillRecord {
  const BillRecord({
    required this.id,
    required this.status,
    required this.recognized,
    required this.confirmed,
    required this.calculationInputs,
    required this.metrics,
    required this.cardBinding,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillRecord.fromJson(Map<String, dynamic> json) {
    final recognizedJson = _map(json['recognized']);
    final recognized = BillExtraction.fromJson(recognizedJson);
    final confirmedJson = Map<String, dynamic>.from(_map(json['confirmed']));
    // Older drafts may lose the confirmed card name even though the original
    // recognition still identifies it. Restore that context before applying
    // compatibility normalization (notably Gate points -> cash value).
    if ((confirmedJson['cardName']?.toString().trim().isEmpty ?? true) &&
        recognized.cardName?.trim().isNotEmpty == true) {
      confirmedJson['cardName'] = recognized.cardName;
    }
    final confirmed = BillExtraction.fromJson(confirmedJson);
    final rawRecognizedCashback = BillCashback.fromJson(
      _map(recognizedJson['cashback']),
    );
    final rawConfirmedCashback = BillCashback.fromJson(
      _map(confirmedJson['cashback']),
    );
    var inputs = BillCalculationInputs.fromJson(
      _map(json['calculationInputs']),
    );
    var metrics = BillRecordMetrics.fromJson(_map(json['metrics']));
    final pointsEvidence = _isPointsCashback(
      rawRecognizedCashback,
      cardName: recognized.cardName,
      deduction: recognized.deduction,
    );
    final pointsCashbackCorrected =
        pointsEvidence && confirmed.cashback.amount != null;
    if (pointsCashbackCorrected) {
      final correctedAmount = confirmed.cashback.amount!;
      final correctedCurrency = confirmed.cashback.currency;
      inputs = BillCalculationInputs(
        benchmarkRate: inputs.benchmarkRate,
        // The OCR-derived points ratio is an actual result, not the card's
        // advertised cashback rate. Leave the latter empty for user input.
        cashbackRate:
            _isOcrDerivedPointsRate(
                  inputs.cashbackRate,
                  rawRecognizedCashback,
                ) ||
                _isOcrDerivedPointsRate(
                  inputs.cashbackRate,
                  rawConfirmedCashback,
                )
            ? null
            : inputs.cashbackRate,
        cashbackAmount: BillMoney(
          amount: correctedAmount,
          currency: correctedCurrency,
        ),
      );
      final netLoss = _subtractDecimal(
        metrics.base.marketLoss,
        correctedAmount,
      );
      metrics = BillRecordMetrics(
        base: metrics.base,
        benchmarkRate: metrics.benchmarkRate,
        benchmarkExpectedDeduction: metrics.benchmarkExpectedDeduction,
        cashbackValue: correctedAmount,
        netLoss: netLoss,
        netLossRate: metrics.netLossRate,
      );
    }
    return BillRecord(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() == 'confirmed' ? 'confirmed' : 'draft',
      recognized: recognized,
      confirmed: confirmed,
      calculationInputs: inputs,
      metrics: metrics,
      cardBinding: BillCardBinding.fromJson(_map(json['cardBinding'])),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String status;
  final BillExtraction recognized;
  final BillExtraction confirmed;
  final BillCalculationInputs calculationInputs;
  final BillRecordMetrics metrics;
  final BillCardBinding cardBinding;
  final int revision;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

bool _isPointsCashback(
  BillCashback cashback, {
  required String? cardName,
  required BillMoney deduction,
}) {
  final label = cashback.label?.toLowerCase() ?? '';
  final isPointsLabel = RegExp(r'积分|points?|rewards?').hasMatch(label);
  final isNormalizedCashValue = RegExp(
    r'积分现金价值|points? cash value|rewards? cash value',
  ).hasMatch(label);
  final isGateCard = cardName?.toLowerCase().contains('gate card') == true;
  return isPointsLabel &&
      isGateCard &&
      (_decimalEquals(cashback.amount, deduction.amount) ||
          isNormalizedCashValue) &&
      cashback.currency?.trim().toUpperCase() ==
          deduction.currency?.trim().toUpperCase();
}

bool _isOcrDerivedPointsRate(String? inputRate, BillCashback cashback) {
  if (inputRate == null) return false;
  final rawRate = cashback.rate;
  if (!_decimalEquals(rawRate, '1') && _decimalEquals(inputRate, rawRate)) {
    return true;
  }
  final label = cashback.label?.toLowerCase() ?? '';
  final isNormalizedCashValue = RegExp(
    r'积分现金价值|points? cash value|rewards? cash value',
  ).hasMatch(label);
  return isNormalizedCashValue && _decimalEquals(inputRate, cashback.amount);
}

bool _decimalEquals(String? left, String? right) {
  final leftValue = double.tryParse(left ?? '');
  final rightValue = double.tryParse(right ?? '');
  return leftValue != null &&
      rightValue != null &&
      (leftValue - rightValue).abs() < 0.00000001;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _subtractDecimal(String? left, String right) {
  final leftValue = double.tryParse(left ?? '');
  final rightValue = double.tryParse(right);
  if (leftValue == null || rightValue == null) return null;
  final value = leftValue - rightValue;
  return value
      .toStringAsFixed(8)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
