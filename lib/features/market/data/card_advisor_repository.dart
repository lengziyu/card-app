import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/features/market/domain/card_advisor.dart';

class CardAdvisorRepository {
  CardAdvisorRepository(this._apiClient, {required this._accessTokenProvider});

  static const path = '/api/ai/card-advisor';

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;

  Future<CardAdvisorResult> advise(CardAdvisorProfile profile) async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录并完成邮箱验证后使用 AI 选卡',
      );
    }
    final response = jsonObject(
      await _apiClient.post(
        path,
        headers: {'authorization': 'Bearer $token'},
        body: {'profile': profile.toJson()},
        timeout: const Duration(seconds: 35),
      ),
      label: 'AI 选卡结果',
    );
    return CardAdvisorResult.fromJson(
      jsonObject(response['advisor'], label: 'AI 选卡结果'),
    );
  }
}
