import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/theme/app_theme.dart';
import 'package:cardfi/core/widgets/scroll_to_top_button.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/market/presentation/market_page.dart';
import 'package:cardfi/features/market/widgets/market_card_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppColors.configure(Brightness.light));

  testWidgets('other cards match all five H5 regional filters', (tester) async {
    final cards = [
      for (final region in CardMarketRegion.values)
        _regionalCard(region.name, region: region),
      _regionalCard('unclassified'),
      _regionalCard('ucard', category: CardCategory.uCard),
      _regionalCard('account', kind: CatalogItemKind.globalAccount),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(cards),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();

    for (final label in ['全部', '港卡', '美卡', '内地卡', '更多']) {
      expect(find.text(label), findsOneWidget);
    }
    List<String> visibleCards() => tester
        .widgetList<CatalogCardRow>(find.byType(CatalogCardRow))
        .map((row) => row.card.id)
        .toList();
    expect(visibleCards(), ['hk', 'us', 'cn', 'more', 'unclassified']);

    for (final entry in {
      'hk': ['hk'],
      'us': ['us'],
      'cn': ['cn'],
      'more': ['more', 'unclassified'],
      'all': ['hk', 'us', 'cn', 'more', 'unclassified'],
    }.entries) {
      await tester.tap(find.byKey(Key('market-other-filter-${entry.key}')));
      await tester.pumpAndSettle();
      expect(visibleCards(), entry.value, reason: entry.key);
    }

    await tester.tap(find.byKey(const Key('market-other-filter-us')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-group-ucard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-other-filters')), findsNothing);
    expect(visibleCards(), ['ucard']);
    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();
    expect(visibleCards(), ['us']);
  });

  testWidgets('empty regional filters remain selectable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([
            _regionalCard('hk', region: CardMarketRegion.hk),
          ]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-other-filter-us')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-empty')), findsOneWidget);
    expect(find.byType(CatalogCardRow), findsNothing);
    await tester.tap(find.byKey(const Key('market-other-filter-hk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-card-hk')), findsOneWidget);
  });

  testWidgets('other-card regions stay pinned while the list scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([
            for (var index = 0; index < 20; index++)
              _regionalCard('hk-$index', region: CardMarketRegion.hk),
          ]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    final mainTab = tester.getRect(find.byKey(const Key('market-group-other')));
    final filterTab = tester.getRect(
      find.byKey(const Key('market-other-filter-us')),
    );
    expect(mainTab.top, greaterThanOrEqualTo(0));
    expect(filterTab.top, greaterThan(mainTab.bottom));
    expect(filterTab.bottom, lessThanOrEqualTo(111));
    await tester.tap(find.byKey(const Key('market-other-filter-us')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-empty')), findsOneWidget);
  });

  testWidgets('regional tabs scroll on narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [AppLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: MarketPage(
          repository: _CardsRepository([
            _regionalCard('us', region: CardMarketRegion.us),
          ]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();
    expect(find.text('Hong Kong'), findsOneWidget);
    expect(find.text('US'), findsOneWidget);
    expect(find.text('Mainland'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('market-other-filters')),
    );
    final content = scroll.child! as SizedBox;
    expect(content.width, greaterThan(272));
    await tester.drag(
      find.byKey(const Key('market-other-filters')),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();
    final moreTab = find.byKey(const Key('market-other-filter-more'));
    expect(tester.getSize(moreTab).height, greaterThanOrEqualTo(44));
    await tester.tap(moreTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('market row presses subtly and reports its artwork rect', (
    tester,
  ) async {
    CardSummary? openedCard;
    Rect? sourceRect;
    Rect? sourceTitleRect;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (card, geometry) {
            openedCard = card;
            sourceRect = geometry.artworkRect;
            sourceTitleRect = geometry.titleRect;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(Key('catalog-card-${localCardCatalog.first.id}'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('pressable-scale-transform')),
          )
          .scale,
      .985,
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(openedCard?.id, localCardCatalog.first.id);
    expect(sourceRect?.size, const Size(112, 70));
    expect(sourceRect, isNotNull);
    expect(sourceTitleRect, isNotNull);
  });

  testWidgets('market row puts cashback before application facts', (
    tester,
  ) async {
    const card = CardSummary(
      id: 'decision-card',
      name: 'Decision Card',
      issuer: 'Decision',
      category: CardCategory.uCard,
      label: 'VISA',
      tint: 0xFF112233,
      kycSummary: '身份证 / 护照',
      cashbackRate: '最高 2%',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: const _CardsRepository([card]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最高返现 2% · 证件：身份证 / 护照'), findsOneWidget);
    expect(find.text('Decision · U 卡'), findsNothing);
  });

  testWidgets('market decision subtitle is localized in English', (
    tester,
  ) async {
    const card = CardSummary(
      id: 'localized-card',
      name: 'Localized Card',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: 'VISA',
      tint: 0xFF112233,
      kycSummary: '身份证 / 护照',
      cashbackRate: '最高 2%',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [AppLocalizations.delegate],
        home: MarketPage(
          repository: const _CardsRepository([card]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Cashback up to 2% · Documents: National ID / Passport'),
      findsOneWidget,
    );
  });

  testWidgets('market row keeps restrictions and falls back to freshness', (
    tester,
  ) async {
    final cards = [
      CardSummary(
        id: 'restricted-card',
        name: 'Restricted Card',
        issuer: 'Issuer',
        category: CardCategory.uCard,
        label: 'VISA',
        tint: 0xFF112233,
        kycSummary: '大陆不可用',
        cashbackRate: '3%',
      ),
      CardSummary(
        id: 'unknown-card',
        name: 'Unknown Card',
        issuer: 'Issuer',
        category: CardCategory.uCard,
        label: 'VISA',
        tint: 0xFF112233,
        updatedAt: DateTime(2026, 7, 21),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(cards),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('返现 3% · 大陆不可用'), findsOneWidget);
    expect(find.text('申请条件待确认 · 7月21日更新'), findsOneWidget);
  });

  testWidgets('vertical scrolling cancels the market card tap', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog.take(8).toList()),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (_, _) => openCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(openCount, 0);
  });

  testWidgets('global accounts have an article-style market group', (
    tester,
  ) async {
    CatalogCardSourceGeometry? geometry;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (_, value) => geometry = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final uCardTab = find.byKey(const Key('market-group-ucard'));
    final uCardTabTop = tester.getTopLeft(uCardTab).dy;

    final globalTab = find.byKey(const Key('market-group-global-account'));
    await tester.tap(globalTab);
    await tester.pumpAndSettle();

    final account = find.byKey(const Key('global-account-card-wise-account'));
    expect(account, findsOneWidget);
    // The main tabs stay put. Global accounts add their own three-filter
    // panel directly below the tabs before the directory begins.
    final filter = find.byKey(const Key('global-account-filter-panel'));
    expect(tester.getTopLeft(globalTab).dy, closeTo(uCardTabTop, 1));
    expect(
      tester.getTopLeft(filter).dy - tester.getBottomLeft(globalTab).dy,
      greaterThanOrEqualTo(12),
    );
    expect(
      tester.getTopLeft(account).dy - tester.getBottomLeft(filter).dy,
      greaterThanOrEqualTo(12),
    );
    expect(
      find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      findsNothing,
    );
    final cover = find.descendant(
      of: account,
      matching: find.byType(AspectRatio),
    );
    expect(cover, findsOneWidget);
    final coverSize = tester.getSize(cover);
    expect(coverSize.width / coverSize.height, closeTo(16 / 9, .01));
    expect(
      find.descendant(
        of: account,
        matching: find.byKey(const Key('global-account-logo-wise-account')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: account,
        matching: find.byKey(
          const Key('global-account-bank-mark-wise-account'),
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(account);
    await tester.pump(const Duration(milliseconds: 120));
    expect(geometry, isNotNull);
    expect(
      geometry!.artworkRect.width / geometry!.artworkRect.height,
      closeTo(16 / 9, .01),
    );

    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -560),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(globalTab).dy, lessThanOrEqualTo(12));
  });

  testWidgets(
    'global accounts preserve the provider-curated order and mark crypto',
    (tester) async {
      const traditionalZ = CardSummary(
        id: 'traditional-z',
        name: 'Zulu Account',
        issuer: 'Zulu',
        category: CardCategory.bankAccount,
        label: '多币种账户',
        tint: 0xFF112233,
        kind: CatalogItemKind.globalAccount,
        accountType: 'multiCurrency',
      );
      const crypto = CardSummary(
        id: 'crypto-account',
        name: 'Crypto Account',
        issuer: 'Crypto',
        category: CardCategory.bankAccount,
        label: '数字资产账户',
        tint: 0xFF112233,
        kind: CatalogItemKind.globalAccount,
        accountType: 'cryptoPlatform',
      );
      const traditionalA = CardSummary(
        id: 'traditional-a',
        name: 'Alpha Account',
        issuer: 'Alpha',
        category: CardCategory.bankAccount,
        label: '多币种账户',
        tint: 0xFF112233,
        kind: CatalogItemKind.globalAccount,
        accountType: 'multiCurrency',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MarketPage(
            repository: const _CardsRepository([
              traditionalZ,
              crypto,
              traditionalA,
            ]),
            onSearch: () {},
            onOpenCard: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('market-group-global-account')));
      await tester.pumpAndSettle();

      final zulu = find.byKey(const Key('global-account-card-traditional-z'));
      final alpha = find.byKey(const Key('global-account-card-traditional-a'));
      final cryptoCard = find.byKey(
        const Key('global-account-card-crypto-account'),
      );
      expect(
        tester.getTopLeft(zulu).dy,
        lessThan(tester.getTopLeft(cryptoCard).dy),
      );
      expect(
        tester.getTopLeft(cryptoCard).dy,
        lessThan(tester.getTopLeft(alpha).dy),
      );
      expect(
        find.byKey(const Key('global-account-crypto-crypto-account')),
        findsOneWidget,
      );
      expect(find.text('加密相关'), findsOneWidget);
      expect(find.text('加密相关 · 非银行账户'), findsNothing);
    },
  );

  testWidgets('global account dropdown filters the published directory', (
    tester,
  ) async {
    const traditional = CardSummary(
      id: 'traditional-account',
      name: 'Traditional Account',
      issuer: 'Traditional',
      category: CardCategory.bankAccount,
      label: '多币种账户',
      tint: 0xFF112233,
      kind: CatalogItemKind.globalAccount,
      accountType: 'multiCurrency',
      transferCurrencies: ['USD'],
      receivingMethods: ['wire'],
      chinaKycStatus: 'available',
    );
    const crypto = CardSummary(
      id: 'crypto-account',
      name: 'Crypto Account',
      issuer: 'Crypto',
      category: CardCategory.bankAccount,
      label: '数字资产账户',
      tint: 0xFF112233,
      kind: CatalogItemKind.globalAccount,
      accountType: 'cryptoPlatform',
      receivingMethods: ['crypto'],
      chinaKycStatus: 'unavailable',
    );
    const usdCrypto = CardSummary(
      id: 'usd-crypto-account',
      name: 'USD Crypto Account',
      issuer: 'USD Crypto',
      category: CardCategory.bankAccount,
      label: '数字资产账户',
      tint: 0xFF112233,
      kind: CatalogItemKind.globalAccount,
      accountType: 'cryptoIntegratedAccount',
      transferCurrencies: ['USD'],
      receivingMethods: ['crypto'],
      chinaKycStatus: 'unknown',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: const _CardsRepository([traditional, crypto, usdCrypto]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-group-global-account')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('global-account-filter-panel')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('global-account-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加密相关 (2)').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('global-account-card-traditional-account')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('global-account-card-crypto-account')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('global-account-card-usd-crypto-account')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('global-account-kyc-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大陆不可用 (1)').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('global-account-card-usd-crypto-account')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('global-account-card-crypto-account')),
      findsOneWidget,
    );
  });

  testWidgets('U-card scrolling pins only its secondary filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final primaryTab = find.byKey(const Key('market-group-ucard'));
    final filterTab = find.byKey(const Key('market-filter-all'));
    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -560),
    );
    await tester.pumpAndSettle();

    expect(filterTab, findsOneWidget);
    expect(tester.getTopLeft(filterTab).dy, lessThanOrEqualTo(24));
    // The primary category segment scrolls with the U-card content instead
    // of occupying a second fixed row above the filters.
    expect(tester.getTopLeft(primaryTab).dy, lessThan(0));
  });

  testWidgets('market header keeps all actions visible on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
          onCompare: () {},
          onOpenCanvas: () {},
          onOpenAiAdvisor: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-compare-button')), findsOneWidget);
    expect(find.byKey(const Key('market-ai-advisor-button')), findsOneWidget);
    expect(find.byKey(const Key('market-canvas-button')), findsOneWidget);
    expect(find.byKey(const Key('market-search-button')), findsOneWidget);
    final actionTop = tester
        .getTopLeft(find.byKey(const Key('market-compare-button')))
        .dy;
    for (final key in const [
      Key('market-ai-advisor-button'),
      Key('market-canvas-button'),
      Key('market-search-button'),
    ]) {
      expect(tester.getTopLeft(find.byKey(key)).dy, actionTop);
    }
    for (final key in const [
      Key('market-compare-button'),
      Key('market-ai-advisor-button'),
      Key('market-canvas-button'),
      Key('market-search-button'),
    ]) {
      final ink = tester.widget<Ink>(
        find.descendant(of: find.byKey(key), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration as BoxDecoration;
      // Header actions stay lightweight: a border supplies separation without
      // four simultaneous large blur shadows on narrow devices.
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'market reveals the floating return-to-top control after one screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MarketPage(
            repository: _CardsRepository([
              ...localCardCatalog,
              ...localCardCatalog,
              ...localCardCatalog,
              ...localCardCatalog,
            ]),
            onSearch: () {},
            onOpenCard: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final control = find.byType(ScrollToTopButton);
      final opacity = find.descendant(
        of: control,
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);

      await tester.drag(
        find.byKey(const Key('market-page')),
        const Offset(0, -1100),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);

      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
    },
  );

  testWidgets('global account directory card supports the dark theme', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-group-global-account')));
    await tester.pumpAndSettle();

    final account = find.byKey(const Key('global-account-card-wise-account'));
    expect(account, findsOneWidget);
    expect(
      find.descendant(of: account, matching: find.text('查看支持币种、收款能力与开户条件')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the market row at full scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('pressable-scale-transform')),
          )
          .scale,
      1,
    );
    await gesture.cancel();
  });

  testWidgets('market AI action is available and opens the supplied flow', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenAiAdvisor: () => openCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-ai-advisor-button')));
    expect(openCount, 1);
  });

  testWidgets('shared card flight reaches the detail artwork bounds', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 360),
    );
    addTearDown(controller.dispose);
    const source = Rect.fromLTWH(24, 210, 112, 70);
    const target = Rect.fromLTWH(24, 150, 342, 216);
    const sourceTitle = Rect.fromLTWH(153, 230, 90, 18);
    const targetTitle = Rect.fromLTWH(24, 391, 342, 32);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MarketCardTransition(
                card: localCardCatalog.first,
                animation: controller,
                sourceRect: source,
                targetRect: target,
                sourceTitleRect: sourceTitle,
                targetTitleRect: targetTitle,
              ),
            ],
          ),
        ),
      ),
    );
    controller.value = .84;
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('market-card-flight-opacity')))
          .opacity,
      1,
      reason:
          'the source artwork must remain visible until the detail artwork starts its handoff',
    );

    controller.value = 1;
    await tester.pump();

    final positioned = tester.widget<Positioned>(
      find.byKey(const Key('market-card-flight-position')),
    );
    expect(positioned.left, target.left);
    expect(positioned.top, target.top);
    expect(positioned.width, target.width);
    expect(positioned.height, target.height);
    final titlePositioned = tester.widget<Positioned>(
      find.byKey(const Key('market-card-flight-title-position')),
    );
    expect(titlePositioned.left, targetTitle.left);
    expect(titlePositioned.top, targetTitle.top);

    // A system back action can interrupt entry before the card has arrived.
    controller.value = .52;
    await tester.pump();
    final beforeReverse = tester.getRect(
      find.byKey(const Key('market-card-flight-opacity')),
    );
    controller.reverse();
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('market-card-flight-opacity'))),
      beforeReverse,
      reason:
          'reversing mid-flight must not switch to a different spatial curve',
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('market-card-flight-opacity'))),
      source,
    );
  });
}

CardSummary _regionalCard(
  String id, {
  CardMarketRegion region = CardMarketRegion.more,
  CardCategory category = CardCategory.debitCard,
  CatalogItemKind kind = CatalogItemKind.card,
}) => CardSummary(
  id: id,
  name: id,
  issuer: 'Issuer',
  category: category,
  label: 'VISA',
  tint: 0xFF112233,
  marketRegion: region,
  kind: kind,
);

class _CardsRepository implements CardCatalogRepository {
  const _CardsRepository(this.cards);

  final List<CardSummary> cards;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async => cards;
}
