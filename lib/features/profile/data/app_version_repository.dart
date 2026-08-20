import 'package:cardfi/core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateStatus { unavailable, upToDate, optional, required }

class AppVersionUpdate {
  const AppVersionUpdate({
    required this.status,
    this.latestVersion = '',
    this.latestBuildNumber = '',
    this.updateUrl = '',
    this.releaseNotes = '',
  });

  final AppUpdateStatus status;
  final String latestVersion;
  final String latestBuildNumber;
  final String updateUrl;
  final String releaseNotes;

  bool get needsUpdate =>
      status == AppUpdateStatus.optional || status == AppUpdateStatus.required;
  bool get requiresUpdate => status == AppUpdateStatus.required;
}

class AppVersionRepository {
  AppVersionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AppVersionUpdate> checkInstalledVersion(
    PackageInfo packageInfo,
  ) async {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => '',
    };
    if (platform.isEmpty) {
      return const AppVersionUpdate(status: AppUpdateStatus.unavailable);
    }
    final response = jsonObject(
      await _apiClient.get(
        '/api/app-version',
        query: {
          'platform': platform,
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
        },
      ),
    );
    final update = jsonObject(response['update'], label: '版本更新信息');
    return AppVersionUpdate(
      status: _statusFor(update['status']),
      latestVersion: update['latestVersion']?.toString() ?? '',
      latestBuildNumber: update['latestBuildNumber']?.toString() ?? '',
      updateUrl: update['updateUrl']?.toString() ?? '',
      releaseNotes: update['releaseNotes']?.toString() ?? '',
    );
  }

  AppUpdateStatus _statusFor(Object? value) => switch (value?.toString()) {
    'upToDate' => AppUpdateStatus.upToDate,
    'optional' => AppUpdateStatus.optional,
    'required' => AppUpdateStatus.required,
    _ => AppUpdateStatus.unavailable,
  };
}
