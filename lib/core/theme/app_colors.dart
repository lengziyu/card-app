import 'package:flutter/material.dart';

/// H5 同源色板。
///
/// 现有页面仍通过静态色值访问；主题切换时由应用根节点更新色板并整体重建。
/// 后续新增组件应优先使用 [Theme.of]，避免继续扩大静态色板范围。
abstract final class AppColors {
  static bool _dark = false;

  static void configure(Brightness brightness) {
    _dark = brightness == Brightness.dark;
  }

  static bool get isDark => _dark;

  static Color get ink =>
      _dark ? const Color(0xFF070B19) : const Color(0xFFF8FBFF);
  static Color get canvas =>
      _dark ? const Color(0xFF111522) : const Color(0xFFF4F7FF);
  static Color get surface =>
      _dark ? const Color(0xFF232737) : const Color(0xFFFFFFFF);
  static Color get surfaceRaised =>
      _dark ? const Color(0xFF262A3A) : const Color(0xFFF9FAFF);
  static Color get line =>
      _dark ? const Color(0x14FFFFFF) : const Color(0x8AFFFFFF);
  static Color get text =>
      _dark ? const Color(0xFFF2F5FF) : const Color(0xFF10131D);
  static Color get textMuted =>
      _dark ? const Color(0xFF9DA5B8) : const Color(0xFF8A92A5);
  static Color get violet =>
      _dark ? const Color(0xFF8F73FF) : const Color(0xFF8B68FF);
  static Color get cyan =>
      _dark ? const Color(0xFF8B91FF) : const Color(0xFF5C73FF);
  static Color get mint => const Color(0xFF43D0B5);
  static Color get pink => const Color(0xFFFF8EDB);

  static Color get glass => _dark
      ? const Color.fromRGBO(35, 39, 55, 0.66)
      : const Color.fromRGBO(255, 255, 255, 0.58);
  static Color get glassStrong => _dark
      ? const Color.fromRGBO(38, 42, 58, 0.82)
      : const Color.fromRGBO(255, 255, 255, 0.72);
  static Color get navIcon =>
      _dark ? const Color(0xFFADB4C8) : const Color(0xFF697185);
  static Color get selectedWash =>
      _dark ? const Color(0x52777DFF) : const Color(0x665C73FF);
}
