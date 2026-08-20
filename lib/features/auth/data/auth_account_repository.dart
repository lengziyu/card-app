import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';

class AuthAccountRepository {
  factory AuthAccountRepository(
    ApiClient client, {
    required Future<String?> Function() accessTokenProvider,
  }) => AuthAccountRepository._(client, accessTokenProvider);

  AuthAccountRepository._(this._client, this._accessTokenProvider);

  static const _accountPath = String.fromEnvironment(
    'AUTH_ACCOUNT_PATH',
    defaultValue: '/api/auth/account',
  );

  final ApiClient _client;
  final Future<String?> Function() _accessTokenProvider;

  Future<String?> purchaseApplicationUserName() async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) return null;
    try {
      final response = jsonObject(
        await _client.get(
          _accountPath,
          headers: {'authorization': 'Bearer $token'},
        ),
        label: '账号资料',
      );
      final value = response['purchaseApplicationUserName']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAccount() async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '请重新登录后再删除账号');
    }
    await _client.delete(
      _accountPath,
      headers: {'authorization': 'Bearer $token'},
    );
  }
}
