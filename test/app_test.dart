import 'package:card_app/app/card_app.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the card collection home', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(find.byKey(const Key('home-card-etherfi-core')), findsOneWidget);
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
  });

  testWidgets('opens the add card page from the title action', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
    expect(find.text('添加卡片'), findsOneWidget);
    expect(find.byKey(const Key('toggle-etherfi-core')), findsOneWidget);
  });

  testWidgets('opens a home card detail like H5', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-card-etherfi-core')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
  });

  testWidgets('home card previews crop from the top like H5', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final firstCard = find.byKey(const Key('home-card-etherfi-core'));
    final artwork = find.descendant(
      of: firstCard,
      matching: find.byType(Image),
    );

    expect(artwork, findsOneWidget);
    expect(tester.widget<Image>(artwork).alignment, Alignment.topCenter);
  });

  testWidgets('long press and drag reorders home cards like H5', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final firstCard = find.byKey(const Key('home-card-etherfi-core'));
    final secondCard = find.byKey(const Key('home-card-bybit-card'));
    final start = tester.getTopLeft(firstCard) + const Offset(100, 40);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 160));
    await gesture.moveBy(const Offset(0, 190));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(secondCard).dy,
      lessThan(tester.getTopLeft(firstCard).dy),
    );
  });

  test('home card pinch scale uses the same H5 limits', () {
    expect(clampHomeCardHeightScale(0), homeCardHeightScaleMin);
    expect(clampHomeCardHeightScale(10), homeCardHeightScaleMax);
    expect(homeCardHeightPercent(1), 62);
  });

  testWidgets('two-finger hold then pinch changes the home card height', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final stack = find.byKey(const Key('card-stack'));
    final initialHeight = tester.getSize(stack).height;
    final center = tester.getTopLeft(stack) + const Offset(200, 110);
    tester.binding.handlePointerEvent(
      PointerDownEvent(pointer: 11, position: center - const Offset(32, 0)),
    );
    tester.binding.handlePointerEvent(
      PointerDownEvent(pointer: 12, position: center + const Offset(32, 0)),
    );
    await tester.pump(const Duration(milliseconds: 160));
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 11,
        position: center - const Offset(66, 0),
        delta: const Offset(-34, 0),
      ),
    );
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 12,
        position: center + const Offset(66, 0),
        delta: const Offset(34, 0),
      ),
    );
    await tester.pump();
    tester.binding.handlePointerEvent(
      PointerUpEvent(pointer: 11, position: center - const Offset(66, 0)),
    );
    tester.binding.handlePointerEvent(
      PointerUpEvent(pointer: 12, position: center + const Offset(66, 0)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsNothing);
    expect(stack, findsOneWidget);
    expect(tester.getSize(stack).height, greaterThan(initialHeight));
  });

  testWidgets('home title toggles the bottom navigation like H5', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-title-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-市场')), findsNothing);

    await tester.tap(find.byKey(const Key('home-title-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
  });

  testWidgets('can remove every mock card and verify the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();

    for (final id in const [
      'etherfi-core',
      'bybit-card',
      'redotpay',
      'metamask-card',
    ]) {
      await tester.tap(find.byKey(Key('toggle-$id')));
      await tester.pump();
    }

    await tester.tap(find.byKey(const Key('nav-我的卡片')));
    await tester.pumpAndSettle();

    expect(find.text('还没有卡片'), findsOneWidget);
  });

  testWidgets('every primary navigation destination responds', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    for (final destination in const {
      '市场': Key('market-page'),
      '排行': Key('ranking-page'),
      '我的': Key('profile-page'),
    }.entries) {
      await tester.tap(find.byKey(Key('nav-${destination.key}')));
      await tester.pumpAndSettle();
      expect(find.byKey(destination.value), findsOneWidget);
    }
  });

  testWidgets('supports a narrow screen with large system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('home-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('market matches the current H5 empty directory state', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pump();
    expect(find.byKey(const Key('market-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-empty')), findsOneWidget);
    expect(find.text('没有找到匹配卡片'), findsOneWidget);
    expect(find.text('换个关键词或分类试试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-filter-newest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-group-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-empty')), findsOneWidget);
    expect(find.byKey(const Key('market-filter-newest')), findsNothing);
  });

  testWidgets('searches the market and opens a preview', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'wise',
    );
    await tester.pump();
    expect(find.text('Wise Account'), findsOneWidget);
    expect(find.text('EtherFi Cash'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-card-wise-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    final cardGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('interactive-card-artwork'))),
    );
    await cardGesture.moveBy(const Offset(24, 10));
    await tester.pump();
    await cardGesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-basic-info')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('detail-basic-info')), findsOneWidget);
    expect(find.byKey(const Key('nav-市场')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-toggle-card')));
    await tester.pumpAndSettle();
    expect(find.text('已添加，点击移除'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-source')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('detail-fees')), findsOneWidget);
    expect(find.byKey(const Key('detail-source')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('preview-back')),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-search-page')), findsOneWidget);
  });

  testWidgets('reuses search to add a card to the home collection', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'N26',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('catalog-card-n26-standard')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('search-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的卡片')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-card-n26-standard')), findsOneWidget);
  });

  testWidgets('renders a formal market failure state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: const _FailingRepository(),
          onSearch: _noop,
          onOpenCard: _ignoreCard,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-error')), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
  });

  testWidgets('market and search fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-search-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card details support large text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-etherfi-core')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-kyc')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('detail-kyc')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens UI-only login from the guest profile', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(find.text('游客模式'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byKey(const Key('auth-service-notice')), findsOneWidget);
    expect(find.byKey(const Key('auth-google')), findsOneWidget);
    expect(find.byKey(const Key('auth-apple')), findsOneWidget);
    expect(find.byKey(const Key('nav-我的')), findsNothing);
  });

  testWidgets('validates login locally and clears the password', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-login')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('请输入用户名或邮箱'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'demo_user',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'not-a-real-password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-preview-result')), findsOneWidget);
    final passwordField = tester.widget<TextFormField>(
      find.byKey(const Key('auth-password-field')),
    );
    expect(passwordField.controller?.text, isEmpty);
  });

  testWidgets('switches to register and rejects mismatched passwords', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-login')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-to-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-to-register')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register-page')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password-one',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-field')),
      'password-two',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(find.byKey(const Key('auth-preview-result')), findsNothing);
  });

  testWidgets('auth UI supports narrow screens, large text and back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('auth-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking exposes ranking charts metrics and articles', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking-page')), findsOneWidget);
    expect(find.text('排行榜暂时没加载出来'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-charts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stablecoin-market-overview')), findsOneWidget);
    expect(find.text('\$314.00B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('metrics-data-table')), findsOneWidget);
    expect(find.text('主流 U 卡链上数据'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-articles')));
    await tester.pumpAndSettle();
    expect(find.text('文章暂时没加载出来'), findsOneWidget);
  });

  testWidgets('opens a card from the H5 metrics table', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('metric-row-etherfi')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('nav-排行')), findsNothing);

    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-page')), findsOneWidget);
  });

  testWidgets('profile menu opens public information subpages', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-help')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-menu-help')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-subpage-help')), findsOneWidget);
    expect(find.text('如何添加卡片？'), findsOneWidget);
    expect(find.byKey(const Key('nav-我的')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
  });

  testWidgets('submission pages stay local and clear entered content', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-recommend')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('profile-page')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-recommend')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('submission-description')),
      '这是一张值得收录的演示卡片',
    );
    await tester.ensureVisible(find.byKey(const Key('submission-submit')));
    await tester.tap(find.byKey(const Key('submission-submit')));
    await tester.pumpAndSettle();

    expect(find.text('表单预览完成，内容未发送或保存。'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('submission-description')),
    );
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('card detail opens the UI-only correction form', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-etherfi-core')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-correction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-correction-page')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('correction-description')),
      '官方页面的年费信息已经更新',
    );
    await tester.tap(find.byKey(const Key('correction-submit')));
    await tester.pumpAndSettle();
    expect(find.text('纠错表单预览完成，内容未发送或保存。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('correction-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
  });

  testWidgets('card detail more menu exposes H5 actions', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-card-etherfi-core')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-action-favorite')), findsOneWidget);
    expect(find.byKey(const Key('detail-effect-particle')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-similar')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-official')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-correction')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-remove')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-effect-flame')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-action-favorite')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-similar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(find.byKey(const Key('card-preview-page')), findsNothing);
  });

  testWidgets('ranking article state mirrors the unavailable H5 service', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-articles')));
    await tester.pumpAndSettle();
    expect(find.text('文章暂时没加载出来'), findsOneWidget);
    expect(find.text('稍后刷新看看，或者等后台发布新的文章。'), findsOneWidget);
    expect(find.byKey(const Key('article-detail-page')), findsNothing);
  });

  testWidgets('viewing a card updates the shared browsing history', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'n26',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-n26-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-history')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-history'))),
      alignment: 0.4,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-history')));
    await tester.pumpAndSettle();

    expect(find.text('N26 Standard'), findsOneWidget);
  });

  testWidgets('card height setting changes the home stack', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    final initialHeight = tester
        .getSize(find.byKey(const Key('card-stack')))
        .height;

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('profile-page')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('profile-card-height')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的卡片')));
    await tester.pumpAndSettle();

    final updatedHeight = tester
        .getSize(find.byKey(const Key('card-stack')))
        .height;
    expect(updatedHeight, greaterThan(initialHeight));
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble('card-app-home-card-height-scale-v1'),
      greaterThan(1),
    );
  });

  testWidgets('switches and remembers the H5 theme', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}

void _noop() {}

void _ignoreCard(CardSummary _) {}

class _FailingRepository implements CardCatalogRepository {
  const _FailingRepository();

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) =>
      Future.error(Exception('offline'));
}
