import 'package:shared_preferences/shared_preferences.dart';

class PendingReferralStore {
  static const _key = 'pending-referral-code-v1';

  Future<void> save(String value) async {
    final code = value.trim().toUpperCase();
    if (code.isEmpty) return;
    await (await SharedPreferences.getInstance()).setString(_key, code);
  }

  Future<String?> read() async {
    final value = (await SharedPreferences.getInstance())
        .getString(_key)
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
