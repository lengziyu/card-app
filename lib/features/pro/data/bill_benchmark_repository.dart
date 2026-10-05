import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';

class BillBenchmarkQuote {
  const BillBenchmarkQuote({
    required this.from,
    required this.to,
    required this.rate,
    required this.sourceLabel,
    required this.updatedAt,
  });

  final String from;
  final String to;
  final String rate;
  final String sourceLabel;
  final DateTime? updatedAt;

  String get rateLabel => '1 $from = $rate $to';
}

class BillBenchmarkRepository {
  BillBenchmarkRepository(this._cardApiClient, {ApiClient? fiatApiClient})
    : _fiatApiClient =
          fiatApiClient ?? ApiClient(baseUrl: 'https://api.frankfurter.dev/v2'),
      _ownsFiatApiClient = fiatApiClient == null;

  final ApiClient _cardApiClient;
  final ApiClient _fiatApiClient;
  final bool _ownsFiatApiClient;

  Future<BillBenchmarkQuote> loadCurrent(BillExtraction extraction) async {
    final from = extraction.original.currency?.trim().toUpperCase();
    final to = extraction.deduction.currency?.trim().toUpperCase();
    return loadCurrentPair(from: from, to: to);
  }

  Future<BillBenchmarkQuote> loadCurrentPair({
    required String? from,
    required String? to,
  }) async {
    final normalizedFrom = from?.trim().toUpperCase();
    final normalizedTo = to?.trim().toUpperCase();
    if (normalizedFrom == null ||
        normalizedFrom.isEmpty ||
        normalizedTo == null ||
        normalizedTo.isEmpty) {
      throw const ApiException(
        code: 'BILL_BENCHMARK_PAIR_MISSING',
        message: '请先确认原始币种和扣款币种',
      );
    }
    if (normalizedFrom == normalizedTo) {
      return BillBenchmarkQuote(
        from: normalizedFrom,
        to: normalizedTo,
        rate: '1',
        sourceLabel: '同币种参考',
        updatedAt: DateTime.now(),
      );
    }

    final needsStablecoinData =
        _stablecoins.contains(normalizedFrom) ||
        _stablecoins.contains(normalizedTo);
    final stablecoinData = needsStablecoinData
        ? await _loadStablecoinData()
        : const _StablecoinData(pricesInUsd: {}, updatedAt: null);
    final sourceLabels = <String>{};
    final fromToUsd = await _currencyToUsd(
      normalizedFrom,
      stablecoinData,
      sourceLabels,
    );
    final toToUsd = await _currencyToUsd(
      normalizedTo,
      stablecoinData,
      sourceLabels,
    );
    final rate = fromToUsd.rate / toToUsd.rate;
    if (!rate.isFinite || rate <= 0) {
      throw const ApiException(
        code: 'BILL_BENCHMARK_INVALID',
        message: '当前参考汇率暂不可用',
      );
    }
    return BillBenchmarkQuote(
      from: normalizedFrom,
      to: normalizedTo,
      rate: _formatRate(rate),
      sourceLabel: sourceLabels.join(' / '),
      updatedAt: _latestDate(
        stablecoinData.updatedAt,
        _latestDate(fromToUsd.updatedAt, toToUsd.updatedAt),
      ),
    );
  }

  Future<_UsdQuote> _currencyToUsd(
    String currency,
    _StablecoinData stablecoinData,
    Set<String> sourceLabels,
  ) async {
    if (currency == 'USD') {
      return const _UsdQuote(rate: 1, updatedAt: null);
    }
    final stablecoinPrice = stablecoinData.pricesInUsd[currency];
    if (stablecoinPrice != null) {
      sourceLabels.add('DefiLlama');
      return _UsdQuote(
        rate: stablecoinPrice,
        updatedAt: stablecoinData.updatedAt,
      );
    }
    final response = jsonObject(
      await _fiatApiClient.get('/rate/$currency/USD'),
      label: '当前法币汇率',
    );
    final rate =
        (response['rate'] as num?)?.toDouble() ??
        double.tryParse(response['rate']?.toString() ?? '');
    if (rate == null || !rate.isFinite || rate <= 0) {
      throw const ApiException(
        code: 'BILL_FIAT_RATE_INVALID',
        message: '当前法币参考汇率暂不可用',
      );
    }
    sourceLabels.add('Frankfurter');
    final date = DateTime.tryParse(response['date']?.toString() ?? '');
    return _UsdQuote(rate: rate, updatedAt: date);
  }

  Future<_StablecoinData> _loadStablecoinData() async {
    final response = jsonObject(
      await _cardApiClient.get('/api/stablecoins'),
      label: '当前稳定币行情',
    );
    final prices = <String, double>{};
    for (final value in jsonList(
      response['assets'] ?? const [],
      label: '稳定币行情',
    )) {
      final asset = jsonObject(value, label: '稳定币行情');
      final symbol = asset['symbol']?.toString().trim().toUpperCase();
      final price = _parsePrice(asset['price']);
      if (symbol != null && symbol.isNotEmpty && price != null && price > 0) {
        prices[symbol] = price;
      }
    }
    for (final symbol in _stablecoins) {
      if (prices.containsKey(symbol)) continue;
      if (symbol == 'USD') prices[symbol] = 1;
    }
    return _StablecoinData(
      pricesInUsd: prices,
      updatedAt: DateTime.tryParse(response['updatedAt']?.toString() ?? ''),
    );
  }

  void dispose() {
    if (_ownsFiatApiClient) _fiatApiClient.close();
  }
}

class _UsdQuote {
  const _UsdQuote({required this.rate, required this.updatedAt});

  final double rate;
  final DateTime? updatedAt;
}

class _StablecoinData {
  const _StablecoinData({required this.pricesInUsd, required this.updatedAt});

  final Map<String, double> pricesInUsd;
  final DateTime? updatedAt;
}

const _stablecoins = <String>{
  'USDT',
  'USDC',
  'USDS',
  'USDP',
  'PYUSD',
  'FDUSD',
  'RLUSD',
  'USD1',
  'DAI',
};

double? _parsePrice(Object? value) {
  final source = value?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(source ?? '');
}

String _formatRate(double value) => value
    .toStringAsFixed(8)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

DateTime? _latestDate(DateTime? left, DateTime? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left.isAfter(right) ? left : right;
}
