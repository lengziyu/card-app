import 'package:card_app/core/localization/app_language.dart';
import 'package:card_app/core/localization/app_localizations.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/theme/app_theme.dart';
import 'package:card_app/features/auth/data/auth_repository.dart';
import 'package:card_app/features/pro/data/pro_controller.dart';
import 'package:card_app/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardApp extends StatefulWidget {
  const CardApp({
    this.enableRemoteData = false,
    this.proUnlocked = false,
    this.proAccessTokenProvider,
    this.proApplicationUserNameProvider,
    this.authRepository,
    super.key,
  });

  final bool enableRemoteData;
  final bool proUnlocked;
  final ProAccessTokenProvider? proAccessTokenProvider;
  final ProApplicationUserNameProvider? proApplicationUserNameProvider;
  final AuthRepository? authRepository;

  @override
  State<CardApp> createState() => _CardAppState();
}

class _CardAppState extends State<CardApp> {
  static const _themePreferenceKey = 'card-h5-theme-v1';
  static const _languagePreferenceKey = 'card-app-language-v1';
  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.system;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
    _restoreLanguage();
  }

  Future<void> _restoreLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    final storedLanguage = AppLanguage.fromStorage(
      preferences.getString(_languagePreferenceKey),
    );
    final savedLanguage = AppLanguage.releaseLanguages.contains(storedLanguage)
        ? storedLanguage
        : AppLanguage.system;
    if (!mounted || savedLanguage == _language) return;
    setState(() => _language = savedLanguage);
  }

  void _changeLanguage(AppLanguage language) {
    if (language == _language) return;
    setState(() => _language = language);
    SharedPreferences.getInstance().then(
      (preferences) =>
          preferences.setString(_languagePreferenceKey, language.storageKey),
    );
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
      onGenerateTitle: (context) => context.tr('集卡'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      locale: _language.locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (_language != AppLanguage.system) return _language.locale;
        return AppLanguage.resolveDeviceLocale(deviceLocale);
      },
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(
        enableRemoteData: widget.enableRemoteData,
        proUnlocked: widget.proUnlocked,
        proAccessTokenProvider: widget.proAccessTokenProvider,
        proApplicationUserNameProvider: widget.proApplicationUserNameProvider,
        authRepository: widget.authRepository,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
        selectedLanguage: _language,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }
}
