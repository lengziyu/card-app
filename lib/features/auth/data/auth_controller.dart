import 'package:card_app/features/auth/data/auth_repository.dart';
import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/features/auth/domain/auth_user.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthUser? user;
  bool loading = true;
  String? message;
  bool _disposed = false;

  bool get configured => _repository.configured;
  bool get isVerified => user?.emailVerified == true;

  Future<void> initialize() async {
    loading = true;
    _notify();
    try {
      user = await _repository.initialize();
      message = user != null && !isVerified ? '请先完成邮箱验证。' : null;
    } on AuthFailure catch (error) {
      message = error.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      try {
        user = await _repository.signIn(email: email, password: password);
      } on AuthFailure catch (error) {
        if (error.code == 'EMAIL_NOT_VERIFIED') {
          // Supabase intentionally does not expose a session for an
          // unconfirmed user. Keep only enough local state to offer resend
          // and explicit verification checking; it is not an authenticated
          // account and cannot produce an access token.
          user = AuthUser(
            id: 'pending:${email.trim().toLowerCase()}',
            email: email.trim().toLowerCase(),
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
      message = '登录成功。';
      return true;
    });
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      user = await _repository.register(email: email, password: password);
      message = '账号已创建，验证邮件已发送。完成验证后才能同步数据。';
      return false;
    });
  }

  Future<bool> refreshVerification({bool silently = false}) async {
    if (silently) return _refreshVerificationSilently();
    return _run(() async {
      user = await _repository.reloadUser();
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
      user = await _repository.reloadUser();
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
  Future<void> resetAuthenticationFlow() async {
    try {
      await _repository.signOut();
    } on AuthFailure {
      // A local reset should still succeed if an old session has expired.
    } finally {
      user = null;
      message = null;
      loading = false;
      _notify();
    }
  }

  Future<bool> updateDisplayName(String displayName) {
    final value = displayName.trim();
    return _run(() async {
      if (value.isEmpty || value.length > 32) {
        throw const AuthFailure('INVALID_DISPLAY_NAME', '用户名需为 1–32 个字符');
      }
      user = await _repository.updateDisplayName(value);
      message = '用户名已更新。';
      return true;
    });
  }

  Future<bool> resetPassword(String email) async {
    return _run(() async {
      await _repository.sendPasswordReset(email);
      message = '如果该邮箱已注册，密码重置邮件会发送到你的邮箱。';
      return false;
    });
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AuthFailure catch (error) {
      message = error.message;
    } finally {
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
      await deleteRemoteAccount();
      await _repository.signOut();
      user = null;
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
    super.dispose();
  }
}
