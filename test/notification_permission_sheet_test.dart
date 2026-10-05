import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/country_localizations_delegate.dart';
import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/notifications/presentation/notification_permission_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({required ValueChanged<bool?> onResult}) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        appCountryLocalizationsDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open-notification-permission-sheet'),
              onPressed: () => showAppBottomSheet<bool>(
                context: context,
                builder: (_) => const NotificationPermissionSheet(),
              ).then(onResult),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => AppColors.configure(Brightness.light));

  testWidgets('explains notification value before accepting permission', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(
      find.byKey(const Key('open-notification-permission-sheet')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stay informed about important changes'), findsOneWidget);
    expect(find.text('New card releases'), findsOneWidget);
    expect(find.text('Important updates'), findsOneWidget);
    expect(find.text('Stay in control'), findsOneWidget);
    expect(find.text('Turn On Notifications'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('notification-permission-enable')),
    );
    await tester.tap(find.byKey(const Key('notification-permission-enable')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('supports a narrow phone, large text and a later choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: app(onResult: (value) => result = value),
      ),
    );
    await tester.tap(
      find.byKey(const Key('open-notification-permission-sheet')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('notification-permission-later')),
    );
    await tester.tap(find.byKey(const Key('notification-permission-later')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });
}
