import 'dart:async';

import 'package:cardfi/features/auth/data/auth_controller.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'finishing deletion of an old account does not sign out a new account',
    () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);
      addTearDown(controller.dispose);
      await controller.verifyEmailOtp(
        email: 'member@example.com',
        token: '123456',
      );
      final result = await controller.deleteAccount(() async {
        controller.user = const AuthUser(
          id: 'new-account',
          email: 'other@example.com',
          displayName: 'Other',
          emailVerified: true,
        );
      });
      expect(result, isFalse);
      expect(controller.user?.id, 'new-account');
    },
  );
  test(
    'email OTP signs an existing user into the same stable account',
    () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);

      expect(await controller.sendEmailOtp('Member@Example.com'), isTrue);
      expect(repository.otpEmail, 'member@example.com');

      final verified = await controller.verifyEmailOtp(
        email: 'Member@Example.com',
        token: '123456',
      );

      expect(verified, isTrue);
      expect(repository.otpToken, '123456');
      expect(controller.user?.id, 'firebase-user-1');
      expect(controller.user?.hasProvider(AuthLoginProvider.email), isTrue);
      controller.dispose();
    },
  );

  test('linking Google keeps the existing user id', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);
    await controller.verifyEmailOtp(
      email: 'member@example.com',
      token: '123456',
    );
    final originalId = controller.user?.id;

    final linked = await controller.linkGoogleIdentity();

    expect(linked, isTrue);
    expect(controller.user?.id, originalId);
    expect(controller.user?.hasProvider(AuthLoginProvider.google), isTrue);
    controller.dispose();
  });

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
    final sent = await controller.resetPassword('unknown@example.com');

    expect(sent, isTrue);
    expect(repository.resetEmail, 'unknown@example.com');
    expect(controller.message, contains('如果该邮箱已注册'));
    controller.dispose();
  });

  test(
    'authentication rejects usernames before calling the repository',
    () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);

      expect(
        await controller.signIn(email: 'buding', password: 'old-password'),
        isFalse,
      );
      expect(controller.message, '请输入有效的邮箱地址');
      expect(controller.user, isNull);
      expect(repository.otpEmail, isNull);
      controller.dispose();
    },
  );

  test(
    'password recovery only updates after an explicit recovery event',
    () async {
      final repository = _RecoveryAuthRepository();
      final controller = AuthController(repository);
      await controller.initialize();

      expect(await controller.updateRecoveredPassword('new-password'), isFalse);
      expect(repository.updatedPassword, isNull);

      repository.emitRecovery();
      await Future<void>.delayed(Duration.zero);
      expect(controller.passwordRecoveryPending, isTrue);

      expect(await controller.updateRecoveredPassword('short'), isFalse);
      expect(repository.updatedPassword, isNull);

      final updated = await controller.updateRecoveredPassword('new-password');
      expect(updated, isTrue);
      expect(repository.updatedPassword, 'new-password');
      expect(controller.passwordRecoveryPending, isFalse);
      expect(controller.user?.id, 'firebase-user-1');
      expect(controller.message, '密码已更新。');

      controller.dispose();
      await repository.close();
    },
  );

  test('recovery OTP authorizes the new-password form', () async {
    final repository = _RecoveryAuthRepository();
    final controller = AuthController(repository);
    await controller.initialize();

    expect(
      await controller.verifyPasswordRecoveryOtp(
        email: 'member@example.com',
        token: '12345',
      ),
      isFalse,
    );
    expect(repository.recoveryToken, isNull);

    expect(
      await controller.verifyPasswordRecoveryOtp(
        email: 'Member@Example.com',
        token: '123456',
      ),
      isTrue,
    );
    expect(repository.recoveryEmail, 'member@example.com');
    expect(repository.recoveryToken, '123456');
    expect(controller.passwordRecoveryPending, isTrue);

    controller.dispose();
    await repository.close();
  });

  test('canceling password recovery clears its temporary session', () async {
    final repository = _RecoveryAuthRepository();
    final controller = AuthController(repository);
    await controller.initialize();
    repository.emitRecovery();
    await Future<void>.delayed(Duration.zero);

    await controller.cancelPasswordRecovery();

    expect(controller.passwordRecoveryPending, isFalse);
    expect(controller.user, isNull);
    expect(repository.signedOut, isTrue);
    controller.dispose();
    await repository.close();
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

      controller.resetAuthenticationFlow();

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

  test('live session changes keep the visible account state in sync', () async {
    final repository = _LiveAuthRepository();
    final controller = AuthController(repository);
    await controller.initialize();

    repository.emit(
      const AuthUser(
        id: 'restored-user',
        email: 'member@example.com',
        displayName: null,
        emailVerified: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.isVerified, isTrue);

    repository.emit(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.user, isNull);

    controller.dispose();
    await repository.close();
  });
}

class _LiveAuthRepository extends _FakeAuthRepository
    implements AuthStateRepository {
  final _states = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get authStateChanges => _states.stream;

  void emit(AuthUser? user) => _states.add(user);

  Future<void> close() => _states.close();
}

class _RecoveryAuthRepository extends _FakeAuthRepository
    implements PasswordRecoveryRepository {
  final _recoveryEvents = StreamController<void>.broadcast();
  String? updatedPassword;
  String? recoveryEmail;
  String? recoveryToken;
  bool signedOut = false;

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryEvents.stream;

  void emitRecovery() => _recoveryEvents.add(null);

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
    verified = true;
    return _current('member@example.com');
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    await super.signOut();
  }

  Future<void> close() => _recoveryEvents.close();
}

class _FakeAuthRepository
    implements AuthRepository, PasswordlessAuthRepository {
  bool verified = false;
  bool unconfirmedOnSignIn = false;
  int verificationEmails = 0;
  String? resetEmail;
  String? otpEmail;
  String? otpToken;
  AuthUser? _user;

  @override
  bool get configured => true;

  @override
  bool get appleConfigured => true;

  @override
  bool get googleConfigured => true;

  AuthUser _current(String email) => AuthUser(
    id: 'firebase-user-1',
    email: email,
    displayName: null,
    emailVerified: verified,
    loginProviders: const {AuthLoginProvider.email},
  );

  @override
  Future<void> sendEmailOtp(String email) async => otpEmail = email;

  @override
  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    otpToken = token;
    verified = true;
    return _user = _current(email.toLowerCase());
  }

  @override
  Future<AuthUser> signInWithApple() async {
    verified = true;
    return _user = _current('apple@example.com');
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    verified = true;
    return _user = _current('google@example.com');
  }

  @override
  Future<AuthUser> linkAppleIdentity() async =>
      _user = (_user ?? _current('user@example.com')).copyWith(
        loginProviders: const {
          AuthLoginProvider.email,
          AuthLoginProvider.apple,
        },
      );

  @override
  Future<AuthUser> linkGoogleIdentity() async =>
      _user = (_user ?? _current('user@example.com')).copyWith(
        loginProviders: const {
          AuthLoginProvider.email,
          AuthLoginProvider.google,
        },
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
