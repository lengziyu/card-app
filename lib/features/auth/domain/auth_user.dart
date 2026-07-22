class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool emailVerified;

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
