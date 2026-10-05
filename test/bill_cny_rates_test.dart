import 'package:cardfi/features/pro/domain/bill_cny_rates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates lower loss rate and higher cashback-adjusted rate', () {
    final rates = calculateBillCnyRates(
      currentCnyRate: 6.7172,
      benchmarkExpectedDeduction: 12.29 * 1.00021505,
      actualDeduction: 12.4142,
      cashback: 0.7449,
    );

    expect(rates, isNotNull);
    expect(formatBillCnyRate(rates!.lossAdjusted), '6.6514');
    expect(formatBillCnyRate(rates.cashbackAdjusted!), '7.0760');
    expect(rates.lossAdjusted, lessThan(6.7172));
    expect(rates.cashbackAdjusted, greaterThan(6.7172));
  });

  test('does not invent a cashback rate when cashback is missing', () {
    final rates = calculateBillCnyRates(
      currentCnyRate: 7.2,
      benchmarkExpectedDeduction: 10,
      actualDeduction: 10.1,
    );

    expect(rates, isNotNull);
    expect(rates!.cashbackAdjusted, isNull);
  });
}
