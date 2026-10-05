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
  // This distinct redirect marker lets the shared Supabase recovery template
  // show a code to current builds while keeping the legacy link for already
  // released clients during the compatibility window.
  static const passwordRecoveryOtpRedirectUrl = String.fromEnvironment(
    'SUPABASE_PASSWORD_RECOVERY_OTP_REDIRECT_URL',
    defaultValue:
        'cn.lengziyu.cardapp://auth-callback?mode=password-recovery-otp',
  );
  static const googleAuthEnabled = bool.fromEnvironment(
    'ENABLE_GOOGLE_AUTH',
    defaultValue: false,
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const appleAuthEnabled = bool.fromEnvironment(
    'ENABLE_APPLE_AUTH',
    defaultValue: false,
  );

  static bool get googleConfigured =>
      configured && googleAuthEnabled && googleWebClientId.trim().isNotEmpty;

  static bool get appleConfigured => configured && appleAuthEnabled;

  static bool get configured {
    final uri = Uri.tryParse(url);
    return enabled &&
        uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        publishableKey.isNotEmpty;
  }
}
