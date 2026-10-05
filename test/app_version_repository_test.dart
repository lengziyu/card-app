import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/profile/data/app_version_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final packageInfo = PackageInfo(
    appName: 'CardFi',
    packageName: 'cn.lengziyu.cardapp',
    version: '0.1.0',
    buildNumber: '1',
  );

  test('maps a required update from the public version endpoint', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/app-version');
        expect(request.url.queryParameters['version'], '0.1.0');
        expect(request.url.queryParameters['buildNumber'], '1');
        return http.Response(
          jsonEncode({
            'update': {
              'status': 'required',
              'latestVersion': '0.2.0',
              'latestBuildNumber': '3',
              'forceUpdateEnabled': true,
              'minimumVersion': '0.1.5',
              'minimumBuildNumber': '2',
              'updateUrl':
                  'https://play.google.com/store/apps/details?id=cn.lengziyu.cardapp',
              'releaseNotes': '修复稳定性问题。',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final update = await AppVersionRepository(
      client,
    ).checkInstalledVersion(packageInfo);

    expect(update.status, AppUpdateStatus.required);
    expect(update.requiresUpdate, isTrue);
    expect(update.latestVersion, '0.2.0');
    expect(update.forceUpdateEnabled, isTrue);
    expect(update.minimumVersion, '0.1.5');
    expect(update.releaseNotes, '修复稳定性问题。');
    client.close();
  });

  test('fails open when an update has no safe HTTPS store link', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'update': {
              'status': 'required',
              'latestVersion': '0.2.0',
              'latestBuildNumber': '3',
              'forceUpdateEnabled': true,
              'minimumVersion': '0.1.5',
              'minimumBuildNumber': '2',
              'updateUrl': 'http://unsafe.example/update',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final update = await AppVersionRepository(
      client,
    ).checkInstalledVersion(packageInfo);

    expect(update.status, AppUpdateStatus.unavailable);
    expect(update.configurationInvalid, isTrue);
    expect(update.updateUrl, isEmpty);
    expect(update.requiresUpdate, isFalse);
    client.close();
  });

  test('treats an unconfigured server response as non-blocking', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'update': {'status': 'unavailable'},
          }),
          200,
        ),
      ),
    );

    final update = await AppVersionRepository(
      client,
    ).checkInstalledVersion(packageInfo);

    expect(update.status, AppUpdateStatus.unavailable);
    expect(update.needsUpdate, isFalse);
    client.close();
  });
}
