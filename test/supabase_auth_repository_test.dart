import 'dart:convert';

import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/data/supabase_auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  test('email OTP restores the existing Supabase user id', () async {
    final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
    var otpRequests = 0;
    var verifyRequests = 0;
    final client = supabase.SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const supabase.AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: supabase.AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/otp') {
          otpRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'member@example.com');
          expect(body['create_user'], isTrue);
          return http.Response(
            '{}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/auth/v1/verify') {
          verifyRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'member@example.com');
          expect(body['token'], '123456');
          return http.Response(
            jsonEncode(
              _sessionJson(
                accessToken: freshToken,
                refreshToken: 'otp-refresh-token',
              ),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAuthRepository(clientOverride: client);

    await repository.sendEmailOtp('Member@Example.com');
    final user = await repository.verifyEmailOtp(
      email: 'Member@Example.com',
      token: '123456',
    );

    expect(user.id, 'user-1');
    expect(user.emailVerified, isTrue);
    expect(otpRequests, 1);
    expect(verifyRequests, 1);
  });

  test(
    'cold start refreshes an expired session before exposing its token',
    () async {
      final expiredToken = _jwt(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
      var refreshRequests = 0;
      final client = supabase.SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          refreshRequests++;
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/v1/token');
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          return http.Response(
            jsonEncode(
              _sessionJson(
                accessToken: freshToken,
                refreshToken: 'rotated-refresh-token',
              ),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode(
          _sessionJson(
            accessToken: expiredToken,
            refreshToken: 'persisted-refresh-token',
          ),
        ),
      );
      final repository = SupabaseAuthRepository(clientOverride: client);

      final user = await repository.initialize();
      final token = await repository.idToken();

      expect(user?.id, 'user-1');
      expect(user?.emailVerified, isTrue);
      expect(token, freshToken);
      expect(refreshRequests, 1);
    },
  );

  test(
    'native Google sends both identity and access tokens to Supabase',
    () async {
      final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
      var tokenRequests = 0;
      final client = supabase.SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            tokenRequests++;
            expect(request.url.queryParameters['grant_type'], 'id_token');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['provider'], 'google');
            expect(body['id_token'], 'google-id-token');
            expect(body['access_token'], 'google-access-token');
            return http.Response(
              jsonEncode(
                _sessionJson(
                  accessToken: freshToken,
                  refreshToken: 'google-refresh-token',
                ),
              ),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAuthRepository(
        clientOverride: client,
        googleCredentialProvider: () async =>
            (idToken: 'google-id-token', accessToken: 'google-access-token'),
      );

      final user = await repository.signInWithGoogle();

      expect(user.id, 'user-1');
      expect(user.emailVerified, isTrue);
      expect(tokenRequests, 1);
    },
  );

  test(
    'identity unlinking keeps another login method on the same user',
    () async {
      final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
      final identities = [_identity('email'), _identity('google')];
      var unlinkRequests = 0;
      final client = supabase.SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.method == 'DELETE' &&
              request.url.path ==
                  '/auth/v1/user/identities/google-identity-id') {
            unlinkRequests++;
            return http.Response(
              '{}',
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
            return http.Response(
              jsonEncode(_userJson([_identity('email')])),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode(
          _sessionJson(
            accessToken: freshToken,
            refreshToken: 'persisted-refresh-token',
            identities: identities,
          ),
        ),
      );
      final repository = SupabaseAuthRepository(clientOverride: client);

      final user = await repository.unlinkGoogleIdentity();

      expect(unlinkRequests, 1);
      expect(user.loginProviders, {AuthLoginProvider.email});
    },
  );

  test('password reset requests the code-only template branch', () async {
    var recoveryRequests = 0;
    final client = supabase.SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const supabase.AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: supabase.AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/auth/v1/recover') {
          recoveryRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'member@example.com');
          expect(
            request.url.queryParameters['redirect_to'],
            'cn.lengziyu.cardapp://auth-callback?mode=password-recovery-otp',
          );
          return http.Response(
            '{}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAuthRepository(clientOverride: client);

    await repository.sendPasswordReset('Member@Example.com');

    expect(recoveryRequests, 1);
  });

  test(
    'six-digit recovery OTP creates the password recovery session',
    () async {
      final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
      var verifyRequests = 0;
      final client = supabase.SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/auth/v1/verify') {
            verifyRequests++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['email'], 'member@example.com');
            expect(body['token'], '123456');
            expect(body['type'], 'recovery');
            return http.Response(
              jsonEncode(
                _sessionJson(
                  accessToken: freshToken,
                  refreshToken: 'recovery-refresh-token',
                  identities: [_identity('email')],
                ),
              ),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAuthRepository(clientOverride: client);

      await repository.verifyPasswordRecoveryOtp(
        email: 'Member@Example.com',
        token: '123456',
      );

      expect(verifyRequests, 1);
      expect(client.auth.currentUser?.id, 'user-1');
    },
  );

  test('password recovery updates the authenticated recovery user', () async {
    final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
    var updateRequests = 0;
    final client = supabase.SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT' && request.url.path == '/auth/v1/user') {
          updateRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['password'], 'new-password');
          return http.Response(
            jsonEncode(_userJson([_identity('email')])),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode(
        _sessionJson(
          accessToken: freshToken,
          refreshToken: 'recovery-refresh-token',
          identities: [_identity('email')],
        ),
      ),
    );
    final repository = SupabaseAuthRepository(clientOverride: client);

    final user = await repository.updateRecoveredPassword('new-password');

    expect(user.id, 'user-1');
    expect(user.email, 'member@example.com');
    expect(updateRequests, 1);
  });

  test(
    'password recovery explains when the new password is unchanged',
    () async {
      final freshToken = _jwt(DateTime.now().add(const Duration(hours: 1)));
      final client = supabase.SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.method == 'PUT' && request.url.path == '/auth/v1/user') {
            return http.Response(
              jsonEncode({
                'code': 'same_password',
                'msg':
                    'New password should be different from the old password.',
              }),
              422,
              headers: const {
                'content-type': 'application/json',
                'x-supabase-api-version': '2024-01-01',
              },
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode(
          _sessionJson(
            accessToken: freshToken,
            refreshToken: 'recovery-refresh-token',
            identities: [_identity('email')],
          ),
        ),
      );
      final repository = SupabaseAuthRepository(clientOverride: client);

      await expectLater(
        repository.updateRecoveredPassword('unchanged-password'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.code,
            'code',
            'SAME_PASSWORD',
          ),
        ),
      );
    },
  );
}

Map<String, Object?> _sessionJson({
  required String accessToken,
  required String refreshToken,
  List<Map<String, Object?>> identities = const [],
}) => {
  'access_token': accessToken,
  'expires_in': 3600,
  'refresh_token': refreshToken,
  'token_type': 'bearer',
  'user': _userJson(identities),
};

Map<String, Object?> _userJson(List<Map<String, Object?>> identities) => {
  'id': 'user-1',
  'email': 'member@example.com',
  'email_confirmed_at': '2026-07-20T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{'display_name': 'Member'},
  'aud': 'authenticated',
  'created_at': '2026-07-20T00:00:00Z',
  'identities': identities,
};

Map<String, Object?> _identity(String provider) => {
  'id': '$provider-provider-id',
  'user_id': 'user-1',
  'identity_data': <String, Object?>{},
  'identity_id': '$provider-identity-id',
  'provider': provider,
  'created_at': '2026-07-20T00:00:00Z',
};

String _jwt(DateTime expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
      '${encode({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.signature';
}
