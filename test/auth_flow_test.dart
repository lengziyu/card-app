import 'package:card_app/app/card_app.dart';
import 'package:card_app/features/auth/data/auth_repository.dart';
import 'package:card_app/features/auth/domain/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'zh-CN'});
    PackageInfo.setMockInitialValues(
      appName: '集卡',
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
