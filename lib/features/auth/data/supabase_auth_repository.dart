import 'dart:async';
import 'dart:convert';

import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/data/secure_supabase_storage.dart';
import 'package:cardfi/features/auth/data/supabase_auth_config.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseAuthRepository
    implements
        AuthRepository,
        AuthStateRepository,
        PasswordRecoveryRepository,
        PasswordlessAuthRepository,
        LinkedIdentityManagementRepository {
  SupabaseAuthRepository({
    supabase.SupabaseClient? clientOverride,
    this.registerAppleAuthorizationCode,
    this.revokeAppleCredential,
    this.googleCredentialProvider,
  }) : _client = clientOverride;

  supabase.SupabaseClient? _client;
  final Future<void> Function(String authorizationCode, String? accessToken)?
  registerAppleAuthorizationCode;
  final Future<void> Function()? revokeAppleCredential;
  final Future<({String idToken, String accessToken})> Function()?
  googleCredentialProvider;
  Future<supabase.SupabaseClient>? _initializing;
  Future<void>? _googleInitializing;
  supabase.User? _pendingUser;
  String? _pendingEmail;

  @override
  bool get configured => SupabaseAuthConfig.configured;

  @override
  bool get googleConfigured {
    if (!SupabaseAuthConfig.googleConfigured || kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return SupabaseAuthConfig.googleIosClientId.trim().isNotEmpty;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  bool get appleConfigured =>
      SupabaseAuthConfig.appleConfigured &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

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
      // A recovery link creates a short-lived authenticated session, but it
      // must not be exposed as a normal signed-in app session until the user
      // has explicitly chosen and submitted a new password.
      if (state.event == supabase.AuthChangeEvent.passwordRecovery) continue;
      yield _mapUser(state.session?.user ?? client.auth.currentUser);
    }
  }

  @override
  Stream<void> get passwordRecoveryEvents async* {
    final client = await _requireClient();
    await for (final state in client.auth.onAuthStateChange) {
      if (state.event == supabase.AuthChangeEvent.passwordRecovery) yield null;
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
  Future<void> sendEmailOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      await (await _requireClient()).auth.signInWithOtp(
        email: normalizedEmail,
        shouldCreateUser: true,
      );
      _pendingEmail = normalizedEmail;
      _pendingUser = null;
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await (await _requireClient()).auth.verifyOTP(
        email: normalizedEmail,
        token: token.trim(),
        type: supabase.OtpType.email,
      );
      _pendingEmail = null;
      _pendingUser = null;
      return _requireUser(response.user);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() => _authenticateWithGoogle(link: false);

  @override
  Future<AuthUser> linkGoogleIdentity() => _authenticateWithGoogle(link: true);

  Future<AuthUser> _authenticateWithGoogle({required bool link}) async {
    if (!googleConfigured && googleCredentialProvider == null) {
      throw const AuthFailure('GOOGLE_NOT_CONFIGURED', 'Google 登录尚未配置');
    }
    try {
      final credential =
          await (googleCredentialProvider ?? _googleCredential)();
      final auth = (await _requireClient()).auth;
      final response = link
          ? await auth.linkIdentityWithIdToken(
              provider: supabase.OAuthProvider.google,
              idToken: credential.idToken,
              accessToken: credential.accessToken,
            )
          : await auth.signInWithIdToken(
              provider: supabase.OAuthProvider.google,
              idToken: credential.idToken,
              accessToken: credential.accessToken,
            );
      return _requireUser(response.user ?? auth.currentUser);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('AUTH_CANCELLED', '已取消 Google 登录');
      }
      throw const AuthFailure('GOOGLE_AUTH_FAILED', 'Google 登录失败，请稍后重试');
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  static const _googleIdentityScopes = <String>['email', 'profile'];

  Future<({String idToken, String accessToken})> _googleCredential() async {
    await _initializeGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: _googleIdentityScopes,
    );
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure('GOOGLE_TOKEN_MISSING', 'Google 登录未返回有效凭据');
    }
    final authorization =
        await account.authorizationClient.authorizationForScopes(
          _googleIdentityScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(
          _googleIdentityScopes,
        );
    final accessToken = authorization.accessToken.trim();
    if (accessToken.isEmpty) {
      throw const AuthFailure('GOOGLE_TOKEN_MISSING', 'Google 登录未返回有效凭据');
    }
    return (idToken: idToken, accessToken: accessToken);
  }

  Future<void> _initializeGoogleSignIn() {
    if (_googleInitializing case final initializing?) return initializing;
    final iosClientId = SupabaseAuthConfig.googleIosClientId.trim();
    return _googleInitializing = GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
      serverClientId: SupabaseAuthConfig.googleWebClientId.trim(),
    );
  }

  @override
  Future<AuthUser> signInWithApple() => _authenticateWithApple(link: false);

  @override
  Future<AuthUser> linkAppleIdentity() => _authenticateWithApple(link: true);

  @override
  Future<AuthUser> unlinkGoogleIdentity() => _unlinkIdentity(
    provider: AuthLoginProvider.google,
    providerName: 'google',
  );

  @override
  Future<AuthUser> unlinkAppleIdentity() => _unlinkIdentity(
    provider: AuthLoginProvider.apple,
    providerName: 'apple',
    beforeUnlink: revokeAppleCredential,
  );

  Future<AuthUser> _unlinkIdentity({
    required AuthLoginProvider provider,
    required String providerName,
    Future<void> Function()? beforeUnlink,
  }) async {
    try {
      final auth = (await _requireClient()).auth;
      final user = auth.currentUser;
      if (user == null) {
        throw const AuthFailure('UNAUTHORIZED', '请重新登录后再管理登录方式');
      }
      final identities = user.identities ?? const <supabase.UserIdentity>[];
      final identity = identities
          .where((item) => item.provider == providerName)
          .firstOrNull;
      if (identity == null) {
        final label = provider == AuthLoginProvider.apple ? 'Apple' : 'Google';
        throw AuthFailure('IDENTITY_NOT_LINKED', '$label 尚未绑定到当前账号');
      }
      if (identities.length <= 1) {
        throw const AuthFailure(
          'LAST_IDENTITY_REQUIRED',
          '请先绑定另一种登录方式，再解除当前绑定',
        );
      }
      if (provider == AuthLoginProvider.apple && beforeUnlink == null) {
        throw const AuthFailure(
          'APPLE_UNLINK_NOT_CONFIGURED',
          'Apple 授权撤销服务尚未配置',
        );
      }
      await beforeUnlink?.call();
      await auth.unlinkIdentity(identity);
      return _requireUser((await auth.getUser()).user);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  Future<AuthUser> _authenticateWithApple({required bool link}) async {
    if (!appleConfigured) {
      throw const AuthFailure('APPLE_NOT_CONFIGURED', 'Apple 登录尚未配置');
    }
    try {
      final client = await _requireClient();
      final rawNonce = client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('APPLE_TOKEN_MISSING', 'Apple 登录未返回有效凭据');
      }
      final response = link
          ? await client.auth.linkIdentityWithIdToken(
              provider: supabase.OAuthProvider.apple,
              idToken: idToken,
              nonce: rawNonce,
            )
          : await client.auth.signInWithIdToken(
              provider: supabase.OAuthProvider.apple,
              idToken: idToken,
              nonce: rawNonce,
            );
      var user = response.user ?? client.auth.currentUser;
      final accessToken =
          response.session?.accessToken ??
          client.auth.currentSession?.accessToken;
      final fullName = [credential.givenName, credential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty) {
        user = (await client.auth.updateUser(
          supabase.UserAttributes(
            data: {'display_name': fullName, 'full_name': fullName},
          ),
        )).user;
      }
      final registerAuthorizationCode = registerAppleAuthorizationCode;
      if (registerAuthorizationCode != null) {
        try {
          await registerAuthorizationCode(
            credential.authorizationCode,
            accessToken,
          );
        } catch (_) {
          await client.auth.signOut(scope: supabase.SignOutScope.local);
          rethrow;
        }
      }
      return _requireUser(user);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthFailure('AUTH_CANCELLED', '已取消 Apple 登录');
      }
      throw const AuthFailure('APPLE_AUTH_FAILED', 'Apple 登录失败，请稍后重试');
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
        redirectTo: SupabaseAuthConfig.passwordRecoveryOtpRedirectUrl,
      );
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await (await _requireClient()).auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: supabase.OtpType.recovery,
      );
      _requireUser(response.user);
    } on supabase.AuthException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<AuthUser> updateRecoveredPassword(String password) async {
    try {
      final response = await (await _requireClient()).auth.updateUser(
        supabase.UserAttributes(password: password),
      );
      return _requireUser(response.user);
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
    final displayName =
        (metadata?['display_name'] ??
                metadata?['full_name'] ??
                metadata?['name'])
            ?.toString()
            .trim();
    final providers = <AuthLoginProvider>{
      for (final identity in user.identities ?? const <supabase.UserIdentity>[])
        ?_mapProvider(identity.provider),
    };
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: displayName?.isEmpty == true ? null : displayName,
      emailVerified: user.emailConfirmedAt != null,
      loginProviders: providers,
      createdAt: user.createdAt,
    );
  }

  AuthLoginProvider? _mapProvider(String provider) => switch (provider) {
    'email' => AuthLoginProvider.email,
    'google' => AuthLoginProvider.google,
    'apple' => AuthLoginProvider.apple,
    _ => null,
  };

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
      'same_password' => const AuthFailure(
        'SAME_PASSWORD',
        '新密码不能与当前密码相同，请更换一个新密码',
      ),
      'reauthentication_needed' ||
      'reauthentication_not_valid' ||
      'session_not_found' ||
      'refresh_token_not_found' => const AuthFailure(
        'PASSWORD_RECOVERY_EXPIRED',
        '密码重置验证已失效，请重新获取验证码',
      ),
      'validation_failed' => const AuthFailure(
        'PASSWORD_VALIDATION_FAILED',
        '新密码不符合当前密码规则，请更换后重试',
      ),
      'email_not_confirmed' => const AuthFailure(
        'EMAIL_NOT_VERIFIED',
        '邮箱尚未验证，请打开验证邮件中的链接后再检查。',
      ),
      'otp_expired' => const AuthFailure('OTP_EXPIRED', '验证码无效或已过期，请重新获取'),
      'otp_disabled' => const AuthFailure('OTP_DISABLED', '邮箱验证码登录暂未开放'),
      'identity_already_exists' => const AuthFailure(
        'IDENTITY_ALREADY_EXISTS',
        '这个登录方式已经绑定到其他账号',
      ),
      'manual_linking_disabled' => const AuthFailure(
        'IDENTITY_LINKING_DISABLED',
        '账号绑定尚未在认证服务中启用',
      ),
      'provider_disabled' => const AuthFailure(
        'PROVIDER_DISABLED',
        '这个登录方式暂未开放',
      ),
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        const AuthFailure('RATE_LIMITED', '尝试次数过多，请稍后再试'),
      'request_timeout' => const AuthFailure(
        'REQUEST_TIMEOUT',
        '请求超时，请检查网络后重试',
      ),
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
