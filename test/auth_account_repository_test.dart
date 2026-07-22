import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/auth/data/auth_account_repository.dart';
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
}
