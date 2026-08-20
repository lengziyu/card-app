import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';

class ReferralProgramConfiguration {
  const ReferralProgramConfiguration({
    required this.enabled,
    required this.standardInviteThreshold,
    required this.referredFirstThreshold,
    required this.maxRewardMonths,
  });

  factory ReferralProgramConfiguration.fromJson(Map<String, dynamic> json) {
    return ReferralProgramConfiguration(
      enabled: json['enabled'] == true,
      standardInviteThreshold: _positiveInt(
        json['standardInviteThreshold'],
        10,
      ),
      referredFirstThreshold: _positiveInt(json['referredFirstThreshold'], 7),
      maxRewardMonths: _positiveInt(json['maxRewardMonths'], 6),
    );
  }

  final bool enabled;
  final int standardInviteThreshold;
  final int referredFirstThreshold;
  final int maxRewardMonths;
}

class ReferralProfile {
  const ReferralProfile({
    required this.code,
    required this.usedInviteCode,
    required this.activated,
    required this.effectiveInvites,
    required this.nextRewardAt,
    required this.rewardedMonths,
    required this.pendingRewardMonths,
    required this.maxRewardMonths,
    required this.firstRewardInviteCount,
    required this.standardRewardInviteCount,
  });

  factory ReferralProfile.fromJson(Map<String, dynamic> json) {
    return ReferralProfile(
      code: json['code']?.toString() ?? '',
      usedInviteCode: json['usedInviteCode'] == true,
      activated: json['activated'] == true,
      effectiveInvites: _positiveInt(json['effectiveInvites'], 0),
      nextRewardAt: _nullableInt(json['nextRewardAt']),
      rewardedMonths: _positiveInt(json['rewardedMonths'], 0),
      pendingRewardMonths: _positiveInt(json['pendingRewardMonths'], 0),
      maxRewardMonths: _positiveInt(json['maxRewardMonths'], 6),
      firstRewardInviteCount: _positiveInt(json['firstRewardInviteCount'], 10),
      standardRewardInviteCount: _positiveInt(
        json['standardRewardInviteCount'],
        10,
      ),
    );
  }

  final String code;
  final bool usedInviteCode;
  final bool activated;
  final int effectiveInvites;
  final int? nextRewardAt;
  final int rewardedMonths;
  final int pendingRewardMonths;
  final int maxRewardMonths;
  final int firstRewardInviteCount;
  final int standardRewardInviteCount;
}

class ReferralRepository {
  ReferralRepository(this._client, {required this.accessTokenProvider});

  final ApiClient _client;
  final Future<String?> Function() accessTokenProvider;

  Future<ReferralProgramConfiguration> loadConfiguration() async {
    final response = jsonObject(
      await _client.get('/api/referrals/config'),
      label: '邀请计划配置',
    );
    return ReferralProgramConfiguration.fromJson(response);
  }

  Future<ReferralProfile> loadProfile() =>
      _profileRequest('GET', '/api/referrals/me');

  Future<ReferralProfile> bind(String code) => _profileRequest(
    'POST',
    '/api/referrals/bind',
    body: {'code': code.trim().toUpperCase()},
  );

  Future<ReferralProfile> activate() =>
      _profileRequest('POST', '/api/referrals/activate', body: const {});

  Future<ReferralProfile> _profileRequest(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final headers = await _headers();
    final raw = switch (method) {
      'GET' => await _client.get(path, headers: headers),
      'POST' => await _client.post(path, headers: headers, body: body),
      _ => throw StateError('Unsupported referral request method: $method'),
    };
    final response = jsonObject(raw, label: '邀请计划响应');
    return ReferralProfile.fromJson(
      jsonObject(response['referral'], label: '邀请计划资料'),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = (await accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录并完成邮箱验证后使用邀请码。',
      );
    }
    return {'authorization': 'Bearer $token'};
  }
}

int _positiveInt(Object? value, int fallback) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : fallback;
}

int? _nullableInt(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}
