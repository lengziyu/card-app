import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/theme/app_theme.dart';
import 'package:card_app/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardApp extends StatefulWidget {
  const CardApp({this.enableRemoteData = false, super.key});

  final bool enableRemoteData;

  @override
  State<CardApp> createState() => _CardAppState();
}

class _CardAppState extends State<CardApp> {
  static const _themePreferenceKey = 'card-h5-theme-v1';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString(_themePreferenceKey);
    if (!mounted || savedTheme != 'dark') return;
    setState(() => _themeMode = ThemeMode.dark);
  }

  void _toggleTheme() {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });
    SharedPreferences.getInstance().then(
      (preferences) => preferences.setString(
        _themePreferenceKey,
        nextMode == ThemeMode.dark ? 'dark' : 'light',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;
    AppColors.configure(brightness);
    return MaterialApp(
      title: '集卡',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: AppShell(
        enableRemoteData: widget.enableRemoteData,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
