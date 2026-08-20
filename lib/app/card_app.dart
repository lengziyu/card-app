import 'package:cardfi/app/startup_splash.dart';
import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/country_localizations_delegate.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/theme/app_theme.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/pro/data/pro_controller.dart';
import 'package:cardfi/features/shell/presentation/app_shell.dart';
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
  bool _preferencesReady = false;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedLanguage = AppLanguage.fromStorage(
        preferences.getString(_languagePreferenceKey),
      );
      final savedLanguage =
          AppLanguage.releaseLanguages.contains(storedLanguage)
          ? storedLanguage
          : AppLanguage.system;
      final savedTheme = preferences.getString(_themePreferenceKey);
      if (!mounted) return;
      setState(() {
        _language = savedLanguage;
        _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        _preferencesReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferencesReady = true);
    }
  }

  void _changeLanguage(AppLanguage language) {
    if (language == _language) return;
    setState(() => _language = language);
    SharedPreferences.getInstance().then(
      (preferences) =>
          preferences.setString(_languagePreferenceKey, language.storageKey),
    );
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
      onGenerateTitle: (context) => 'CardFi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      // Keep the app from showing a mixed light/dark frame. Custom surfaces
      // read Theme.brightness directly, so the framework's default theme
      // interpolation otherwise leaves them on the old palette too long.
      themeAnimationDuration: MotionTokens.instant,
      themeAnimationCurve: Curves.easeOutCubic,
      locale: _language.locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (_language != AppLanguage.system) return _language.locale;
        return AppLanguage.resolveDeviceLocale(deviceLocale);
      },
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        appCountryLocalizationsDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _preferencesReady
          ? CardFiStartupTransition(
              child: AppShell(
                enableRemoteData: widget.enableRemoteData,
                proUnlocked: widget.proUnlocked,
                proAccessTokenProvider: widget.proAccessTokenProvider,
                proApplicationUserNameProvider:
                    widget.proApplicationUserNameProvider,
                authRepository: widget.authRepository,
                isDarkMode: _themeMode == ThemeMode.dark,
                onToggleTheme: _toggleTheme,
                selectedLanguage: _language,
                onLanguageChanged: _changeLanguage,
              ),
            )
          : const CardFiStartupPlaceholder(),
    );
  }
}
