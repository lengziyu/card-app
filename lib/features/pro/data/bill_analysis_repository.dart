import 'dart:convert';
import 'dart:typed_data';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/domain/bill_analysis.dart';

class BillAnalysisRepository {
  factory BillAnalysisRepository(
    ApiClient apiClient, {
    required Future<String?> Function() accessTokenProvider,
  }) => BillAnalysisRepository._(apiClient, accessTokenProvider);

  BillAnalysisRepository._(this._apiClient, this._accessTokenProvider);

  static const maxImageBytes = 1_350_000;

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;

  Future<BillAnalysis> analyze({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (imageBytes.isEmpty) {
      throw const ApiException(code: 'BILL_IMAGE_REQUIRED', message: '请选择账单截图');
    }
    if (imageBytes.length > maxImageBytes) {
      throw const ApiException(
        code: 'BILL_IMAGE_TOO_LARGE',
        message: '截图过大，请裁剪或压缩后重试',
      );
    }
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录并确认 Pro 权益后使用账单分析',
      );
    }
    final response = jsonObject(
      await _apiClient.post(
        ProConfig.billAnalysisPath,
        headers: {'authorization': 'Bearer $token'},
        body: {
          'mimeType': mimeType,
          'imageBase64': base64Encode(imageBytes),
          'aiDataConsent': AiDataConsent.payload(AiDataConsentKind.billVision),
        },
        timeout: const Duration(seconds: 45),
      ),
      label: '账单分析',
    );
    return BillAnalysis.fromJson(
      jsonObject(response['analysis'], label: '账单分析结果'),
    );
  }
}
