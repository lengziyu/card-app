class BillCnyRates {
  const BillCnyRates({
    required this.lossAdjusted,
    required this.cashbackAdjusted,
  });

  /// 每 1 个扣款币种在计入汇率损耗后的人民币购买力。
  final double lossAdjusted;

  /// 每 1 个净扣款币种在继续计入实际返现后的人民币购买力。
  final double? cashbackAdjusted;
}

BillCnyRates? calculateBillCnyRates({
  required double? currentCnyRate,
  required double? benchmarkExpectedDeduction,
  required double? actualDeduction,
  double? cashback,
}) {
  if (!_isPositiveFinite(currentCnyRate) ||
      !_isPositiveFinite(benchmarkExpectedDeduction) ||
      !_isPositiveFinite(actualDeduction)) {
    return null;
  }

  final lossAdjusted =
      currentCnyRate! * benchmarkExpectedDeduction! / actualDeduction!;
  final netDeduction = cashback == null ? null : actualDeduction - cashback;
  final cashbackAdjusted = _isPositiveFinite(netDeduction)
      ? currentCnyRate * benchmarkExpectedDeduction / netDeduction!
      : null;
  return BillCnyRates(
    lossAdjusted: lossAdjusted,
    cashbackAdjusted: cashbackAdjusted,
  );
}

String formatBillCnyRate(double value, {int maxFractionDigits = 4}) {
  return value.toStringAsFixed(maxFractionDigits);
}

bool _isPositiveFinite(double? value) =>
    value != null && value.isFinite && value > 0;
