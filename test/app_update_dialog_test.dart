import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/country_localizations_delegate.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/profile/data/app_version_repository.dart';
import 'package:cardfi/features/profile/presentation/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppColors.configure(Brightness.light));

  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      appCountryLocalizationsDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );

  testWidgets('required update exposes the minimum release without a skip', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      app(
        AppUpdateDialog(
          update: const AppVersionUpdate(
            status: AppUpdateStatus.required,
            latestVersion: '2.0.0',
            latestBuildNumber: '20',
            forceUpdateEnabled: true,
            minimumVersion: '1.5.0',
            minimumBuildNumber: '15',
            updateUrl: 'https://example.com/store',
            releaseNotes: 'Important fixes.',
          ),
          blocking: true,
          onUpdate: () => opened = true,
        ),
      ),
    );

    expect(find.byKey(const Key('required-update-dialog')), findsOneWidget);
    expect(find.textContaining('1.5.0'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    await tester.tap(find.byKey(const Key('required-update-open')));
    expect(opened, isTrue);
  });

  testWidgets('optional update can be postponed on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var postponed = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: app(
          AppUpdateDialog(
            update: const AppVersionUpdate(
              status: AppUpdateStatus.optional,
              latestVersion: '2.0.0',
              latestBuildNumber: '20',
              updateUrl: 'https://example.com/store',
              releaseNotes: 'Several reliability improvements.',
            ),
            blocking: false,
            onLater: () => postponed = true,
            onUpdate: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('optional-update-dialog')), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await tester.tap(find.byKey(const Key('optional-update-later')));
    expect(postponed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
