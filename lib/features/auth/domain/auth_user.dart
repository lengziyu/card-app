enum AuthLoginProvider { email, google, apple }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    this.avatarUrl,
    this.loginProviders = const <AuthLoginProvider>{},
    this.createdAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final String? avatarUrl;
  final Set<AuthLoginProvider> loginProviders;
  final String? createdAt;

  AuthUser copyWith({
    String? displayName,
    String? avatarUrl,
    Set<AuthLoginProvider>? loginProviders,
  }) => AuthUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    emailVerified: emailVerified,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    loginProviders: loginProviders ?? this.loginProviders,
    createdAt: createdAt,
  );

  bool appearsRecentlyRegistered({DateTime? now}) {
    final created = DateTime.tryParse(createdAt ?? '')?.toUtc();
    if (created == null) return false;
    final age = (now ?? DateTime.now()).toUtc().difference(created);
    return age >= const Duration(minutes: -5) &&
        age <= const Duration(hours: 2);
  }

  bool hasProvider(AuthLoginProvider provider) =>
      loginProviders.contains(provider);

  String get profileName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final address = email?.trim() ?? '';
    final separator = address.indexOf('@');
    if (separator > 0) return address.substring(0, separator);
    if (address.isNotEmpty) return address;
    return '账号用户';
  }

  String get handle => '@$profileName';

  String get label => profileName;

  String get initial {
    final value = label.trim();
    return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
  }
}
