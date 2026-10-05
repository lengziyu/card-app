import 'package:cardfi/core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateStatus { unavailable, upToDate, optional, required }

class AppVersionUpdate {
  const AppVersionUpdate({
    required this.status,
    this.latestVersion = '',
    this.latestBuildNumber = '',
    this.forceUpdateEnabled = false,
    this.minimumVersion = '',
    this.minimumBuildNumber = '',
    this.configurationInvalid = false,
    this.updateUrl = '',
    this.releaseNotes = '',
  });

  final AppUpdateStatus status;
  final String latestVersion;
  final String latestBuildNumber;
  final bool forceUpdateEnabled;
  final String minimumVersion;
  final String minimumBuildNumber;
  final bool configurationInvalid;
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
    final parsedStatus = _statusFor(update['status']);
    final updateUrl = _safeHttpsUrl(update['updateUrl']);
    // Never trap an installation behind a required-update dialog without a
    // valid HTTPS destination. A malformed rollout fails open and remains
    // visible to operators through the manual version page.
    final status =
        parsedStatus != AppUpdateStatus.upToDate &&
            parsedStatus != AppUpdateStatus.unavailable &&
            updateUrl.isEmpty
        ? AppUpdateStatus.unavailable
        : parsedStatus;
    return AppVersionUpdate(
      status: status,
      latestVersion: update['latestVersion']?.toString() ?? '',
      latestBuildNumber: update['latestBuildNumber']?.toString() ?? '',
      forceUpdateEnabled:
          update['forceUpdateEnabled'] == true ||
          parsedStatus == AppUpdateStatus.required,
      minimumVersion: update['minimumVersion']?.toString() ?? '',
      minimumBuildNumber: update['minimumBuildNumber']?.toString() ?? '',
      configurationInvalid:
          parsedStatus != AppUpdateStatus.upToDate &&
          parsedStatus != AppUpdateStatus.unavailable &&
          updateUrl.isEmpty,
      updateUrl: updateUrl,
      releaseNotes: update['releaseNotes']?.toString() ?? '',
    );
  }

  String _safeHttpsUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
    return uri.toString();
  }

  AppUpdateStatus _statusFor(Object? value) => switch (value?.toString()) {
    'upToDate' => AppUpdateStatus.upToDate,
    'optional' => AppUpdateStatus.optional,
    'required' => AppUpdateStatus.required,
    _ => AppUpdateStatus.unavailable,
  };
}
