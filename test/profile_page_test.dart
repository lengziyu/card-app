import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile avatar and animated membership card support dark mode', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    var loginRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProfilePage(
              cardCount: 0,
              favoriteCount: 0,
              historyCount: 0,
              submissionCount: 0,
              onOpenSection: (_) {},
              onLogin: () => loginRequested = true,
              isDarkMode: true,
              onToggleTheme: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile-avatar')), findsOneWidget);
    expect(find.byKey(const Key('profile-membership-card')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-membership-gradient')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('profile-membership-card')));
    expect(loginRequested, isTrue);
  });

  testWidgets('profile visual treatment fits narrow screens and large text', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.55),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: ProfilePage(
              cardCount: 0,
              favoriteCount: 0,
              historyCount: 0,
              submissionCount: 0,
              onOpenSection: (_) {},
              onLogin: () {},
              isDarkMode: false,
              onToggleTheme: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(find.byKey(const Key('profile-membership-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
