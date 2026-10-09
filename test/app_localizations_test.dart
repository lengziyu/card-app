import 'dart:io';

import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/data/local_card_details.dart';
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

  test(
    'rights and removal notice is translated for every selectable locale',
    () {
      const source = '如相关展示存在错误、侵权或造成冒犯，请通过“反馈与纠错”联系；核实后将及时更正或下架。';
      for (final language in AppLanguage.releaseLanguages.where(
        (language) => language.locale != null,
      )) {
        final translation = AppLocalizations(language.locale!).text(source);
        expect(translation, isNotEmpty, reason: language.storageKey);
        if (language != AppLanguage.simplifiedChinese) {
          expect(translation, isNot(source), reason: language.storageKey);
        }
      }
    },
  );

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

  test('other-card region labels are localized for every product locale', () {
    for (final locale in AppLanguage.supportedLocales) {
      final localizations = AppLocalizations(locale);
      for (final source in ['港卡', '美卡', '内地卡', '更多']) {
        final translation = localizations.text(source);
        expect(translation, isNotEmpty, reason: '$locale: $source');
        if (locale.languageCode != 'zh') {
          expect(translation, isNot(source), reason: '$locale: $source');
        }
      }
    }
  });

  test('English localizes App Store subscription display names', () {
    const localizations = AppLocalizations(Locale('en', 'US'));

    expect(localizations.text('CardFi Pro 月度'), 'CardFi Pro Monthly');
    expect(localizations.text('CardFi Pro 年度'), 'CardFi Pro Yearly');
    expect(
      localizations.text(r'US$14.99 · 开通 CardFi Pro 年度'),
      r'US$14.99 · Subscribe to CardFi Pro Yearly',
    );
  });

  test(
    'ranking, stablecoin, profile and Pro copy has an English translation',
    () {
      const sources = [
        '近 7 天入金量',
        '近 30 天入金量',
        '累计入金量',
        '链上交易笔数',
        '活跃地址数',
        '市值占比',
        '稳定币市值占比',
        '卡友贡献与活跃榜',
        '本月活跃度',
        '活跃天数 24 天 · 已采纳 6 条',
        '已采纳 6 条贡献',
        '按贡献与活跃度综合排序；会员身份不参与计分。',
        '贡献 40% · 有效活跃天数 25% · 社区反馈 20% · 持续参与 15%',
        '订阅会按所选周期自动续费；可随时前往系统订阅管理页取消。实际价格、扣款时间与续费规则以商店确认页为准。',
        '这会永久删除账号及已同步的卡包、收藏、历史、反馈和 Pro 工作区数据，无法恢复。已有应用商店订阅不会自动取消。',
      ];
      final chinese = RegExp(r'[\u3400-\u9FFF]');

      const localizations = AppLocalizations(Locale('en', 'US'));
      for (final source in sources) {
        expect(
          localizations.text(source),
          isNot(contains(chinese)),
          reason: source,
        );
      }
    },
  );

  test('language selector retains every translated product locale', () {
    expect(AppLanguage.releaseLanguages, AppLanguage.values);
    expect(AppLanguage.releaseLanguages, hasLength(13));
    expect(AppLanguage.supportedLocales, const <Locale>[
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
    ]);
    expect(
      AppLanguage.resolveDeviceLocale(const Locale('ko', 'KR')),
      const Locale('ko', 'KR'),
    );
  });

  test(
    'every released locale uses a translation or the complete Chinese source',
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
          final partialMixedChinese =
              language != AppLanguage.japanese &&
              chinese.hasMatch(translated) &&
              translated != source.copy;
          final genericFallback =
              translated == 'Details are not available in English yet.';
          if (translated.isEmpty || partialMixedChinese || genericFallback) {
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

  test('missing translations preserve the original Chinese copy', () {
    const source = '这是一条尚未收录翻译的测试文案';

    expect(AppLocalizations(const Locale('en', 'US')).text(source), source);
    expect(AppLocalizations(const Locale('fr', 'FR')).text(source), source);
    expect(
      AppLocalizations(const Locale('en', 'US')).text(source),
      isNot('Details are not available in English yet.'),
    );
  });

  test('English catalog data uses translations or complete Chinese copy', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    expect(
      localizations.text('个人多币种账户 · 地区受限'),
      'Personal multi-currency account · region restricted',
    );
    expect(
      localizations.text('企业账户 · 全球收款'),
      'Business account · global receiving',
    );
    expect(localizations.text('账户月费'), 'Monthly account fee');
    final details = LocalCardDetailRepository();
    final copy = <String>[
      for (final card in localCardCatalog) ...[
        card.category.label,
        card.label,
        card.directoryTypeLabel,
        card.kycSummary,
        ...card.kycDocuments.map((document) => document.label),
        ...details.detailFor(card).tags,
        details.detailFor(card).region,
        details.detailFor(card).funding,
        details.detailFor(card).availability,
        ...details.detailFor(card).features.map((feature) => feature.text),
        ...details
            .detailFor(card)
            .rules
            .expand((rule) => [rule.label, rule.value]),
        ...details
            .detailFor(card)
            .fees
            .expand(
              (fee) => [fee.label, fee.value, if (fee.note != null) fee.note!],
            ),
        details.detailFor(card).kycNote,
        details.detailFor(card).sourceLabel,
        details.detailFor(card).note,
        if (details.detailFor(card).chinaKyc case final chinaKyc?) ...[
          chinaKyc.status.label,
          chinaKyc.documentSummary,
          chinaKyc.note,
        ],
      ],
    ].where((value) => value.isNotEmpty);
    final chinese = RegExp(r'[\u3400-\u9FFF]');
    final invalid = copy
        .map(
          (source) => (source: source, translated: localizations.text(source)),
        )
        .where(
          (entry) =>
              entry.translated == 'Details are not available in English yet.' ||
              chinese.hasMatch(entry.translated) &&
                  entry.translated != entry.source,
        )
        .toList();

    expect(
      invalid,
      isEmpty,
      reason: invalid
          .map((entry) => '${entry.source} -> ${entry.translated}')
          .join('\n'),
    );
  });

  test('English fully translates both AI assistant flows', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    final files = [
      File('lib/features/market/presentation/card_advisor_page.dart'),
      File(
        'lib/features/market/presentation/card_application_assistant_page.dart',
      ),
      File('lib/features/market/presentation/ai_assistant_hub_sheet.dart'),
      File('lib/features/market/widgets/ai_assistant_flow_controls.dart'),
    ];
    final literal = RegExp(r"'((?:\\'|[^'])*[\u3400-\u9FFF](?:\\'|[^'])*)'");
    final chinese = RegExp(r'[\u3400-\u9FFF]');
    final failures = <String>[];

    for (final file in files) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final source = match.group(1)!.replaceAll(r"\'", "'");
        final translated = localizations.text(source);
        if (chinese.hasMatch(translated) ||
            translated == 'Details are not available in English yet.') {
          failures.add('${file.path}: $source -> $translated');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('English fully translates the Pro purchase and entitlement flow', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    final files = [
      File('lib/features/pro/presentation/pro_page.dart'),
      File('lib/features/pro/domain/pro_models.dart'),
      File('lib/features/pro/data/pro_controller.dart'),
    ];
    final literal = RegExp(r"'((?:\\'|[^'])*[\u3400-\u9FFF](?:\\'|[^'])*)'");
    final chinese = RegExp(r'[\u3400-\u9FFF]');
    final failures = <String>[];

    for (final file in files) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final source = match.group(1)!.replaceAll(r"\'", "'");
        final translated = localizations.text(source);
        if (chinese.hasMatch(translated) ||
            translated == 'Details are not available in English yet.') {
          failures.add('${file.path}: $source -> $translated');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('English fully translates authentication runtime messages', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    expect(localizations.text('60 秒后可重新发送'), 'Resend in 60 seconds');
    expect(localizations.text('Google 账号已绑定。'), 'Google account linked.');
    final files = [
      File('lib/features/auth/data/auth_controller.dart'),
      File('lib/features/auth/data/supabase_auth_repository.dart'),
      File('lib/features/auth/presentation/auth_page.dart'),
    ];
    final literal = RegExp(r"'((?:\\'|[^'])*[\u3400-\u9FFF](?:\\'|[^'])*)'");
    final chinese = RegExp(r'[\u3400-\u9FFF]');
    final failures = <String>[];

    for (final file in files) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final source = match.group(1)!.replaceAll(r"\'", "'");
        final translated = localizations.text(source);
        if (chinese.hasMatch(translated) ||
            translated == 'Details are not available in English yet.') {
          failures.add('${file.path}: $source -> $translated');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('profile copy never uses the generic missing-translation message', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    final files = [
      File('lib/features/profile/presentation/profile_page.dart'),
      File('lib/features/profile/presentation/profile_subpage.dart'),
    ];
    final literal = RegExp(r"'((?:\\'|[^'])*[\u3400-\u9FFF](?:\\'|[^'])*)'");
    final failures = <String>[];

    for (final file in files) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final source = match.group(1)!.replaceAll(r"\'", "'");
        final translated = localizations.text(source);
        if (translated == 'Details are not available in English yet.') {
          failures.add('${file.path}: $source');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('English settings page has complete primary copy', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    const sources = [
      '设置',
      '震动反馈',
      '操作时提供轻微触觉反馈',
      '卡片滑动震动',
      '切换当前卡片时提供触觉反馈',
      '卡片滑动强度',
      '弱',
      '中',
      '高',
      '使用说明',
      'AI精选好卡、AI 协助开卡与 Pro 功能操作说明',
      '帮助中心',
      '常见问题、地区适用性与数据安全',
      '关于我们',
      '产品定位、隐私原则与联系信息',
      '隐私政策',
      '了解数据处理、保留、安全与账号权利',
      '用户协议',
      '服务定位、使用规则和重要风险说明',
      '账号删除说明',
      '删除方式、数据范围和无法登录时的处理路径',
      '联系支持',
      '联系开发者、反馈问题或提出数据请求',
      '版本管理',
      '当前版本、构建号与更新方式',
    ];
    final chinese = RegExp(r'[\u3400-\u9FFF]');

    for (final source in sources) {
      final translated = localizations.text(source);
      expect(translated, isNot(contains(chinese)), reason: source);
      expect(
        translated,
        isNot('Details are not available in English yet.'),
        reason: source,
      );
    }
  });

  test('English Pro quota copy matches the current monthly allowances', () {
    const localizations = AppLocalizations(Locale('en', 'US'));
    expect(
      localizations.text('Pro AI 使用额度 · 每月共 70 次'),
      'Pro AI allowance · 70 total uses per month',
    );
    expect(
      localizations.text('AI精选好卡、AI 协助开卡各每月 20 次；每分钟最多 3 次。'),
      contains('20 uses per month'),
    );
    expect(
      localizations.text('账单识别每月 30 次，和以上额度独立计算；每月月初重置。'),
      contains('30 uses per month'),
    );
  });
}
