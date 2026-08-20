abstract final class LegalConfig {
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  static const termsOfUseUrl = String.fromEnvironment(
    'TERMS_OF_USE_URL',
    defaultValue: '',
  );

  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue: '',
  );

  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '',
  );

  static Uri? httpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) return null;
    return uri;
  }

  static Uri? get supportEmailUri {
    final value = supportEmail.trim();
    if (value.isEmpty || !value.contains('@')) return null;
    return Uri(
      scheme: 'mailto',
      path: value,
      queryParameters: {'subject': 'CardFi 支持请求'},
    );
  }
}
