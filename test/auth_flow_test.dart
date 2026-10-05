import 'dart:async';

import 'package:cardfi/app/card_app.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-otp-field')), '123456');
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

    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'reviewer@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-otp-field')), '000000');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(
      find.text('The code is invalid or expired. Request a new code.'),
      findsOneWidget,
    );
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
  });

  testWidgets(
    'existing password account can still sign in without registering',
    (tester) async {
      final repository = _PasswordTrackingAuthRepository();
      await tester.pumpWidget(CardApp(authRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-我的')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-membership-card')));
      await tester.pumpAndSettle();

      final brandImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('auth-brand-logo')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (brandImage.image as AssetImage).assetName,
        'assets/branding/cardfi-icon-master.png',
      );
      expect(find.byKey(const Key('auth-password-field')), findsNothing);
      expect(find.text('创建账号'), findsNothing);
      await tester.tap(find.byKey(const Key('auth-use-password')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-forgot-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-referral-code-field')), findsNothing);
      expect(find.text('创建账号'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('auth-forgot-password'))).dx,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('auth-account-field'))).dx,
          0.1,
        ),
      );
      expect(
        tester.getTopRight(find.byKey(const Key('auth-use-email-otp'))).dx,
        closeTo(
          tester.getTopRight(find.byKey(const Key('auth-account-field'))).dx,
          0.1,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('auth-account-field')),
        'Legacy@Example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'old-password',
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(repository.signedInEmail, 'legacy@example.com');
      expect(repository.signedInPassword, 'old-password');
      expect(find.byKey(const Key('login-page')), findsNothing);
      expect(find.byKey(const Key('profile-page')), findsOneWidget);
    },
  );

  testWidgets('login rejects a username and only accepts an email address', (
    tester,
  ) async {
    final repository = _PasswordTrackingAuthRepository();
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-use-password')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'buding',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'old-password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);
    expect(repository.signedInEmail, isNull);
    expect(repository.signedInPassword, isNull);
    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('settings show the account email and logout returns to profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _VerifiedAuthRepository();
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'ichenbuding@gmail.com',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-otp-field')), '123456');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-settings'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-profile-email')), findsOneWidget);
    expect(find.text('注册邮箱'), findsOneWidget);
    final emailText = find.text('ichenbuding@gmail.com');
    expect(emailText, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(emailText).didExceedMaxLines,
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-logout')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings-logout'))),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-subpage-settings')), findsNothing);
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(repository.currentUser, isNull);
  });

  testWidgets('password recovery deep link opens and completes reset form', (
    tester,
  ) async {
    final repository = _RecoveryAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    repository.emitRecovery();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-recovery-page')), findsOneWidget);
    expect(find.byKey(const Key('login-page')), findsNothing);
    expect(find.text('设置新密码'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('password-recovery-password')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('password-recovery-confirmation')),
      'different-password',
    );
    await tester.tap(find.byKey(const Key('password-recovery-submit')));
    await tester.pumpAndSettle();
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(repository.updatedPassword, isNull);

    await tester.enterText(
      find.byKey(const Key('password-recovery-confirmation')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('password-recovery-submit')));
    await tester.pumpAndSettle();

    expect(repository.updatedPassword, 'new-password');
    expect(find.byKey(const Key('password-recovery-page')), findsNothing);
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
  });

  testWidgets('forgot password verifies a six-digit recovery code', (
    tester,
  ) async {
    final repository = _RecoveryAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-use-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'Member@Example.com',
    );
    await tester.tap(find.byKey(const Key('auth-forgot-password')));
    await tester.pumpAndSettle();

    expect(repository.resetEmail, 'member@example.com');
    expect(find.byKey(const Key('auth-password-field')), findsNothing);
    expect(find.byKey(const Key('auth-otp-field')), findsOneWidget);
    expect(find.text('验证重置码'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-otp-field')), '123456');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(repository.recoveryEmail, 'member@example.com');
    expect(repository.recoveryToken, '123456');
    expect(find.byKey(const Key('password-recovery-page')), findsOneWidget);
  });

  testWidgets('canceling password recovery signs out its temporary session', (
    tester,
  ) async {
    final repository = _RecoveryAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(CardApp(authRepository: repository));
    await tester.pumpAndSettle();
    repository.emitRecovery();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('password-recovery-cancel')));
    await tester.pumpAndSettle();

    expect(repository.signedOut, isTrue);
    expect(find.byKey(const Key('password-recovery-page')), findsNothing);
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
  });

  testWidgets('English settings renders translated primary controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'en-US'});
    await tester.pumpWidget(CardApp(authRepository: _VerifiedAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('profile-page')),
      const Offset(0, -80),
    );
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

class _VerifiedAuthRepository
    implements AuthRepository, PasswordlessAuthRepository {
  AuthUser? _user;

  AuthUser? get currentUser => _user;

  @override
  bool get configured => true;

  @override
  bool get appleConfigured => false;

  @override
  bool get googleConfigured => false;

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  }) async => _user = AuthUser(
    id: 'auth-user-1',
    email: email,
    displayName: null,
    emailVerified: true,
    loginProviders: const {AuthLoginProvider.email},
  );

  @override
  Future<AuthUser> signInWithApple() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> signInWithGoogle() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> linkAppleIdentity() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> linkGoogleIdentity() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

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
  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    throw const AuthFailure('OTP_EXPIRED', '验证码无效或已过期，请重新获取');
  }
}

class _RecoveryAuthRepository extends _VerifiedAuthRepository
    implements PasswordRecoveryRepository {
  final _events = StreamController<void>.broadcast();
  String? updatedPassword;
  String? resetEmail;
  String? recoveryEmail;
  String? recoveryToken;
  bool signedOut = false;

  @override
  Stream<void> get passwordRecoveryEvents => _events.stream;

  void emitRecovery() => _events.add(null);

  @override
  Future<void> sendPasswordReset(String email) async => resetEmail = email;

  @override
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    recoveryEmail = email;
    recoveryToken = token;
    emitRecovery();
  }

  @override
  Future<AuthUser> updateRecoveredPassword(String password) async {
    updatedPassword = password;
    return _user = const AuthUser(
      id: 'auth-user-1',
      email: 'member@example.com',
      displayName: null,
      emailVerified: true,
      loginProviders: {AuthLoginProvider.email},
    );
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    await super.signOut();
  }

  void dispose() => _events.close();
}

class _PasswordTrackingAuthRepository extends _VerifiedAuthRepository {
  String? signedInEmail;
  String? signedInPassword;

  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    signedInEmail = email;
    signedInPassword = password;
    return super.signIn(email: email, password: password);
  }
}
