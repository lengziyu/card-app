import 'dart:io';

import 'package:card_app/core/localization/app_language.dart';
import 'package:card_app/core/localization/app_localizations.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every selectable locale has a market translation', () {
    for (final language in AppLanguage.releaseLanguages.where(
      (language) => language.locale != null,
    )) {
      final translation = AppLocalizations(language.locale!).text('市场');
      expect(translation, isNotEmpty, reason: language.storageKey);
      if (language != AppLanguage.simplifiedChinese) {
        expect(translation, isNot('市场'), reason: language.storageKey);
      }
    }
  });

  testWidgets('localized Text responds to the active locale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en', 'US'),
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Text('市场')),
      ),
    );

    expect(find.text('Market'), findsOneWidget);
  });

  test('traditional Chinese converts uncatalogued product copy', () {
    const localizations = AppLocalizations(Locale('zh', 'HK'));
    expect(localizations.text('保存账号资料'), '儲存帳號資料');
  });

  test('first release exposes only reviewed Chinese and English locales', () {
    expect(
      AppLanguage.releaseLanguages,
      containsAll(<AppLanguage>[
        AppLanguage.system,
        AppLanguage.simplifiedChinese,
        AppLanguage.traditionalChinese,
        AppLanguage.english,
      ]),
    );
    expect(AppLanguage.releaseLanguages, hasLength(4));
    expect(AppLanguage.supportedLocales, const <Locale>[
      Locale('zh', 'CN'),
      Locale('zh', 'HK'),
      Locale('en', 'US'),
    ]);
    expect(
      AppLanguage.resolveDeviceLocale(const Locale('ko', 'KR')),
      const Locale('en', 'US'),
    );
  });

  test(
    'every released non-Chinese locale has no untranslated Chinese in direct visible Text copy',
    () {
      final files = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final singleQuoted = RegExp(
        r"\bText\s*\(\s*'((?:\\'|[^'])*)'",
        dotAll: true,
      );
      final doubleQuoted = RegExp(
        r'\bText\s*\(\s*"((?:\\"|[^"])*)"',
        dotAll: true,
      );
      final chinese = RegExp(r'[\u3400-\u9FFF]');
      final sourceCopies = <({String path, String copy})>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final expression in [singleQuoted, doubleQuoted]) {
          for (final match in expression.allMatches(source)) {
            final copy = match
                .group(1)!
                .replaceAll(r"\'", "'")
                .replaceAll(r'\"', '"');
            if (chinese.hasMatch(copy)) {
              sourceCopies.add((path: file.path, copy: copy));
            }
          }
        }
      }

      final failures = <String>[];
      for (final language in AppLanguage.releaseLanguages.where(
        (language) =>
            language.locale != null && language.locale!.languageCode != 'zh',
      )) {
        final localizations = AppLocalizations(language.locale!);
        for (final source in sourceCopies) {
          final translated = localizations.text(source.copy);
          if (chinese.hasMatch(translated)) {
            failures.add(
              '${language.storageKey}: ${source.path}: '
              '${source.copy} -> $translated',
            );
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );
}
