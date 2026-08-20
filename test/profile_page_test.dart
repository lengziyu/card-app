import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile avatar and login level card support dark mode', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    ProfileSection? openedSection;
    var loginCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProfilePage(
              onOpenSection: (section) => openedSection = section,
              onLogin: () => loginCount++,
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
    expect(find.byKey(const Key('profile-menu-cards')), findsNothing);
    expect(find.byKey(const Key('profile-menu-pro')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-notifications')), findsNothing);
    expect(find.byKey(const Key('profile-menu-language')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-settings')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-motionLab')), findsNothing);
    final languageBottom = tester.getBottomLeft(
      find.byKey(const Key('profile-menu-language')),
    );
    final settingsTop = tester.getTopLeft(
      find.byKey(const Key('profile-menu-settings')),
    );
    expect(languageBottom.dy, settingsTop.dy);
    expect(find.byKey(const Key('pro-crown-badge')), findsOneWidget);
    expect(find.byKey(const Key('profile-login')), findsNothing);
    expect(find.text('卡片等级'), findsOneWidget);
    expect(find.text('未登录'), findsWidgets);
    expect(find.text('质量分'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
    final loginChipSize = tester.getSize(
      find.byKey(const Key('profile-login-chip')),
    );
    expect(loginChipSize.height, 36);
    expect(loginChipSize.width, inInclusiveRange(90, 116));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('profile-membership-card')));
    expect(loginCount, 1);

    await tester.tap(find.byKey(const Key('profile-menu-language')));
    expect(openedSection, ProfileSection.language);

    await tester.tap(find.byKey(const Key('profile-menu-pro')));
    expect(openedSection, ProfileSection.pro);
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

  testWidgets('light profile avatar and level card match the H5 treatment', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProfilePage(
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

    expect(find.text('B'), findsOneWidget);
    expect(find.text('当前未登录 · 登录后同步卡片与收藏'), findsOneWidget);
    final avatar = tester.widget<Container>(
      find.byKey(const Key('profile-avatar')),
    );
    final avatarDecoration = avatar.decoration! as BoxDecoration;
    expect(avatarDecoration.color, isNull);
    expect(avatarDecoration.gradient, isA<LinearGradient>());
    expect(avatarDecoration.shape, BoxShape.circle);

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('profile-membership-surface')),
    );
    final surfaceDecoration = surface.decoration as BoxDecoration;
    expect(surfaceDecoration.borderRadius, BorderRadius.circular(14));
    expect(surfaceDecoration.gradient, isA<LinearGradient>());
    expect(find.text('卡片等级'), findsOneWidget);
    expect(find.text('质量分'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pro profile gives the account and card level a premium identity',
    (tester) async {
      AppColors.configure(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ProfilePage(
                onOpenSection: (_) {},
                onLogin: () {},
                isDarkMode: true,
                onToggleTheme: () {},
                isPro: true,
                authUser: const AuthUser(
                  id: 'user-1',
                  email: 'pro@example.com',
                  displayName: 'Pro 用户',
                  emailVerified: true,
                ),
                cardCount: 3,
                favoriteCount: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pro 用户'), findsOneWidget);
      expect(find.text('Pro 卡片等级'), findsOneWidget);
      expect(find.text('Pro 权益已解锁'), findsNothing);
      expect(find.byKey(const Key('pro-crown-badge')), findsWidgets);
      final avatar = tester.widget<Container>(
        find.byKey(const Key('profile-avatar')),
      );
      final decoration = avatar.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, const Color(0xFFF4A51C).withValues(alpha: .72));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English profile preserves user data and translates card counts',
    (tester) async {
      AppColors.configure(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],
          localizationsDelegates: const [AppLocalizations.delegate],
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ProfilePage(
                onOpenSection: (_) {},
                onLogin: () {},
                isDarkMode: false,
                onToggleTheme: () {},
                isPro: true,
                authUser: const AuthUser(
                  id: 'review-user',
                  email: 'review@example.com',
                  displayName: '审核账号',
                  emailVerified: true,
                ),
                cardCount: 12,
                favoriteCount: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('审核账号'), findsOneWidget);
      expect(find.text('审'), findsOneWidget);
      expect(find.text('@审核账号 · Manage cards and favorites'), findsOneWidget);
      expect(find.text('12 cards owned'), findsOneWidget);
      expect(find.text('0 favorites'), findsOneWidget);
      expect(
        find.text('Details are not available in English yet.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guest profile never displays a Pro membership treatment', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProfilePage(
              onOpenSection: (_) {},
              onLogin: () {},
              isDarkMode: true,
              onToggleTheme: () {},
              isPro: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('卡片等级'), findsOneWidget);
    expect(find.text('Pro 卡片等级'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsNothing,
    );
  });

  testWidgets('theme switch refreshes profile glass colors immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const _ThemeSwitchProfile());
    await tester.pump();

    BoxDecoration avatarDecoration() =>
        tester
                .widget<Container>(find.byKey(const Key('profile-avatar')))
                .decoration!
            as BoxDecoration;
    BoxDecoration membershipDecoration() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('profile-membership-surface')),
                )
                .decoration
            as BoxDecoration;
    TextStyle membershipStatusStyle() => tester
        .widget<Text>(find.byKey(const Key('profile-membership-status')))
        .style!;

    final lightAvatar = avatarDecoration().gradient! as LinearGradient;
    final lightMembership = membershipDecoration().gradient! as LinearGradient;
    expect(lightAvatar.colors.last, const Color(0xEBF5FAFF));
    expect(lightMembership.colors.last, const Color(0xEFF0F0FF));
    expect(membershipStatusStyle().color, const Color(0xFF131C2F));

    await tester.tap(find.byKey(const Key('profile-theme-toggle')));
    await tester.pumpAndSettle();

    final darkAvatar = avatarDecoration().gradient! as LinearGradient;
    final darkMembership = membershipDecoration().gradient! as LinearGradient;
    expect(darkAvatar.colors.last, const Color(0xFF252A40));
    expect(darkMembership.colors.last, const Color(0xFF1D2544));
    expect(membershipStatusStyle().color, Colors.white);
    expect(tester.takeException(), isNull);
  });
}

class _ThemeSwitchProfile extends StatefulWidget {
  const _ThemeSwitchProfile();

  @override
  State<_ThemeSwitchProfile> createState() => _ThemeSwitchProfileState();
}

class _ThemeSwitchProfileState extends State<_ThemeSwitchProfile> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    AppColors.configure(_dark ? Brightness.dark : Brightness.light);
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: ProfilePage(
            onOpenSection: (_) {},
            onLogin: () {},
            isDarkMode: _dark,
            onToggleTheme: () => setState(() => _dark = !_dark),
          ),
        ),
      ),
    );
  }
}
