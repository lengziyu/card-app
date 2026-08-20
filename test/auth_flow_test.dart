import 'dart:async';

import 'package:cardfi/app/card_app.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'zh-CN'});
    PackageInfo.setMockInitialValues(
      appName: 'CardFi',
      packageName: 'cn.lengziyu.cardapp',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('verified account signs in and renders the profile', (
    tester,
  ) async {
    final repository = _VerifiedAuthRepository();
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'correct-horse',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsNothing);
    expect(find.text('member'), findsOneWidget);
    expect(find.text('@member · 可管理卡片与收藏'), findsOneWidget);
    expect(find.byKey(const Key('profile-logout')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsNothing);
  });

  testWidgets('English login shows the actionable authentication error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'en-US'});
    await tester.pumpWidget(CardApp(authRepository: _FailingAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();

    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('用户名 / 邮箱'), findsNothing);
    expect(find.text('密码'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'reviewer@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'incorrect-password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(
      find.text(
        'Login failed. Check your email and password. '
        'If this account was deleted, create a new account.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
  });

  testWidgets('English settings renders translated primary controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'en-US'});
    await tester.pumpWidget(CardApp(authRepository: _VerifiedAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Card Swipe Haptics'), findsOneWidget);
    expect(find.text('Card swipe intensity'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('User Guide'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
  });

  testWidgets('switching accounts never exposes the previous local card state', (
    tester,
  ) async {
    const userA = AuthUser(
      id: 'user-a',
      email: 'a@example.com',
      displayName: 'A',
      emailVerified: true,
    );
    const userB = AuthUser(
      id: 'user-b',
      email: 'b@example.com',
      displayName: 'B',
      emailVerified: true,
    );
    SharedPreferences.setMockInitialValues({
      'card-app-language-v1': 'zh-CN',
      LocalGuestStateRepository.storageKeyForUser(
        userA.id,
      ): '{"version":2,"addedCardIds":["etherfi-core"],"favoriteCardIds":[],"favoriteArticleIds":[],"recentCardIds":[],"submissions":[]}',
      LocalGuestStateRepository.storageKeyForUser(
        userB.id,
      ): '{"version":2,"addedCardIds":["bybit-card"],"favoriteCardIds":[],"favoriteArticleIds":[],"recentCardIds":[],"submissions":[]}',
      LocalGuestStateRepository.legacyStorageKey:
          '{"version":2,"addedCardIds":["redotpay"],"favoriteCardIds":[],"favoriteArticleIds":[],"recentCardIds":[],"submissions":[]}',
    });
    final repository = _SwitchingAuthRepository(userA);
    addTearDown(repository.dispose);

    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-card-etherfi-core')), findsOneWidget);
    expect(find.byKey(const Key('home-card-redotpay')), findsNothing);

    repository.switchTo(userB);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-card-etherfi-core')), findsNothing);
    expect(find.byKey(const Key('home-card-bybit-card')), findsOneWidget);
    expect(find.byKey(const Key('home-card-redotpay')), findsNothing);
  });
}

class _SwitchingAuthRepository implements AuthRepository, AuthStateRepository {
  _SwitchingAuthRepository(this._user);

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  void switchTo(AuthUser user) {
    _user = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  bool get configured => true;

  @override
  Future<AuthUser?> initialize() async => _user;

  @override
  Future<String?> idToken() async => _user == null ? null : 'auth-token';

  @override
  Future<AuthUser?> reloadUser() async => _user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _user!;

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async => _user!;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async => _user!;
}

class _VerifiedAuthRepository implements AuthRepository {
  AuthUser? _user;

  @override
  bool get configured => true;

  @override
  Future<AuthUser?> initialize() async => _user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _user = AuthUser(
    id: 'auth-user-1',
    email: email,
    displayName: null,
    emailVerified: true,
  );

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => signIn(email: email, password: password);

  @override
  Future<AuthUser?> reloadUser() async => _user;

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    final current = _user!;
    return _user = AuthUser(
      id: current.id,
      email: current.email,
      displayName: displayName,
      emailVerified: current.emailVerified,
    );
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> idToken() async => _user == null ? null : 'auth-token';
}

class _FailingAuthRepository extends _VerifiedAuthRepository {
  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    throw const AuthFailure(
      'INVALID_CREDENTIALS',
      '登录失败，请检查邮箱和密码；如已删除账号，请重新注册',
    );
  }
}
