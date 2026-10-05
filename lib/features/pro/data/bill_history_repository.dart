import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';

class BillRecordPage {
  const BillRecordPage({required this.records, required this.nextCursor});

  final List<BillRecord> records;
  final String? nextCursor;
}

class BillHistoryRepository {
  factory BillHistoryRepository(
    ApiClient apiClient, {
    required Future<String?> Function() accessTokenProvider,
  }) => BillHistoryRepository._(apiClient, accessTokenProvider);

  BillHistoryRepository._(this._apiClient, this._accessTokenProvider);

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;

  Future<Map<String, String>> _headers() async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '请先登录后使用历史账单');
    }
    return {'authorization': 'Bearer $token'};
  }

  Future<BillRecordPage> list({String? cursor, int limit = 50}) async {
    final response = jsonObject(
      await _apiClient.get(
        ProConfig.billRecordsPath,
        query: {'limit': limit, 'cursor': cursor},
        headers: await _headers(),
      ),
      label: '历史账单',
    );
    final values = jsonList(response['records'], label: '历史账单列表');
    return BillRecordPage(
      records: values
          .map((item) => BillRecord.fromJson(jsonObject(item, label: '账单记录')))
          .toList(growable: false),
      nextCursor: response['nextCursor']?.toString(),
    );
  }

  Future<BillRecord> createDraft(
    BillAnalysis analysis, {
    String? benchmarkRate,
  }) async {
    final response = jsonObject(
      await _apiClient.post(
        ProConfig.billRecordsPath,
        headers: await _headers(),
        body: {
          'status': 'draft',
          'recognized': analysis.extraction.toJson(),
          'confirmed': analysis.extraction.toJson(),
          'calculationInputs': BillCalculationInputs(
            benchmarkRate: benchmarkRate,
            // A recognized cashback amount is the actual result. Do not also
            // treat its OCR ratio as the card's advertised percentage.
            cashbackRate: analysis.extraction.cashback.amount == null
                ? analysis.extraction.cashback.rate
                : null,
            cashbackAmount: BillMoney(
              amount:
                  analysis.extraction.cashback.currency ==
                      analysis.extraction.deduction.currency
                  ? analysis.extraction.cashback.amount
                  : null,
              currency:
                  analysis.extraction.cashback.currency ==
                      analysis.extraction.deduction.currency
                  ? analysis.extraction.cashback.currency
                  : null,
            ),
          ).toJson(),
          'cardBinding': const BillCardBinding.unbound().toJson(),
        },
      ),
      label: '保存账单',
    );
    return BillRecord.fromJson(jsonObject(response['record'], label: '账单记录'));
  }

  Future<BillRecord> update({
    required BillRecord record,
    required BillExtraction confirmed,
    required BillCalculationInputs calculationInputs,
    required BillCardBinding cardBinding,
    required bool confirmedByUser,
  }) async {
    final response = jsonObject(
      await _apiClient.patch(
        '${ProConfig.billRecordsPath}/${Uri.encodeComponent(record.id)}',
        headers: await _headers(),
        body: {
          'expectedRevision': record.revision,
          'status': confirmedByUser ? 'confirmed' : 'draft',
          'confirmed': confirmed.toJson(),
          'calculationInputs': calculationInputs.toJson(),
          'cardBinding': cardBinding.toJson(),
        },
      ),
      label: '更新账单',
    );
    return BillRecord.fromJson(jsonObject(response['record'], label: '账单记录'));
  }

  Future<void> delete(String id) async {
    await _apiClient.delete(
      '${ProConfig.billRecordsPath}/${Uri.encodeComponent(id)}',
      headers: await _headers(),
    );
  }
}
