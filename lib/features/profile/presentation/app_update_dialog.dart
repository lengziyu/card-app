import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/profile/data/app_version_repository.dart';
import 'package:flutter/material.dart' hide Text;

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    required this.update,
    required this.blocking,
    required this.onUpdate,
    this.onLater,
    super.key,
  });

  final AppVersionUpdate update;
  final bool blocking;
  final VoidCallback onUpdate;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final latest =
        '${update.latestVersion}${localizations.text('（构建 ')}${update.latestBuildNumber}${localizations.text('）')}';
    final minimum = update.minimumVersion.isEmpty
        ? ''
        : '${update.minimumVersion}${localizations.text('（构建 ')}${update.minimumBuildNumber}${localizations.text('）')}';
    final message = blocking
        ? minimum.isEmpty
              ? '${localizations.text('当前版本已不再受支持。请更新至 ')}$latest${localizations.text('后继续使用。')}'
              : '${localizations.text('当前版本低于最低支持版本 ')}$minimum${localizations.text('。请更新至 ')}$latest${localizations.text('后继续使用。')}'
        : '${localizations.text('新版本 ')}$latest${localizations.text(' 已发布，你可以现在更新，也可以稍后在版本管理中处理。')}';

    return PopScope(
      canPop: !blocking,
      child: AlertDialog(
        key: Key(
          blocking ? 'required-update-dialog' : 'optional-update-dialog',
        ),
        icon: Icon(
          blocking
              ? Icons.system_security_update_warning_rounded
              : Icons.system_update_alt_rounded,
          color: blocking ? AppColors.pink : AppColors.cyan,
          size: 34,
        ),
        title: Text(blocking ? '需要更新' : '发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(height: 1.5)),
              if (update.releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '本次更新',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  update.releaseNotes,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!blocking)
            TextButton(
              key: const Key('optional-update-later'),
              onPressed: onLater,
              child: const Text('稍后'),
            ),
          FilledButton(
            key: Key(
              blocking ? 'required-update-open' : 'optional-update-open',
            ),
            onPressed: onUpdate,
            child: Text(blocking ? '立即更新' : '前往更新'),
          ),
        ],
      ),
    );
  }
}
