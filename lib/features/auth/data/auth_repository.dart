import 'package:card_app/features/auth/domain/auth_user.dart';

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
