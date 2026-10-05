import 'package:cardfi/features/auth/domain/auth_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  bool get configured;

  Future<AuthUser?> initialize();

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> register({required String email, required String password});

  Future<AuthUser?> reloadUser();

  Future<AuthUser> updateDisplayName(String displayName);

  Future<void> sendEmailVerification();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  Future<String?> idToken();
}

/// Optional live session updates for repositories whose access token can be
/// refreshed or revoked outside an explicit sign-in/sign-out call.
abstract interface class AuthStateRepository {
  Stream<AuthUser?> get authStateChanges;
}

/// Optional password-recovery support for repositories that can verify a
/// recovery OTP or accept a legacy recovery deep link, producing a short-lived
/// authenticated session.
///
/// The recovery event must come from the authentication SDK. A normal sign-in
/// session must never be treated as authorization to display the reset form.
abstract interface class PasswordRecoveryRepository {
  Stream<void> get passwordRecoveryEvents;

  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  });

  Future<AuthUser> updateRecoveredPassword(String password);
}

/// Passwordless and native identity operations used by current CardFi builds.
///
/// The password methods on [AuthRepository] remain available temporarily so
/// already-released clients can continue to use existing Supabase accounts
/// during the compatibility window.
abstract interface class PasswordlessAuthRepository {
  bool get googleConfigured;

  bool get appleConfigured;

  Future<void> sendEmailOtp(String email);

  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Future<AuthUser> linkGoogleIdentity();

  Future<AuthUser> linkAppleIdentity();
}

/// Optional identity removal support for account settings.
///
/// Implementations must reject removal when it would leave the account with
/// no remaining login identity.
abstract interface class LinkedIdentityManagementRepository {
  Future<AuthUser> unlinkGoogleIdentity();

  Future<AuthUser> unlinkAppleIdentity();
}
