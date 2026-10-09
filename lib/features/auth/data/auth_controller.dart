import 'dart:async';

import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/profile/data/avatar_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository, {this.avatarRepository});

  final AuthRepository _repository;
  final AvatarRepository? avatarRepository;

  AuthUser? user;
  bool loading = true;
  String? message;
  int registrationCelebrationVersion = 0;
  bool passwordRecoveryPending = false;
  String? lastSuccessfulAuthMethod;
  bool _disposed = false;
  StreamSubscription<AuthUser?>? _authStateSubscription;
  StreamSubscription<void>? _passwordRecoverySubscription;
  int _authStateVersion = 0;

  bool get configured => _repository.configured;
  bool get isVerified => user?.emailVerified == true;
  PasswordlessAuthRepository? get _passwordlessRepository =>
      _repository is PasswordlessAuthRepository
      ? _repository as PasswordlessAuthRepository
      : null;
  PasswordRecoveryRepository? get _passwordRecoveryRepository =>
      _repository is PasswordRecoveryRepository
      ? _repository as PasswordRecoveryRepository
      : null;
  bool get googleConfigured =>
      _passwordlessRepository?.googleConfigured == true;
  bool get appleConfigured => _passwordlessRepository?.appleConfigured == true;

  String _validatedEmail(String value) {
    final email = value.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const AuthFailure('INVALID_EMAIL', '请输入有效的邮箱地址');
    }
    return email;
  }

  Future<void> initialize() async {
    loading = true;
    _notify();
    try {
      user = await _attachAvatar(await _repository.initialize());
      message = user != null && !isVerified ? '请先完成邮箱验证。' : null;
    } on AuthFailure catch (error) {
      message = error.message;
    } finally {
      _listenToRepositoryState();
      loading = false;
      _notify();
    }
  }

  void _listenToRepositoryState() {
    if (_authStateSubscription == null && _repository is AuthStateRepository) {
      final stateRepository = _repository as AuthStateRepository;
      _authStateSubscription = stateRepository.authStateChanges.listen(
        (nextUser) {
          final version = ++_authStateVersion;
          unawaited(_applyRepositoryUser(nextUser, version));
        },
        onError: (Object _) {
          // A transient background refresh error must not interrupt the current
          // screen. Token consumers retry when the app resumes or Pro is opened.
        },
      );
    }
    final recoveryRepository = _passwordRecoveryRepository;
    if (_passwordRecoverySubscription == null && recoveryRepository != null) {
      _passwordRecoverySubscription = recoveryRepository.passwordRecoveryEvents
          .listen(
            (_) {
              passwordRecoveryPending = true;
              message = null;
              _notify();
            },
            onError: (Object _) {
              message = '密码重置链接无效或已过期，请重新获取。';
              _notify();
            },
          );
    }
  }

  Future<void> _applyRepositoryUser(AuthUser? nextUser, int version) async {
    final next = await _attachAvatar(nextUser);
    // Explicit OTP/social operations update [user] only after every required
    // compatibility and credential-registration step succeeds. Ignore the
    // intermediate SDK event while such an operation is still in flight.
    if (_disposed || version != _authStateVersion || loading) return;
    user = next;
    if (next == null) {
      message = null;
      lastSuccessfulAuthMethod = null;
    }
    _notify();
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      final validatedEmail = _validatedEmail(email);
      try {
        user = await _attachAvatar(
          await _repository.signIn(email: validatedEmail, password: password),
        );
      } on AuthFailure catch (error) {
        if (error.code == 'EMAIL_NOT_VERIFIED') {
          // Supabase intentionally does not expose a session for an
          // unconfirmed user. Keep only enough local state to offer resend
          // and explicit verification checking; it is not an authenticated
          // account and cannot produce an access token.
          user = AuthUser(
            id: 'pending:$validatedEmail',
            email: validatedEmail,
            displayName: null,
            emailVerified: false,
          );
        }
        rethrow;
      }
      if (!isVerified) {
        message = '邮箱尚未验证，请打开验证邮件后点击“我已完成验证”。';
        return false;
      }
      lastSuccessfulAuthMethod = 'password';
      message = '登录成功。';
      return true;
    });
  }

  Future<bool> sendEmailOtp(String email) {
    return _run(() async {
      final repository = _passwordlessRepository;
      if (repository == null) {
        throw const AuthFailure('OTP_UNAVAILABLE', '邮箱验证码登录暂不可用');
      }
      await repository.sendEmailOtp(_validatedEmail(email));
      message = '验证码已发送，请查看邮箱。';
      return true;
    });
  }

  Future<bool> verifyEmailOtp({required String email, required String token}) {
    return _run(() async {
      final repository = _passwordlessRepository;
      if (repository == null) {
        throw const AuthFailure('OTP_UNAVAILABLE', '邮箱验证码登录暂不可用');
      }
      user = await _attachAvatar(
        await repository.verifyEmailOtp(
          email: _validatedEmail(email),
          token: token,
        ),
      );
      if (!isVerified) {
        throw const AuthFailure('EMAIL_NOT_VERIFIED', '邮箱验证未完成，请重新获取验证码');
      }
      lastSuccessfulAuthMethod = 'email_otp';
      message = '登录成功。';
      return true;
    });
  }

  Future<bool> signInWithGoogle() => _signInWithProvider(
    (repository) => repository.signInWithGoogle(),
    successMessage: 'Google 登录成功。',
    authMethod: 'google',
  );

  Future<bool> signInWithApple() => _signInWithProvider(
    (repository) => repository.signInWithApple(),
    successMessage: 'Apple 登录成功。',
    authMethod: 'apple',
  );

  Future<bool> _signInWithProvider(
    Future<AuthUser> Function(PasswordlessAuthRepository repository)
    operation, {
    required String successMessage,
    required String authMethod,
  }) {
    return _run(() async {
      final repository = _passwordlessRepository;
      if (repository == null) {
        throw const AuthFailure('SOCIAL_AUTH_UNAVAILABLE', '第三方登录暂不可用');
      }
      user = await _attachAvatar(await operation(repository));
      if (!isVerified) {
        throw const AuthFailure('AUTH_FAILED', '登录服务未返回有效账号');
      }
      lastSuccessfulAuthMethod = authMethod;
      message = successMessage;
      return true;
    });
  }

  Future<bool> linkGoogleIdentity() => _linkIdentity(
    AuthLoginProvider.google,
    (repository) => repository.linkGoogleIdentity(),
    label: 'Google',
  );

  Future<bool> linkAppleIdentity() => _linkIdentity(
    AuthLoginProvider.apple,
    (repository) => repository.linkAppleIdentity(),
    label: 'Apple',
  );

  Future<bool> unlinkGoogleIdentity() => _unlinkIdentity(
    AuthLoginProvider.google,
    (repository) => repository.unlinkGoogleIdentity(),
    label: 'Google',
  );

  Future<bool> unlinkAppleIdentity() => _unlinkIdentity(
    AuthLoginProvider.apple,
    (repository) => repository.unlinkAppleIdentity(),
    label: 'Apple',
  );

  Future<bool> _unlinkIdentity(
    AuthLoginProvider provider,
    Future<AuthUser> Function(LinkedIdentityManagementRepository repository)
    operation, {
    required String label,
  }) {
    final current = user;
    if (current == null || !current.hasProvider(provider)) {
      message = '$label 尚未绑定。';
      _notify();
      return Future.value(false);
    }
    if (current.loginProviders.length <= 1) {
      message = '请先绑定另一种登录方式，再解除 $label 绑定。';
      _notify();
      return Future.value(false);
    }
    return _run(() async {
      if (_repository is! LinkedIdentityManagementRepository) {
        throw const AuthFailure('IDENTITY_UNLINKING_UNAVAILABLE', '账号解绑暂不可用');
      }
      user = await _attachAvatar(
        await operation(_repository as LinkedIdentityManagementRepository),
      );
      message = '$label 账号已解除绑定。';
      return true;
    });
  }

  Future<bool> _linkIdentity(
    AuthLoginProvider provider,
    Future<AuthUser> Function(PasswordlessAuthRepository repository)
    operation, {
    required String label,
  }) {
    if (!isVerified) {
      message = '请先使用邮箱验证码登录，再绑定第三方账号。';
      _notify();
      return Future.value(false);
    }
    if (user?.hasProvider(provider) == true) {
      message = '$label 已绑定。';
      _notify();
      return Future.value(true);
    }
    return _run(() async {
      final repository = _passwordlessRepository;
      if (repository == null) {
        throw const AuthFailure('IDENTITY_LINKING_UNAVAILABLE', '账号绑定暂不可用');
      }
      user = await _attachAvatar(await operation(repository));
      message = '$label 账号已绑定。';
      return true;
    });
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      user = await _attachAvatar(
        await _repository.register(
          email: _validatedEmail(email),
          password: password,
        ),
      );
      lastSuccessfulAuthMethod = 'password';
      registrationCelebrationVersion++;
      message = '账号已创建，验证邮件已发送。完成验证后才能同步数据。';
      return false;
    });
  }

  Future<bool> refreshVerification({bool silently = false}) async {
    if (silently) return _refreshVerificationSilently();
    return _run(() async {
      user = await _attachAvatar(await _repository.reloadUser());
      if (!isVerified) {
        message = '邮箱尚未验证，请打开邮件中的验证链接。';
        return false;
      }
      message = '邮箱验证成功。';
      return true;
    });
  }

  Future<bool> _refreshVerificationSilently() async {
    if (user == null || isVerified) return isVerified;
    final wasVerified = isVerified;
    try {
      user = await _attachAvatar(await _repository.reloadUser());
      if (!wasVerified && isVerified) {
        message = '邮箱验证成功。';
      }
      _notify();
      return isVerified;
    } on AuthFailure {
      // 后台轮询不打断用户输入；下次切回前台或手动刷新会再尝试。
      return false;
    }
  }

  Future<bool> resendVerification() async {
    return _run(() async {
      await _repository.sendEmailVerification();
      message = '验证邮件已重新发送。';
      return false;
    });
  }

  /// Supabase does not create an app session until a confirmed user signs in.
  /// Re-authenticate explicitly after the email link is opened so this also
  /// works when the link was opened on another device, such as a computer.
  Future<bool> confirmEmailVerification({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      message = '请输入注册邮箱和密码后，再检查验证状态。';
      _notify();
      return false;
    }
    return signIn(email: email, password: password);
  }

  /// Leaving the registration flow must not leave stale verification prompts
  /// or a pending email address in memory for the next login attempt.
  void resetAuthenticationFlow() {
    // Reset the visible state immediately. A slow or unavailable Auth service
    // must never prevent a user from going back to the normal login form.
    unawaited(_repository.signOut().catchError((Object _) {}));
    user = null;
    message = null;
    loading = false;
    lastSuccessfulAuthMethod = null;
    _notify();
  }

  /// Clears a transient sign-in status when leaving or reopening the auth
  /// surface. The current session is intentionally left untouched.
  void clearMessage() {
    if (message == null) return;
    message = null;
    _notify();
  }

  Future<bool> updateDisplayName(String displayName) {
    final value = displayName.trim();
    return _run(() async {
      if (value.isEmpty || value.length > 32) {
        throw const AuthFailure('INVALID_DISPLAY_NAME', '用户名需为 1–32 个字符');
      }
      user = await _attachAvatar(await _repository.updateDisplayName(value));
      message = '用户名已更新。';
      return true;
    });
  }

  Future<bool> updateAvatar(XFile image) {
    final current = user;
    if (current == null) {
      message = '请先登录后再修改头像。';
      _notify();
      return Future.value(false);
    }
    return _run(() async {
      final repository = avatarRepository;
      if (repository == null) {
        throw const AuthFailure('AVATAR_SERVICE_UNAVAILABLE', '头像服务暂时不可用');
      }
      final avatarUrl = await repository.upload(image);
      user = current.copyWith(avatarUrl: avatarUrl);
      message = '头像已更新。';
      return true;
    });
  }

  Future<bool> resetPassword(String email) async {
    return _run(() async {
      await _repository.sendPasswordReset(_validatedEmail(email));
      message = '如果该邮箱已注册，密码重置验证码会发送到你的邮箱。';
      return true;
    });
  }

  Future<bool> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) {
    return _run(() async {
      final repository = _passwordRecoveryRepository;
      if (repository == null) {
        throw const AuthFailure('PASSWORD_RECOVERY_UNAVAILABLE', '密码重置暂时不可用');
      }
      if (!RegExp(r'^\d{6}$').hasMatch(token.trim())) {
        throw const AuthFailure('INVALID_OTP', '请输入 6 位验证码');
      }
      await repository.verifyPasswordRecoveryOtp(
        email: _validatedEmail(email),
        token: token,
      );
      // A successful recovery verification is itself an explicit SDK-backed
      // authorization. Set the flag here as well as from the auth event so a
      // synchronous UI transition never depends on stream scheduling.
      passwordRecoveryPending = true;
      message = null;
      return true;
    });
  }

  Future<bool> updateRecoveredPassword(String password) {
    return _run(() async {
      final repository = _passwordRecoveryRepository;
      if (!passwordRecoveryPending || repository == null) {
        throw const AuthFailure(
          'PASSWORD_RECOVERY_REQUIRED',
          '密码重置链接无效或已过期，请重新获取。',
        );
      }
      if (password.length < 8) {
        throw const AuthFailure('WEAK_PASSWORD', '密码至少需要 8 位');
      }
      user = await _attachAvatar(
        await repository.updateRecoveredPassword(password),
      );
      passwordRecoveryPending = false;
      message = '密码已更新。';
      return true;
    });
  }

  Future<void> cancelPasswordRecovery() async {
    passwordRecoveryPending = false;
    await signOut();
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AuthFailure catch (error) {
      message = error.message;
    } finally {
      passwordRecoveryPending = false;
      lastSuccessfulAuthMethod = null;
      user = null;
      _notify();
    }
  }

  Future<bool> deleteAccount(Future<void> Function() deleteRemoteAccount) {
    return _run(() async {
      if (!isVerified) {
        message = '请先完成邮箱验证，再删除账号。';
        return false;
      }
      final deletingUserId = user!.id;
      await deleteRemoteAccount();
      if (user != null && user!.id != deletingUserId) {
        message = '账号已切换，已停止后续退出操作。';
        return false;
      }
      await _repository.signOut();
      if (user != null && user!.id != deletingUserId) return false;
      user = null;
      lastSuccessfulAuthMethod = null;
      message = '账号和云端数据已删除。';
      return true;
    });
  }

  Future<String?> idToken() async {
    if (!isVerified) return null;
    try {
      return await _repository.idToken();
    } on AuthFailure {
      return null;
    }
  }

  Future<AuthUser?> _attachAvatar(AuthUser? nextUser) async {
    if (nextUser == null) return null;
    final repository = avatarRepository;
    if (repository == null) return nextUser;
    try {
      final avatarUrl = await repository.loadAvatarUrl();
      return nextUser.copyWith(avatarUrl: avatarUrl);
    } on ApiException {
      // An unavailable optional avatar endpoint must not block authentication.
      return nextUser;
    }
  }

  Future<bool> _run(Future<bool> Function() operation) async {
    loading = true;
    message = null;
    _notify();
    try {
      return await operation();
    } on AuthFailure catch (error) {
      message = error.message;
      return false;
    } on ApiException catch (error) {
      message = error.message;
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authStateSubscription?.cancel());
    unawaited(_passwordRecoverySubscription?.cancel());
    super.dispose();
  }
}
