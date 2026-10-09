import 'dart:convert';

import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/profile/presentation/profile_page.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/shell/presentation/app_shell.dart';
import 'package:cardfi/features/tools/data/tools_repository.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:cardfi/features/tools/presentation/tools_page.dart';
import 'package:cardfi/features/tools/widgets/h5_tool_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'tool availability uses H5 meta switches and isolates endpoint failures',
    () async {
      final paths = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.contains('international-sims')) {
            return http.Response('', 503);
          }
          return _response({
            'enabled': !request.url.path.contains('no-kyc'),
            'count': 4,
          });
        }),
      );
      addTearDown(client.close);
      final result = await ToolsRepository(client).loadAvailability();
      expect(
        paths,
        unorderedEquals([
          '/api/no-kyc-cards/meta',
          '/api/international-sims/meta',
          '/api/sms-platforms/meta',
        ]),
      );
      expect(result[ToolKind.noKyc]!.enabled, isFalse);
      expect(result[ToolKind.internationalSim]!.failed, isTrue);
      expect(result[ToolKind.sms]!.enabled, isTrue);
    },
  );

  test('empty enabled meta directories remain hidden like H5', () async {
    final client = ApiClient(
      client: MockClient((_) async => _response({'enabled': true, 'count': 0})),
    );
    addTearDown(client.close);
    expect(
      (await ToolsRepository(client).loadAvailability()).values.every(
        (item) => !item.enabled && !item.failed,
      ),
      isTrue,
    );
  });

  test(
    'all directories use public H5 endpoints and reject unpublished rows',
    () async {
      final paths = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return _response({
            'enabled': true,
            'updatedAt': '2026-09-10',
            'items': [
              {'id': 'public', 'status': 'published'},
              {'id': 'hidden', 'status': 'draft'},
              {'id': 'old', 'status': 'archived'},
            ],
          });
        }),
      );
      addTearDown(client.close);
      final repository = ToolsRepository(client);
      for (final kind in ToolKind.values) {
        final collection = await repository.load(kind);
        expect(collection.items.map((item) => item.id), ['public']);
        expect(collection.updatedAt, '2026-09-10');
      }
      expect(paths, ToolKind.values.map((kind) => kind.path));
      expect(paths.any((path) => path.startsWith('/api/admin/')), isFalse);
    },
  );

  test(
    'BIN source reuses H5 fallback and lets configured empty ranges override it',
    () async {
      final client = ApiClient(
        client: MockClient(
          (_) async => _response({
            'items': [
              {'id': 'etherfi-core', 'name': 'Ether.fi'},
              {'id': 'bybit', 'name': 'Bybit', 'binRanges': []},
              {
                'id': 'runtime',
                'binRanges': [
                  {'bin': '123456', 'source': 'Official'},
                ],
              },
            ],
          }),
        ),
      );
      addTearDown(client.close);
      final items = (await ToolsRepository(client).load(ToolKind.bin)).items;
      expect(items[0].records('binRanges').first.value('bin'), '45492423');
      expect(items[1].id, 'bybit');
      expect(items[1].records('binRanges'), isEmpty);
      expect(items[2].records('binRanges').single.value('source'), 'Official');
    },
  );

  test('disabled no-KYC directory never leaks saved rows', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => _response({
          'enabled': false,
          'items': [
            {'id': 'old'},
          ],
        }),
      ),
    );
    addTearDown(client.close);
    expect((await ToolsRepository(client).load(ToolKind.noKyc)).items, isEmpty);
  });

  test(
    'details use encoded public identifiers and preserve H5 source metadata',
    () async {
      final requests = <Uri>[];
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add(request.url);
          return _response({
            'item': {
              'id': 'proof',
              'sourceUrl': 'https://source.example',
              'updatedAt': '2026-09-10',
            },
          });
        }),
      );
      addTearDown(client.close);
      final result = await ToolsRepository(client).detail(
        ToolKind.addressProof,
        ToolRecord({'id': 'proof', 'slug': 'a/b'}),
      );
      expect(requests.single.toString(), contains('/api/address-proofs/a%2Fb'));
      expect(result.value('sourceUrl'), 'https://source.example');
    },
  );

  test('BIN rejects full card numbers before any network request', () async {
    final requests = <String>[];
    final client = ApiClient(
      client: MockClient((request) async {
        requests.add(request.url.path);
        return _response({
          'item': {
            'bin': '454924',
            'source': {'provider': 'H5'},
          },
        });
      }),
    );
    addTearDown(client.close);
    final repository = ToolsRepository(client);
    for (final invalid in [
      '12345',
      '123456789',
      '4549240000000000',
      '123abc',
    ]) {
      await expectLater(repository.lookupBin(invalid), throwsFormatException);
    }
    expect(requests, isEmpty);
    expect((await repository.lookupBin('454924')).value('bin'), '454924');
    expect(requests, ['/api/bin-lookup/454924']);
  });

  test(
    'tool links exclude executable schemes and remove unapproved tracking',
    () {
      expect(publicToolUri('javascript:alert(1)'), isNull);
      expect(publicToolUri('file:///C:/secret'), isNull);
      expect(publicToolUri('https://user:password@example.com'), isNull);
      expect(
        publicToolUri(
          'https://example.com/?referrerCode=abc&utm_source=x&lang=en',
        )!.toString(),
        'https://example.com/?lang=en',
      );
      expect(
        publicToolUri(
          '/cover.png',
          base: Uri.parse('https://card.example/'),
        )!.toString(),
        'https://card.example/cover.png',
      );
      expect(
        cleanToolText('https://example.com/?ref=abc'),
        'https://example.com/',
      );
    },
  );

  test(
    'native guide rendering retains links and paragraphs without active content',
    () {
      final markdown = toolHtmlToMarkdown(
        '<script>evil()</script><p>First</p><p><strong>Second</strong> <a href="https://example.com/?ref=1&lang=en">Read</a></p>',
      );
      expect(markdown, contains('First\n\n**Second**'));
      expect(markdown, contains('[Read](https://example.com/?lang=en)'));
      expect(markdown, isNot(contains('evil')));
      expect(markdown, isNot(contains('ref=')));
    },
  );

  test(
    'unreviewed promotional summaries fall back to H5 requirement facts',
    () {
      final record = ToolRecord({
        'summaryZh': '通过邀请码注册并参加活动得 40U',
        'summaryEn': 'Register with an invite code for a 40U reward',
        'requirements': {'passport': 'required', 'idCard': 'unknown'},
      });
      expect(record.summary(ToolKind.requirements, chinese: true), '护照');
      expect(record.summary(ToolKind.requirements, chinese: false), 'Passport');
    },
  );

  test('public content chooses H5 English fields with a Chinese fallback', () {
    final item = ToolRecord({
      'summaryZh': '中文',
      'summaryEn': 'English',
      'nameZh': '仅中文',
    });
    expect(item.localized('summary', chinese: false), 'English');
    expect(item.localized('name', chinese: false), '仅中文');
    for (final language in AppLanguage.supportedLocales.where(
      (locale) => locale.languageCode != 'zh',
    )) {
      for (final source in [
        '实用工具',
        ...ToolKind.values.map((kind) => kind.title),
      ]) {
        expect(
          AppLocalizations(language).text(source),
          isNot(source),
          reason: '$language $source',
        );
      }
    }
  });

  testWidgets('personal center exposes useful tools to guests without login', (
    tester,
  ) async {
    ProfileSection? opened;
    var login = false;
    await _pump(
      tester,
      ProfilePage(
        onOpenSection: (section) => opened = section,
        onLogin: () => login = true,
        isDarkMode: false,
        onToggleTheme: () {},
      ),
    );
    await tester.ensureVisible(find.text('实用工具'));
    await tester.tap(find.text('实用工具'));
    expect(opened, ProfileSection.tools);
    expect(login, isFalse);
  });

  testWidgets(
    'tool hub follows H5 switches and remains usable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeRepository();
      await _pump(
        tester,
        ToolsPage(repository: repository, onBack: () {}),
        scale: 2,
      );
      expect(find.byKey(const Key('tool-noKyc')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('tool-sms')), 220);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('tool-sms')), findsOneWidget);
    },
  );

  testWidgets(
    'SIM cards preserve H5 eligibility values without inferring availability',
    (tester) async {
      for (final entry in {
        'available': '中国用户可申请',
        'conditional': '中国用户有条件申请',
        'unavailable': '中国用户暂不可申请',
        'unknown': '申请资格待核验',
      }.entries) {
        await _pump(
          tester,
          Center(
            child: SizedBox(
              width: 180,
              child: ToolDirectoryCard(
                kind: ToolKind.internationalSim,
                item: ToolRecord({
                  'id': entry.key,
                  'productName': 'Public SIM',
                  'chinaApplicationStatus': entry.key,
                }),
                base: Uri.parse('https://card.example/'),
                onTap: () {},
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'country search and filtering survive returning from tool detail',
    (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, ToolsPage(repository: repository, onBack: () {}));
      await tester.tap(find.byKey(const Key('tool-internationalSim')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tools-search')), 'Tello');
      await tester.tap(find.byKey(const Key('tools-filter-US')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-record-uk')), findsNothing);
      await tester.tap(find.byKey(const Key('tool-record-us')));
      await tester.pumpAndSettle();
      expect(find.text('申请与激活'), findsOneWidget);
      expect(find.text('需要'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('官方资料与用户经验'), 250);
      expect(find.text('官方资料与用户经验'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tools-back')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('tools-search')))
            .controller!
            .text,
        'Tello',
      );
      expect(repository.loads, 1);
      expect(find.byKey(const Key('tool-record-us')), findsOneWidget);
    },
  );

  testWidgets(
    'requirements filters distinguish unknown, required and conditional support',
    (tester) async {
      await _pump(
        tester,
        ToolsPage(repository: _FakeRepository(), onBack: () {}),
      );
      await tester.tap(find.byKey(const Key('tool-requirements')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tools-filter-passport')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-record-card-a')), findsOneWidget);
      expect(find.byKey(const Key('tool-record-card-b')), findsNothing);
      await tester.tap(find.byKey(const Key('tools-mode-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tools-filter-wechatPay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-record-card-a')), findsOneWidget);
      expect(find.byKey(const Key('tool-record-card-b')), findsNothing);
    },
  );

  testWidgets(
    'H5 BIN selector shows every range inline and changes the selected card',
    (tester) async {
      await _pump(
        tester,
        ToolsPage(repository: _FakeRepository(), onBack: () {}),
      );
      await tester.tap(find.byKey(const Key('tool-bin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bin-selected-card')), findsOneWidget);
      expect(find.text('BIN 401234'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('bin-card-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('BIN 40456789'),
        180,
        scrollable: scrollable,
      );
      expect(find.text('BIN 40456789'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('tools-search')),
        -180,
        scrollable: scrollable,
      );
      await tester.enterText(find.byKey(const Key('tools-search')), 'Infini');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bin-option-bybit')), findsNothing);
      await tester.tap(find.byKey(const Key('bin-option-infini')));
      await tester.pumpAndSettle();
      expect(find.text('BIN 441357'), findsOneWidget);
      expect(find.text('BIN 401234'), findsNothing);
      expect(find.byKey(const Key('tools-search')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('tools-search')),
        'Unrecorded',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bin-option-unrecorded')));
      await tester.pumpAndSettle();
      expect(find.text('这张卡还没有已发布的 BIN'), findsOneWidget);
    },
  );

  testWidgets(
    'BIN copy writes only the selected public prefix and back dismisses the selector',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(
        tester,
        ToolsPage(repository: _FakeRepository(), onBack: () {}),
      );
      await tester.tap(find.byKey(const Key('tool-bin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('copy-bin-bybit-0')));
      await tester.tap(find.byKey(const Key('copy-bin-bybit-0')));
      await tester.pump();
      expect(copied, '401234');
      expect(find.text('已复制'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('tools-search')),
        -180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('bin-card-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(find.byKey(const Key('tools-search')), 'Infini');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tools-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bin-option-infini')), findsNothing);
      expect(find.byKey(const Key('bin-card-list')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tools-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-bin')), findsOneWidget);
    },
  );

  testWidgets('BIN input limits card prefixes and shows the H5 lookup result', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, ToolsPage(repository: repository, onBack: () {}));
    await tester.tap(find.byKey(const Key('tool-bin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tools-mode-bin')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('bin-input')),
      '4549240000000000',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bin-input')))
          .controller!
          .text,
      '45492400',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '反查'));
    await tester.pumpAndSettle();
    expect(repository.queriedBin, '45492400');
    expect(find.text('查询结果'), findsOneWidget);
  });

  testWidgets(
    'loading failures expose retry and empty filters can be cleared',
    (tester) async {
      final repository = _FakeRepository()..failNext = true;
      await _pump(tester, ToolsPage(repository: repository, onBack: () {}));
      await tester.tap(find.byKey(const Key('tool-requirements')));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法加载资料'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tools-filter-idCard')));
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配的资料'), findsOneWidget);
      await tester.tap(find.text('清除筛选'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-record-card-a')), findsOneWidget);
    },
  );

  testWidgets('reopening comparison replaces edited and removed records', (
    tester,
  ) async {
    var records = <Map<String, dynamic>>[
      {
        'id': 'old',
        'cardId': 'old',
        'displayNameZh': '旧卡片',
        'status': 'published',
      },
    ];
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/meta')) {
          return _response({'enabled': false, 'count': 0});
        }
        expect(request.url.path, '/api/u-card-opening-requirements');
        expect(request.headers['cache-control'], 'no-cache');
        return _response({'items': records});
      }),
    );
    addTearDown(client.close);
    await _pump(
      tester,
      ToolsPage(repository: ToolsRepository(client), onBack: () {}),
    );
    await tester.tap(find.byKey(const Key('tool-requirements')));
    await tester.pumpAndSettle();
    expect(find.text('旧卡片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tools-back')));
    await tester.pumpAndSettle();
    records = [
      {
        'id': 'new',
        'cardId': 'new',
        'displayNameZh': '新增卡片',
        'status': 'published',
      },
      {
        'id': 'old',
        'cardId': 'old',
        'displayNameZh': '旧卡片',
        'status': 'archived',
      },
    ];
    await tester.tap(find.byKey(const Key('tool-requirements')));
    await tester.pumpAndSettle();
    expect(find.text('旧卡片'), findsNothing);
    expect(find.text('新增卡片'), findsOneWidget);
    records = [];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('新增卡片'), findsNothing);
  });

  testWidgets(
    'Android system back unwinds tool detail, list, hub and personal center',
    (tester) async {
      SharedPreferences.setMockInitialValues({'card-app-language-v1': 'zh-CN'});
      PackageInfo.setMockInitialValues(
        appName: 'CardFi',
        packageName: 'cn.lengziyu.cardapp',
        version: '0.1.0',
        buildNumber: '1',
        buildSignature: '',
      );
      await _pump(
        tester,
        AppShell(
          enableRemoteData: false,
          proUnlocked: false,
          toolsRepository: _FakeRepository(),
          authRepository: _GuestAuthRepository(),
          isDarkMode: false,
          onToggleTheme: () {},
          selectedLanguage: AppLanguage.simplifiedChinese,
          onLanguageChanged: (_) {},
        ),
      );
      await tester.tap(find.byKey(const Key('nav-我的')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('实用工具'));
      await tester.tap(find.text('实用工具'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tool-requirements')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tool-expand-card-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-expanded-card-a')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-expanded-card-a')), findsNothing);
      expect(find.byKey(const Key('tools-filter-passport')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-requirements')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tools-page')), findsNothing);
      expect(find.byKey(const Key('profile-page')), findsOneWidget);
    },
  );
}

http.Response _response(Map<String, dynamic> data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _GuestAuthRepository implements AuthRepository {
  @override
  bool get configured => false;
  @override
  Future<AuthUser?> initialize() async => null;
  @override
  Future<String?> idToken() async => null;
  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));
  @override
  Future<AuthUser?> reloadUser() async => null;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));
  @override
  Future<AuthUser> updateDisplayName(String displayName) =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));
}

class _FakeRepository extends ToolsRepository {
  _FakeRepository() : super(ApiClient());
  int loads = 0;
  bool failNext = false;
  String? queriedBin;
  @override
  Future<Map<ToolKind, ToolAvailability>> loadAvailability() async => {
    ToolKind.noKyc: const ToolAvailability(enabled: false),
    ToolKind.internationalSim: const ToolAvailability(enabled: true, count: 2),
    ToolKind.sms: const ToolAvailability(enabled: true, count: 1),
  };
  @override
  Future<ToolCollection> load(ToolKind kind) async {
    loads++;
    if (failNext) {
      failNext = false;
      throw const FormatException('Unavailable');
    }
    return ToolCollection(
      items: switch (kind) {
        ToolKind.bin => [
          ToolRecord({
            'id': 'bybit',
            'name': 'Bybit Card',
            'issuer': 'Bybit',
            'binRanges': [
              {
                'id': 'bybit-one',
                'bin': '401234',
                'network': 'Visa',
                'region': '中国香港',
                'issuer': 'Issuer One',
              },
              {
                'id': 'bybit-two',
                'bin': '40456789',
                'network': 'Mastercard',
                'region': '欧洲',
                'issuer': 'Issuer Two',
              },
            ],
          }),
          ToolRecord({
            'id': 'infini',
            'name': 'Infini Card',
            'issuer': 'Infini',
            'binRanges': [
              {
                'id': 'infini-one',
                'bin': '441357',
                'network': 'Visa',
                'region': '美国',
                'issuer': 'Public Bank',
              },
            ],
          }),
          ToolRecord({
            'id': 'unrecorded',
            'name': 'Unrecorded Card',
            'issuer': 'Other',
            'binRanges': [],
          }),
        ],
        ToolKind.internationalSim => [
          ToolRecord({
            'id': 'us',
            'productName': 'Tello',
            'countryCode': 'US',
            'countryNameZh': '美国',
            'countryNameEn': 'United States',
            'supportsSms': 'yes',
            'requiresLocalPresence': 'yes',
            'guides': [
              {'titleZh': '申请指南', 'evidence': 'mixed', 'steps': []},
            ],
          }),
          ToolRecord({
            'id': 'uk',
            'productName': 'Giffgaff',
            'countryCode': 'GB',
            'countryNameZh': '英国',
          }),
        ],
        ToolKind.requirements => [
          ToolRecord({
            'id': 'card-a',
            'displayNameZh': 'Card A',
            'requirements': {'passport': 'required'},
            'card': {
              'paymentSupport': {
                'wechatPay': {'status': 'conditional'},
              },
            },
          }),
          ToolRecord({
            'id': 'card-b',
            'displayNameZh': 'Card B',
            'requirements': {'passport': 'unknown'},
          }),
        ],
        _ => [],
      },
    );
  }

  @override
  Future<ToolRecord> detail(ToolKind kind, ToolRecord item) async => item;
  @override
  Future<ToolRecord> lookupBin(String bin) async {
    queriedBin = bin;
    return ToolRecord({
      'bin': bin,
      'network': 'VISA',
      'issuer': {'nameZh': '公开发卡机构'},
    });
  }
}
