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
  bool _disposed = false;
  StreamSubscription<AuthUser?>? _authStateSubscription;
  int _authStateVersion = 0;

  bool get configured => _repository.configured;
  bool get isVerified => user?.emailVerified == true;

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
    if (_authStateSubscription != null || _repository is! AuthStateRepository) {
      return;
    }
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

  Future<void> _applyRepositoryUser(AuthUser? nextUser, int version) async {
    final next = await _attachAvatar(nextUser);
    if (_disposed || version != _authStateVersion) return;
    user = next;
    if (next == null) message = null;
    _notify();
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      try {
        user = await _attachAvatar(
          await _repository.signIn(email: email, password: password),
        );
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
      user = await _attachAvatar(
        await _repository.register(email: email, password: password),
      );
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
    super.dispose();
  }
}
