import 'package:card_app/features/auth/data/supabase_auth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase Auth is the default production authentication provider', () {
    expect(SupabaseAuthConfig.enabled, isTrue);
    expect(SupabaseAuthConfig.configured, isTrue);
    expect(SupabaseAuthConfig.url, 'https://card.lengziyu.cn/supabase');
    expect(SupabaseAuthConfig.publishableKey, startsWith('sb_publishable_'));
  });
}
