import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xFF8B91FF) : const Color(0xFF5C73FF),
      brightness: brightness,
      surface: isDark ? const Color(0xFF232737) : Colors.white,
    );
    final interactionStyle = ButtonStyle(
      animationDuration: MotionTokens.stateChange,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.pressed)) return null;
        return scheme.primary.withValues(alpha: isDark ? .13 : .08);
      }),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF070B19)
          : const Color(0xFFF8FBFF),
      fontFamilyFallback: const [
        'Inter',
        'SF Pro Display',
        'PingFang SC',
        'Hiragino Sans GB',
        'Microsoft YaHei',
      ],
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(style: interactionStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: interactionStyle),
      textButtonTheme: TextButtonThemeData(style: interactionStyle),
      iconButtonTheme: IconButtonThemeData(style: interactionStyle),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: isDark ? const Color(0xFFF2F5FF) : const Color(0xFF10131D),
          fontSize: 27,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.35,
          height: 1.05,
        ),
        titleLarge: TextStyle(
          color: isDark ? const Color(0xFFF2F5FF) : const Color(0xFF10131D),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        bodyMedium: TextStyle(
          color: isDark ? const Color(0xFF9DA5B8) : const Color(0xFF8A92A5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}
