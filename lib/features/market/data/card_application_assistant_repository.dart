import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/features/market/domain/card_application_assistant.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';

class CardApplicationAssistantRepository {
  factory CardApplicationAssistantRepository(
    ApiClient apiClient, {
    required Future<String?> Function() accessTokenProvider,
  }) => CardApplicationAssistantRepository._(apiClient, accessTokenProvider);

  CardApplicationAssistantRepository._(
    this._apiClient,
    this._accessTokenProvider,
  );

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;

  Future<CardApplicationAssistantResult> prepare(
    CardApplicationProfile profile,
  ) async {
    if (profile.cardId.trim().isEmpty) {
      throw const ApiException(
        code: 'APPLICATION_CARD_REQUIRED',
        message: '请先选择要了解的卡片',
      );
    }
    if (containsSensitiveInput(profile.question)) {
      throw const ApiException(
        code: 'SENSITIVE_INPUT',
        message: '请删除证件号、卡号、密码、验证码或助记词后再继续',
      );
    }
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录后使用 AI 协助开卡',
      );
    }
    late final Map<String, Object?> response;
    try {
      response = jsonObject(
        await _apiClient.post(
          ProConfig.applicationAssistantPath,
          headers: {'authorization': 'Bearer $token'},
          body: {
            'profile': profile.toJson(),
            'aiDataConsent': AiDataConsent.payload(
              AiDataConsentKind.applicationPrep,
            ),
          },
          timeout: const Duration(seconds: 45),
        ),
        label: 'AI 协助开卡结果',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiException(
          code: 'SERVICE_UNAVAILABLE',
          message: 'AI 协助开卡服务尚未部署，请稍后再试。',
        );
      }
      rethrow;
    }
    return CardApplicationAssistantResult.fromJson(
      jsonObject(response['assistant'], label: 'AI 协助开卡结果'),
    );
  }

  static bool containsSensitiveInput(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(
      r'(密码|验证码|助记词|私钥|cvv|cvc|pin|password|otp)',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    return RegExp(r'(?<!\d)\d{8,19}(?!\d)').hasMatch(text);
  }
}
