import 'dart:async';

import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/data/secure_supabase_storage.dart';
import 'package:cardfi/features/auth/data/supabase_auth_config.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseAuthRepository implements AuthRepository, AuthStateRepository {
  SupabaseAuthRepository({supabase.SupabaseClient? clientOverride})
    : _client = clientOverride;

  supabase.SupabaseClient? _client;
  Future<supabase.SupabaseClient>? _initializing;
  supabase.User? _pendingUser;
  String? _pendingEmail;

  @override
  bool get configured => SupabaseAuthConfig.configured;

  @override
  Future<AuthUser?> initialize() async {
    final client = await _requireClient();
    await _refreshExpiredSession(client);
    return _mapUser(client.auth.currentUser ?? _pendingUser);
  }

  @override
  Stream<AuthUser?> get authStateChanges async* {
    final client = await _requireClient();
    await for (final state in client.auth.onAuthStateChange) {
      yield _mapUser(state.session?.user ?? client.auth.currentUser);
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final client = await _requireClient();
      final response = await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      _pendingEmail = null;
      _pendingUser = null;
      return _requireUser(response.user);
    } on supabase.AuthException catch (error) {
      if (error.code == 'email_not_confirmed') {
        _pendingEmail = normalizedEmail;
      }
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await (await _requireClient()).auth.signUp(
        email: normalizedEmail,
        password: password,
        emailRedirectTo: SupabaseAuthConfig.emailRedirectUrl,
      );
      _pendingEmail = normalizedEmail;
      _pendingUser = response.user;
      return _requireUser(response.user);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser?> reloadUser() async {
    try {
      final client = await _requireClient();
      if (client.auth.currentSession == null) return _mapUser(_pendingUser);
      final response = await client.auth.getUser();
      _pendingUser = null;
      _pendingEmail = null;
      return _mapUser(response.user);
    } on supabase.AuthSessionMissingException {
      return _mapUser(_pendingUser);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    try {
      final response = await (await _requireClient()).auth.updateUser(
        supabase.UserAttributes(data: {'display_name': displayName.trim()}),
      );
      return _requireUser(response.user);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final client = await _requireClient();
    final email = (_pendingEmail ?? client.auth.currentUser?.email)?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthFailure('AUTH_REQUIRED', '请先输入需要验证的邮箱地址');
    }
    try {
      await client.auth.resend(
        type: supabase.OtpType.signup,
        email: email,
        emailRedirectTo: SupabaseAuthConfig.emailRedirectUrl,
      );
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await (await _requireClient()).auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: SupabaseAuthConfig.emailRedirectUrl,
      );
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final client = await _requireClient();
      await client.auth.signOut(scope: supabase.SignOutScope.local);
      _pendingEmail = null;
      _pendingUser = null;
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<String?> idToken() async {
    final client = await _requireClient();
    final session = await _refreshExpiredSession(client);
    if (session?.user.emailConfirmedAt == null) return null;
    return session?.accessToken;
  }

  Future<supabase.Session?> _refreshExpiredSession(
    supabase.SupabaseClient client,
  ) async {
    final current = client.auth.currentSession;
    if (current == null || !current.isExpired) return current;
    try {
      final response = await client.auth.refreshSession();
      return response.session;
    } on supabase.AuthSessionMissingException {
      return null;
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  Future<supabase.SupabaseClient> _requireClient() async {
    if (!configured) {
      throw const AuthFailure(
        'AUTH_NOT_CONFIGURED',
        'Supabase 登录尚未配置，请先完成项目和构建参数设置。',
      );
    }
    if (_client case final client?) return client;
    if (_initializing case final initializing?) return initializing;
    final initializing = _initializeClient();
    _initializing = initializing;
    try {
      return await initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<supabase.SupabaseClient> _initializeClient() async {
    try {
      final instance = await supabase.Supabase.initialize(
        url: SupabaseAuthConfig.url,
        publishableKey: SupabaseAuthConfig.publishableKey,
        authOptions: supabase.FlutterAuthClientOptions(
          authFlowType: supabase.AuthFlowType.pkce,
          localStorage: SecureSupabaseStorage(),
        ),
      );
      return _client = instance.client;
    } catch (error, stackTrace) {
      assert(() {
        debugPrint(
          'Supabase Auth initialization failed: '
          '${error.runtimeType}: $error\n$stackTrace',
        );
        return true;
      }());
      throw const AuthFailure(
        'AUTH_NOT_CONFIGURED',
        'Supabase 登录初始化失败，请检查项目配置。',
      );
    }
  }

  AuthUser _requireUser(supabase.User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw const AuthFailure('AUTH_FAILED', '登录服务未返回有效账号');
    }
    return mapped;
  }

  AuthUser? _mapUser(supabase.User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    final displayName = metadata?['display_name']?.toString().trim();
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: displayName?.isEmpty == true ? null : displayName,
      emailVerified: user.emailConfirmedAt != null,
    );
  }

  AuthFailure _failureFor(supabase.AuthException error) {
    final code = error.code ?? '';
    return switch (code) {
      'invalid_credentials' => const AuthFailure(
        'INVALID_CREDENTIALS',
        '登录失败，请检查邮箱和密码；如已删除账号，请重新注册',
      ),
      'email_exists' ||
      'user_already_exists' => const AuthFailure('EMAIL_EXISTS', '这个邮箱已经注册'),
      'weak_password' => const AuthFailure(
        'WEAK_PASSWORD',
        '密码强度不足，请至少使用 8 位字符',
      ),
      'email_not_confirmed' => const AuthFailure(
        'EMAIL_NOT_VERIFIED',
        '邮箱尚未验证，请打开验证邮件中的链接后再检查。',
      ),
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        const AuthFailure('RATE_LIMITED', '尝试次数过多，请稍后再试'),
      'signup_disabled' || 'email_provider_disabled' => const AuthFailure(
        'SIGNUP_DISABLED',
        '当前暂未开放邮箱注册',
      ),
      'user_banned' => const AuthFailure('USER_DISABLED', '这个账号已停用'),
      _ when error is supabase.AuthRetryableFetchException => const AuthFailure(
        'NETWORK_ERROR',
        '认证服务连接失败，请检查网络后重试',
      ),
      _ => const AuthFailure('AUTH_FAILED', '登录服务暂时不可用，请稍后重试'),
    };
  }
}
