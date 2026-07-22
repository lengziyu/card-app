class BillMoney {
  const BillMoney({required this.amount, required this.currency});

  factory BillMoney.fromJson(Map<String, dynamic> json) => BillMoney(
    amount: json['amount']?.toString(),
    currency: json['currency']?.toString(),
  );

  final String? amount;
  final String? currency;

  bool get isComplete =>
      amount?.isNotEmpty == true && currency?.isNotEmpty == true;

  String get label => isComplete ? '$amount $currency' : '未识别';
}

class BillFee {
  const BillFee({
    required this.type,
    required this.label,
    required this.amount,
    required this.currency,
  });

  factory BillFee.fromJson(Map<String, dynamic> json) => BillFee(
    type: json['type']?.toString() ?? 'other',
    label: json['label']?.toString(),
    amount: json['amount']?.toString(),
    currency: json['currency']?.toString(),
  );

  final String type;
  final String? label;
  final String? amount;
  final String? currency;

  String get valueLabel =>
      amount == null ? '未识别' : '$amount ${currency ?? ''}'.trim();
}

class BillExchangeRate {
  const BillExchangeRate({
    required this.from,
    required this.to,
    required this.rate,
  });

  factory BillExchangeRate.fromJson(Map<String, dynamic> json) =>
      BillExchangeRate(
        from: json['from']?.toString(),
        to: json['to']?.toString(),
        rate: json['rate']?.toString(),
      );

  final String? from;
  final String? to;
  final String? rate;

  String get label => from == null || to == null || rate == null
      ? '未识别'
      : '1 $from = $rate $to';
}

class BillExtraction {
  const BillExtraction({
    required this.provider,
    required this.cardName,
    required this.status,
    required this.transactionAt,
    required this.original,
    required this.settlement,
    required this.deduction,
    required this.fees,
    required this.exchangeRates,
    required this.cardLast4,
    required this.confidence,
    required this.needsReview,
  });

  factory BillExtraction.fromJson(Map<String, dynamic> json) => BillExtraction(
    provider: json['provider']?.toString(),
    cardName: json['cardName']?.toString(),
    status: json['status']?.toString() ?? 'unknown',
    transactionAt: json['transactionAt']?.toString(),
    original: BillMoney.fromJson(_map(json['original'])),
    settlement: BillMoney.fromJson(_map(json['settlement'])),
    deduction: BillMoney.fromJson(_map(json['deduction'])),
    fees: _list(
      json['fees'],
    ).map((item) => BillFee.fromJson(_map(item))).toList(growable: false),
    exchangeRates: _list(json['exchangeRates'])
        .map((item) => BillExchangeRate.fromJson(_map(item)))
        .toList(growable: false),
    cardLast4: json['cardLast4']?.toString(),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    needsReview: _list(
      json['needsReview'],
    ).map((item) => item.toString()).toList(growable: false),
  );

  final String? provider;
  final String? cardName;
  final String status;
  final String? transactionAt;
  final BillMoney original;
  final BillMoney settlement;
  final BillMoney deduction;
  final List<BillFee> fees;
  final List<BillExchangeRate> exchangeRates;
  final String? cardLast4;
  final double confidence;
  final List<String> needsReview;
}

class BillMetrics {
  const BillMetrics({
    required this.effectiveDeductionPerOriginal,
    required this.effectiveRatePair,
    required this.internalExpectedDeduction,
    required this.internalRoundingDifference,
    required this.declaredFeesInDeductionCurrency,
    required this.deductionCurrency,
    required this.marketLoss,
    required this.marketLossRate,
    required this.benchmarkStatus,
  });

  factory BillMetrics.fromJson(Map<String, dynamic> json) => BillMetrics(
    effectiveDeductionPerOriginal: json['effectiveDeductionPerOriginal']
        ?.toString(),
    effectiveRatePair: json['effectiveRatePair']?.toString(),
    internalExpectedDeduction: json['internalExpectedDeduction']?.toString(),
    internalRoundingDifference: json['internalRoundingDifference']?.toString(),
    declaredFeesInDeductionCurrency: json['declaredFeesInDeductionCurrency']
        ?.toString(),
    deductionCurrency: json['deductionCurrency']?.toString(),
    marketLoss: json['marketLoss']?.toString(),
    marketLossRate: json['marketLossRate']?.toString(),
    benchmarkStatus: json['benchmarkStatus']?.toString() ?? 'not_available',
  );

  final String? effectiveDeductionPerOriginal;
  final String? effectiveRatePair;
  final String? internalExpectedDeduction;
  final String? internalRoundingDifference;
  final String? declaredFeesInDeductionCurrency;
  final String? deductionCurrency;
  final String? marketLoss;
  final String? marketLossRate;
  final String benchmarkStatus;
}

class BillAnalysis {
  const BillAnalysis({
    required this.extraction,
    required this.metrics,
    required this.disclaimer,
  });

  factory BillAnalysis.fromJson(Map<String, dynamic> json) => BillAnalysis(
    extraction: BillExtraction.fromJson(_map(json['extraction'])),
    metrics: BillMetrics.fromJson(_map(json['metrics'])),
    disclaimer: json['disclaimer']?.toString() ?? '',
  );

  final BillExtraction extraction;
  final BillMetrics metrics;
  final String disclaimer;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> _list(Object? value) => value is List<dynamic> ? value : const [];
