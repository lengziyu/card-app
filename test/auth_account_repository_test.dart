import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/auth/data/auth_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads the server-generated purchase account UUID', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'purchaseApplicationUserName':
                '2f56f57d-f0df-4e60-ae31-228f92bbca47',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    final repository = AuthAccountRepository(
      client,
      accessTokenProvider: () async => 'firebase-id-token',
    );

    final value = await repository.purchaseApplicationUserName();

    expect(captured.url.path, '/api/auth/account');
    expect(captured.headers['authorization'], 'Bearer firebase-id-token');
    expect(value, '2f56f57d-f0df-4e60-ae31-228f92bbca47');
    client.close();
  });

  test('does not call the account endpoint without a verified token', () async {
    var requested = false;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    final repository = AuthAccountRepository(
      client,
      accessTokenProvider: () async => null,
    );

    expect(await repository.purchaseApplicationUserName(), isNull);
    expect(requested, isFalse);
    client.close();
  });

  test('deletes the account with the verified Firebase token', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );
    final repository = AuthAccountRepository(
      client,
      accessTokenProvider: () async => 'firebase-id-token',
    );

    await repository.deleteAccount();

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/auth/account');
    expect(captured.headers['authorization'], 'Bearer firebase-id-token');
    client.close();
  });

  test(
    'reports additive client context with the authenticated token',
    () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );
      final repository = AuthAccountRepository(
        client,
        accessTokenProvider: () async => 'supabase-access-token',
      );

      await repository.reportClientContext(
        platform: 'ios',
        authMethod: 'email_otp',
        isRegistration: true,
        appVersion: '0.1.1',
        appBuildNumber: '16',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/auth/client-context');
      expect(captured.headers['authorization'], 'Bearer supabase-access-token');
      expect(jsonDecode(captured.body), {
        'platform': 'ios',
        'authMethod': 'email_otp',
        'isRegistration': true,
        'appVersion': '0.1.1',
        'appBuildNumber': '16',
      });
      client.close();
    },
  );

  test('skips client context reporting without a token', () async {
    var requested = false;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    final repository = AuthAccountRepository(
      client,
      accessTokenProvider: () async => null,
    );

    await repository.reportClientContext(
      platform: 'android',
      authMethod: 'session_restore',
      isRegistration: false,
      appVersion: '0.1.1',
      appBuildNumber: '16',
    );

    expect(requested, isFalse);
    client.close();
  });

  test('registers an Apple authorization code for later revocation', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );
    final repository = AuthAccountRepository(
      client,
      accessTokenProvider: () async => 'supabase-access-token',
    );

    await repository.registerAppleAuthorizationCode('apple-code');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/auth/apple-credential');
    expect(captured.headers['authorization'], 'Bearer supabase-access-token');
    expect(jsonDecode(captured.body), {'authorizationCode': 'apple-code'});
    client.close();
  });

  test(
    'revokes the stored Apple credential before identity unlinking',
    () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );
      final repository = AuthAccountRepository(
        client,
        accessTokenProvider: () async => 'supabase-access-token',
      );

      await repository.revokeAppleCredential();

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/api/auth/apple-credential');
      expect(captured.headers['authorization'], 'Bearer supabase-access-token');
      client.close();
    },
  );
}
