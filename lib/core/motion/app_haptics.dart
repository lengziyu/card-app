import 'package:flutter/services.dart';

enum AppHapticStrength { weak, medium, strong }

extension AppHapticStrengthLabel on AppHapticStrength {
  String get label => switch (this) {
    AppHapticStrength.weak => '弱',
    AppHapticStrength.medium => '中',
    AppHapticStrength.strong => '高',
  };
}

abstract final class AppHaptics {
  static bool enabled = true;
  static bool cardSwipeEnabled = true;
  static AppHapticStrength strength = AppHapticStrength.medium;

  static void configure({
    required bool hapticsEnabled,
    required bool swipeHapticsEnabled,
    required AppHapticStrength hapticStrength,
  }) {
    enabled = hapticsEnabled;
    cardSwipeEnabled = swipeHapticsEnabled;
    strength = hapticStrength;
  }

  static Future<void> selection() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> lightImpact() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> cardSwipe() async {
    if (!enabled || !cardSwipeEnabled) return;
    await switch (strength) {
      AppHapticStrength.weak => HapticFeedback.selectionClick(),
      AppHapticStrength.medium => HapticFeedback.lightImpact(),
      AppHapticStrength.strong => HapticFeedback.mediumImpact(),
    };
  }
}
