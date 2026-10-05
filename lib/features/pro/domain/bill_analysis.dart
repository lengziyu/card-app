class BillMoney {
  const BillMoney({required this.amount, required this.currency});

  factory BillMoney.fromJson(Map<String, dynamic> json) => BillMoney(
    amount: json['amount']?.toString(),
    currency: json['currency']?.toString(),
  );

  final String? amount;
  final String? currency;

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

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

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'amount': amount,
    'currency': currency,
  };

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

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'rate': rate};

  String get label => from == null || to == null || rate == null
      ? '未识别'
      : '1 $from = $rate $to';
}

class BillCashback {
  const BillCashback({
    required this.label,
    required this.rate,
    required this.amount,
    required this.currency,
  });

  factory BillCashback.fromJson(Map<String, dynamic> json) => BillCashback(
    label: json['label']?.toString(),
    rate: json['rate']?.toString(),
    amount: json['amount']?.toString(),
    currency: json['currency']?.toString(),
  );

  const BillCashback.empty()
    : label = null,
      rate = null,
      amount = null,
      currency = null;

  final String? label;
  final String? rate;
  final String? amount;
  final String? currency;

  bool get hasValue => rate != null || amount != null;

  String get valueLabel {
    if (amount != null) return '$amount ${currency ?? ''}'.trim();
    if (rate != null) return '$rate%';
    return '未识别';
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'rate': rate,
    'amount': amount,
    'currency': currency,
  };
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
    required this.cashback,
    required this.fees,
    required this.exchangeRates,
    required this.cardLast4,
    required this.confidence,
    required this.needsReview,
  });

  factory BillExtraction.fromJson(Map<String, dynamic> json) {
    final cardName = json['cardName']?.toString();
    final deduction = BillMoney.fromJson(_map(json['deduction']));
    final cashback = _normalizePointsCashback(
      BillCashback.fromJson(_map(json['cashback'])),
      cardName: cardName,
      deduction: deduction,
    );
    return BillExtraction(
      provider: json['provider']?.toString(),
      cardName: cardName,
      status: json['status']?.toString() ?? 'unknown',
      transactionAt: json['transactionAt']?.toString(),
      original: BillMoney.fromJson(_map(json['original'])),
      settlement: BillMoney.fromJson(_map(json['settlement'])),
      deduction: deduction,
      cashback: cashback,
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
  }

  final String? provider;
  final String? cardName;
  final String status;
  final String? transactionAt;
  final BillMoney original;
  final BillMoney settlement;
  final BillMoney deduction;
  final BillCashback cashback;
  final List<BillFee> fees;
  final List<BillExchangeRate> exchangeRates;
  final String? cardLast4;
  final double confidence;
  final List<String> needsReview;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'cardName': cardName,
    'status': status,
    'transactionAt': transactionAt,
    'original': original.toJson(),
    'settlement': settlement.toJson(),
    'deduction': deduction.toJson(),
    'cashback': cashback.toJson(),
    'fees': fees.map((item) => item.toJson()).toList(growable: false),
    'exchangeRates': exchangeRates
        .map((item) => item.toJson())
        .toList(growable: false),
    'cardLast4': cardLast4,
    'confidence': confidence,
    'needsReview': needsReview,
  };
}

BillCashback _normalizePointsCashback(
  BillCashback cashback, {
  required String? cardName,
  required BillMoney deduction,
}) {
  final amount = cashback.amount?.trim();
  final deductionAmount = deduction.amount?.trim();
  final currency = cashback.currency?.trim().toUpperCase();
  final deductionCurrency = deduction.currency?.trim().toUpperCase();
  final label = cashback.label?.toLowerCase() ?? '';
  final isPointsLabel = RegExp(r'积分|points?|rewards?').hasMatch(label);
  final isGateCard = cardName?.toLowerCase().contains('gate card') == true;
  if ((!isPointsLabel || !isGateCard) ||
      amount == null ||
      amount != deductionAmount ||
      currency == null ||
      currency != deductionCurrency) {
    return cashback;
  }
  final cashValue = _divideDecimalBy100(amount);
  if (cashValue == null) return cashback;
  return BillCashback(
    label: '积分现金价值',
    rate: '1',
    amount: cashValue,
    currency: currency,
  );
}

String? _divideDecimalBy100(String value) {
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final digits = '${parts[0]}${parts.length == 2 ? parts[1] : ''}';
  final scale = (parts.length == 2 ? parts[1].length : 0) + 2;
  final padded = digits.padLeft(scale + 1, '0');
  final integer = padded.substring(0, padded.length - scale);
  final fraction = padded
      .substring(padded.length - scale)
      .replaceFirst(RegExp(r'0+$'), '');
  return '$integer${fraction.isEmpty ? '' : '.$fraction'}';
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
