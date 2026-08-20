import 'package:flutter/widgets.dart';

enum AppLanguage {
  system(
    storageKey: 'system',
    flag: '⚙️',
    nativeName: '跟随系统',
    shortLabel: '系统',
  ),
  simplifiedChinese(
    storageKey: 'zh-CN',
    flag: '🇨🇳',
    nativeName: '简体中文',
    shortLabel: '简体中文',
    locale: Locale('zh', 'CN'),
  ),
  traditionalChinese(
    storageKey: 'zh-HK',
    flag: '🇭🇰',
    nativeName: '繁體中文',
    shortLabel: '繁體中文',
    locale: Locale('zh', 'HK'),
  ),
  english(
    storageKey: 'en-US',
    flag: '🇺🇸',
    nativeName: 'English',
    shortLabel: 'English',
    locale: Locale('en', 'US'),
  ),
  japanese(
    storageKey: 'ja-JP',
    flag: '🇯🇵',
    nativeName: '日本語',
    shortLabel: '日本語',
    locale: Locale('ja', 'JP'),
  ),
  korean(
    storageKey: 'ko-KR',
    flag: '🇰🇷',
    nativeName: '한국어',
    shortLabel: '한국어',
    locale: Locale('ko', 'KR'),
  ),
  vietnamese(
    storageKey: 'vi-VN',
    flag: '🇻🇳',
    nativeName: 'Tiếng Việt',
    shortLabel: 'Tiếng Việt',
    locale: Locale('vi', 'VN'),
  ),
  russian(
    storageKey: 'ru-RU',
    flag: '🇷🇺',
    nativeName: 'Русский',
    shortLabel: 'Русский',
    locale: Locale('ru', 'RU'),
  ),
  spanish(
    storageKey: 'es-ES',
    flag: '🇪🇸',
    nativeName: 'Español',
    shortLabel: 'Español',
    locale: Locale('es', 'ES'),
  ),
  french(
    storageKey: 'fr-FR',
    flag: '🇫🇷',
    nativeName: 'Français',
    shortLabel: 'Français',
    locale: Locale('fr', 'FR'),
  ),
  german(
    storageKey: 'de-DE',
    flag: '🇩🇪',
    nativeName: 'Deutsch',
    shortLabel: 'Deutsch',
    locale: Locale('de', 'DE'),
  ),
  portugueseBrazil(
    storageKey: 'pt-BR',
    flag: '🇧🇷',
    nativeName: 'Português (Brasil)',
    shortLabel: 'Português',
    locale: Locale('pt', 'BR'),
  ),
  turkish(
    storageKey: 'tr-TR',
    flag: '🇹🇷',
    nativeName: 'Türkçe',
    shortLabel: 'Türkçe',
    locale: Locale('tr', 'TR'),
  );

  const AppLanguage({
    required this.storageKey,
    required this.flag,
    required this.nativeName,
    required this.shortLabel,
    this.locale,
  });

  final String storageKey;
  final String flag;
  final String nativeName;
  final String shortLabel;
  final Locale? locale;

  static AppLanguage fromStorage(String? value) => values.firstWhere(
    (language) => language.storageKey == value,
    orElse: () => AppLanguage.system,
  );

  /// Keep every language already shipped by the product visible in the
  /// selector. `system` is an option rather than a concrete locale.
  static const releaseLanguages = <AppLanguage>[
    AppLanguage.system,
    AppLanguage.simplifiedChinese,
    AppLanguage.traditionalChinese,
    AppLanguage.english,
    AppLanguage.japanese,
    AppLanguage.korean,
    AppLanguage.vietnamese,
    AppLanguage.russian,
    AppLanguage.spanish,
    AppLanguage.french,
    AppLanguage.german,
    AppLanguage.portugueseBrazil,
    AppLanguage.turkish,
  ];

  static Locale resolveDeviceLocale(Locale? deviceLocale) {
    if (deviceLocale?.languageCode == 'zh') {
      const traditionalRegions = {'HK', 'MO', 'TW'};
      return traditionalRegions.contains(deviceLocale?.countryCode)
          ? const Locale('zh', 'HK')
          : const Locale('zh', 'CN');
    }
    return switch (deviceLocale?.languageCode) {
      'ja' => const Locale('ja', 'JP'),
      'ko' => const Locale('ko', 'KR'),
      'vi' => const Locale('vi', 'VN'),
      'ru' => const Locale('ru', 'RU'),
      'es' => const Locale('es', 'ES'),
      'fr' => const Locale('fr', 'FR'),
      'de' => const Locale('de', 'DE'),
      'pt' => const Locale('pt', 'BR'),
      'tr' => const Locale('tr', 'TR'),
      _ => const Locale('en', 'US'),
    };
  }

  static const supportedLocales = <Locale>[
    Locale('zh', 'CN'),
    Locale('zh', 'HK'),
    Locale('en', 'US'),
    Locale('ja', 'JP'),
    Locale('ko', 'KR'),
    Locale('vi', 'VN'),
    Locale('ru', 'RU'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('de', 'DE'),
    Locale('pt', 'BR'),
    Locale('tr', 'TR'),
  ];
}
