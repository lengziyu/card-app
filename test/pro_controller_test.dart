import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/data/pro_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('referral rewards stay disabled unless explicitly enabled', () {
    expect(ProConfig.referralProgramEnabled, isFalse);
  });

  test(
    'a restored account can recover Pro after an initially empty token',
    () async {
      String? accessToken;
      final requests = <http.Request>[];
      final apiClient = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/pro/config') {
            return _jsonResponse(_enabledConfiguration);
          }
          expect(request.url.path, '/api/pro/entitlement');
          expect(request.headers['authorization'], 'Bearer restored-token');
          return _jsonResponse(_activeEntitlement);
        }),
      );
      final controller = ProController(
        apiClient: apiClient,
        accessTokenProvider: () async => accessToken,
      );
      addTearDown(() {
        controller.dispose();
        apiClient.close();
      });

      await controller.initialize();
      expect(controller.accountConnected, isFalse);
      expect(controller.isActive, isFalse);
      expect(requests, isEmpty);

      accessToken = 'restored-token';
      await controller.refreshEntitlement();

      expect(controller.accountConnected, isTrue);
      expect(controller.isActive, isTrue);
      expect(requests.map((request) => request.url.path), [
        '/api/pro/config',
        '/api/pro/entitlement',
      ]);
    },
  );

  test('sign-out clears cached Pro without depending on the network', () async {
    String? accessToken = 'member-token';
    var requestCount = 0;
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestCount++;
        return request.url.path == '/api/pro/config'
            ? _jsonResponse(_enabledConfiguration)
            : _jsonResponse(_activeEntitlement);
      }),
    );
    final controller = ProController(
      apiClient: apiClient,
      accessTokenProvider: () async => accessToken,
    );
    addTearDown(() {
      controller.dispose();
      apiClient.close();
    });

    await controller.initialize();
    expect(controller.isActive, isTrue);
    expect(requestCount, 2);

    accessToken = null;
    await controller.refreshEntitlement();

    expect(controller.accountConnected, isFalse);
    expect(controller.isActive, isFalse);
    expect(requestCount, 2);
  });
}

const _enabledConfiguration = {
  'enabled': true,
  'stores': {'appStore': true, 'googlePlay': true},
  'products': {
    'monthly': 'cn.lengziyu.cardapp.pro.monthly',
    'yearly': 'cn.lengziyu.cardapp.pro.yearly',
  },
};

final _activeEntitlement = {
  'entitlement': {
    'status': 'active',
    'plan': 'yearly',
    'expiresAt': DateTime.now()
        .add(const Duration(days: 30))
        .toUtc()
        .toIso8601String(),
    'autoRenewing': true,
    'accessGranted': true,
  },
};

http.Response _jsonResponse(Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
