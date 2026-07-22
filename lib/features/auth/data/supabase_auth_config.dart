class SupabaseAuthConfig {
  const SupabaseAuthConfig._();

  static const enabled = bool.fromEnvironment(
    'ENABLE_SUPABASE_AUTH',
    defaultValue: true,
  );
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://card.lengziyu.cn/supabase',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Uv-jnzN8s9eormjr2bdnIw_vOJ7zyYa',
  );
  static const emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_EMAIL_REDIRECT_URL',
    defaultValue: 'cn.lengziyu.cardapp://auth-callback',
  );

  static bool get configured {
    final uri = Uri.tryParse(url);
    return enabled &&
        uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        publishableKey.isNotEmpty;
  }
}
