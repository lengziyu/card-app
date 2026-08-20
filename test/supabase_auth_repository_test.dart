import 'dart:convert';

import 'package:cardfi/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
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
}

Map<String, Object?> _sessionJson({
  required String accessToken,
  required String refreshToken,
}) => {
  'access_token': accessToken,
  'expires_in': 3600,
  'refresh_token': refreshToken,
  'token_type': 'bearer',
  'user': {
    'id': 'user-1',
    'email': 'member@example.com',
    'email_confirmed_at': '2026-07-20T00:00:00Z',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{'display_name': 'Member'},
    'aud': 'authenticated',
    'created_at': '2026-07-20T00:00:00Z',
  },
};

String _jwt(DateTime expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
      '${encode({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.signature';
}
