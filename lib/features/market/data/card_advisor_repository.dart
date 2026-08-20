import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/features/market/domain/card_advisor.dart';

class CardAdvisorRepository {
  CardAdvisorRepository(this._apiClient, {required this._accessTokenProvider});

  static const path = '/api/ai/card-advisor';

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;

  Future<CardAdvisorResult> advise(CardAdvisorProfile profile) async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '请先登录后使用 AI精选好卡');
    }
    late final Map<String, Object?> response;
    try {
      response = jsonObject(
        await _apiClient.post(
          path,
          headers: {'authorization': 'Bearer $token'},
          body: {
            'profile': profile.toJson(),
            'aiDataConsent': AiDataConsent.payload(AiDataConsentKind.cardMatch),
          },
          timeout: const Duration(seconds: 35),
        ),
        label: 'AI精选好卡结果',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiException(
          code: 'SERVICE_UNAVAILABLE',
          message: 'AI精选好卡服务尚未部署，请稍后再试。',
        );
      }
      rethrow;
    }
    return CardAdvisorResult.fromJson(
      jsonObject(response['advisor'], label: 'AI精选好卡结果'),
    );
  }
}
