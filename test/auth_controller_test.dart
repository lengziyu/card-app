import 'package:card_app/features/auth/data/auth_controller.dart';
import 'package:card_app/features/auth/data/auth_repository.dart';
import 'package:card_app/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'registration requires email verification before granting a token',
    () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);

      await controller.initialize();
      final registered = await controller.register(
        email: 'user@example.com',
        password: 'correct-horse',
      );

      expect(registered, isFalse);
      expect(controller.user?.emailVerified, isFalse);
      expect(repository.verificationEmails, 1);
      expect(await controller.idToken(), isNull);

      repository.verified = true;
      final verified = await controller.refreshVerification();

      expect(verified, isTrue);
      expect(controller.isVerified, isTrue);
      expect(await controller.idToken(), 'auth-access-token');
      controller.dispose();
    },
  );

  test('password reset uses a generic success message', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.initialize();
    await controller.resetPassword('unknown@example.com');

    expect(repository.resetEmail, 'unknown@example.com');
    expect(controller.message, contains('如果该邮箱已注册'));
    controller.dispose();
  });

  test('silent verification refresh promotes a verified account', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.register(
      email: 'user@example.com',
      password: 'correct-horse',
    );
    repository.verified = true;

    final verified = await controller.refreshVerification(silently: true);

    expect(verified, isTrue);
    expect(controller.isVerified, isTrue);
    expect(controller.message, '邮箱验证成功。');
    controller.dispose();
  });

  test('manual verification check signs in after email confirmation', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.register(
      email: 'user@example.com',
      password: 'correct-horse',
    );
    repository.verified = true;

    final verified = await controller.confirmEmailVerification(
      email: 'user@example.com',
      password: 'correct-horse',
    );

    expect(verified, isTrue);
    expect(controller.isVerified, isTrue);
    expect(controller.message, '登录成功。');
    controller.dispose();
  });

  test('unconfirmed login keeps the verification actions available', () async {
    final repository = _FakeAuthRepository()..unconfirmedOnSignIn = true;
    final controller = AuthController(repository);

    final signedIn = await controller.signIn(
      email: 'user@example.com',
      password: 'correct-horse',
    );

    expect(signedIn, isFalse);
    expect(controller.user?.email, 'user@example.com');
    expect(controller.isVerified, isFalse);
    expect(controller.message, contains('邮箱尚未验证'));
    controller.dispose();
  });

  test(
    'leaving the registration flow clears pending verification state',
    () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);
      await controller.register(
        email: 'user@example.com',
        password: 'correct-horse',
      );

      await controller.resetAuthenticationFlow();

      expect(controller.user, isNull);
      expect(controller.message, isNull);
      controller.dispose();
    },
  );

  test('deleting a verified account clears the local session', () async {
    final repository = _FakeAuthRepository()..verified = true;
    final controller = AuthController(repository);
    await controller.signIn(
      email: 'user@example.com',
      password: 'correct-horse',
    );
    var deletedRemotely = false;

    final deleted = await controller.deleteAccount(() async {
      deletedRemotely = true;
    });

    expect(deleted, isTrue);
    expect(deletedRemotely, isTrue);
    expect(controller.user, isNull);
    expect(controller.message, '账号和云端数据已删除。');
    controller.dispose();
  });
}

class _FakeAuthRepository implements AuthRepository {
  bool verified = false;
  bool unconfirmedOnSignIn = false;
  int verificationEmails = 0;
  String? resetEmail;
  AuthUser? _user;

  @override
  bool get configured => true;

  AuthUser _current(String email) => AuthUser(
    id: 'firebase-user-1',
    email: email,
    displayName: null,
    emailVerified: verified,
  );

  @override
  Future<AuthUser?> initialize() async => _user;

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    verificationEmails++;
    return _user = _current(email);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (unconfirmedOnSignIn) {
      throw const AuthFailure('EMAIL_NOT_VERIFIED', '邮箱尚未验证');
    }
    return _user = _current(email);
  }

  @override
  Future<AuthUser?> reloadUser() async {
    final email = _user?.email ?? 'user@example.com';
    return _user = _current(email);
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    final current = _user ?? _current('user@example.com');
    return _user = AuthUser(
      id: current.id,
      email: current.email,
      displayName: displayName,
      emailVerified: current.emailVerified,
    );
  }

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<void> sendPasswordReset(String email) async => resetEmail = email;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> idToken() async => verified ? 'auth-access-token' : null;
}
