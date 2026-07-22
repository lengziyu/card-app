import 'dart:math' as math;

import 'package:card_app/app/card_app.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'card-app-language-v1': 'zh-CN'});
    PackageInfo.setMockInitialValues(
      appName: '集卡',
      packageName: 'cn.lengziyu.cardapp',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('renders the card collection home', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(find.byKey(const Key('home-card-etherfi-core')), findsOneWidget);
    expect(find.byKey(const Key('home-mode-wallet')), findsOneWidget);
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
  });

  testWidgets('free users see crowns and open the Pro page', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('home-mode-menu')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsNWidgets(2),
    );
    final walletTop = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const Key('home-mode-menu')),
        matching: find.byKey(const Key('home-mode-wallet')),
      ),
    );
    final stackTop = tester.getTopLeft(
      find.byKey(const Key('home-mode-stack')),
    );
    final focusTop = tester.getTopLeft(
      find.byKey(const Key('home-mode-focus')),
    );
    expect(walletTop.dy, lessThan(stackTop.dy));
    expect(stackTop.dy, lessThan(focusTop.dy));

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('home-mode-menu')),
        matching: find.byKey(const Key('home-mode-wallet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsNothing);
    expect(find.byKey(const Key('home-mode-wallet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-stack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.byKey(const Key('card-stack')), findsNothing);

    await tester.tap(find.byKey(const Key('pro-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-focus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.text('集卡 Pro'), findsOneWidget);
    expect(find.text('Pro 权益'), findsOneWidget);
    expect(find.byKey(const Key('home-focus-stack')), findsNothing);

    final purchaseButton = tester.widget<FilledButton>(
      find.byKey(const Key('pro-preview-purchase')),
    );
    expect(purchaseButton.onPressed, isNull);
    expect(find.text('正式商店配置完成后开放购买'), findsOneWidget);
  });

  testWidgets('market comparison entry is visible and gated for free users', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-compare-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('market-compare-button')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('market-compare-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.byKey(const Key('card-comparison-page')), findsNothing);
  });

  testWidgets('Pro users can compare up to four cards and swap positions', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text']?.toString();
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': copiedText};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-comparison-page')), findsOneWidget);
    expect(find.byKey(const Key('comparison-left-card')), findsOneWidget);
    expect(find.byKey(const Key('comparison-right-card')), findsOneWidget);
    expect(find.byKey(const Key('comparison-row-卡片类型')), findsOneWidget);
    expect(find.byKey(const Key('comparison-fee-estimator')), findsOneWidget);
    expect(find.textContaining('覆盖 2/4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comparison-save-preset')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('方案已保存'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('comparison-export-csv')));
    await tester.tap(find.byKey(const Key('comparison-export-csv')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      contains('适用地区'),
    );
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const Key('card-comparison-page')),
            matching: find.byType(ListView),
          )
          .first,
      const Offset(0, 1200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comparison-add-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-redotpay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comparison-card-redotpay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('comparison-add-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-metamask-card')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('comparison-card-metamask-card')),
      findsOneWidget,
    );
    expect(find.text('已选 4/4'), findsOneWidget);
    expect(find.byKey(const Key('comparison-add-card')), findsNothing);

    await tester.tap(find.byKey(const Key('comparison-swap')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-comparison-page')), findsOneWidget);
  });

  testWidgets('active Pro users can manage the local workspace', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-pro')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pro-open-workspace')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('pro-open-workspace')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pro-workspace-page')), findsOneWidget);
    expect(find.text('卡包结构报告'), findsOneWidget);
    expect(find.byKey(const Key('pro-open-bill-analysis')), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('pro-open-bill-analysis'))),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro-open-bill-analysis')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bill-analysis-page')), findsOneWidget);
    expect(find.text('识别真实消费成本'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bill-analysis-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-workspace-page')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pro-manage-watchlist')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('pro-workspace-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('pro-manage-watchlist')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-toggle-etherfi-core')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('完成'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-watched-etherfi-core')), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('pro-watched-etherfi-core'))),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro-watched-etherfi-core')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-workspace-page')), findsOneWidget);
  });

  testWidgets('home switches to the ArkFlow-style focus mode smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.byKey(const Key('home-mode-menu')), findsOneWidget);
    expect(find.text('堆叠'), findsOneWidget);
    expect(find.text('聚焦'), findsOneWidget);
    expect(find.text('钱包'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-mode-focus')),
        matching: find.byIcon(Icons.view_day_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home-mode-focus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-focus-stack')), findsOneWidget);
    expect(find.byKey(const Key('card-stack')), findsNothing);
    expect(find.byKey(const Key('home-focus-close')), findsNothing);
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
    expect(find.byKey(const Key('home-mode-position')), findsNothing);
    expect(find.byKey(const Key('home-card-previous')), findsNothing);
    expect(find.byKey(const Key('home-card-next')), findsNothing);
    expect(find.text('轻触查看'), findsNothing);

    final initiallyFocused = find.byKey(const Key('home-focus-card-redotpay'));
    final initialTop = tester.getTopLeft(initiallyFocused).dy;
    await tester.drag(
      find.byKey(const Key('home-focus-stack')),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(initiallyFocused).dy, lessThan(initialTop));
    expect(tester.takeException(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('card-app-home-card-display-mode-v1'),
      HomeCardDisplayMode.focus.name,
    );
  });

  testWidgets('stack mode swipes between cards without moving the module', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-stack')));
    await tester.pumpAndSettle();

    final stack = find.byKey(const Key('card-stack'));
    final moduleTop = tester.getTopLeft(stack).dy;
    expect(find.text('轻触查看'), findsNothing);

    final selectedCard = find.byKey(const Key('home-card-redotpay'));
    final selectedTop = tester.getTopLeft(selectedCard).dy;
    final gesture = await tester.startGesture(tester.getCenter(stack));
    await gesture.moveBy(const Offset(0, -44));
    await tester.pump();
    expect(tester.getTopLeft(selectedCard).dy, lessThan(selectedTop));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.drag(stack, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(stack).dy, moduleTop);
    expect(find.byKey(const Key('home-card-blur-redotpay')), findsOneWidget);
    final redotpayVeil = tester.widget<Opacity>(
      find.byKey(const Key('home-card-veil-redotpay')),
    );
    expect(redotpayVeil.opacity, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home exposes mode and add actions', (tester) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-mode-button')), findsOneWidget);
    expect(find.byKey(const Key('home-sort-button')), findsNothing);
    expect(find.byKey(const Key('home-wallet-button')), findsNothing);
    expect(find.byKey(const Key('home-add-button')), findsOneWidget);
    expect(find.byKey(const Key('home-navigation-toggle')), findsNothing);
    expect(find.byKey(const Key('home-title-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-stack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-wallet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-mode-wallet')), findsOneWidget);
    expect(find.byKey(const Key('card-stack')), findsNothing);

    final firstCard = find.byKey(const Key('home-wallet-card-etherfi-core'));
    final secondCard = find.byKey(const Key('home-wallet-card-bybit-card'));
    expect(
      tester.getTopLeft(secondCard).dy - tester.getTopLeft(firstCard).dy,
      lessThan(tester.getSize(firstCard).height / 2),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('card-app-home-card-display-mode-v1'),
      HomeCardDisplayMode.wallet.name,
    );
  });

  testWidgets('wallet reorder keeps the dragged card under the pointer', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-card-etherfi-core'));
    final origin = tester.getTopLeft(card);
    final cardSize = tester.getSize(card);
    final gesture = await tester.startGesture(
      origin + Offset(cardSize.width / 2, 24),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    final firstDragTop = tester.getTopLeft(card).dy;
    expect(firstDragTop, closeTo(origin.dy + 140, 5));

    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(
      tester.getTopLeft(card).dy - firstDragTop,
      closeTo(10, 2),
      reason: 'slot reordering must not replace the cumulative drag anchor',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet card tap opens details without expanding the layout', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-wallet-card-etherfi-core'));
    final cardTopLeft = tester.getTopLeft(card);
    final cardSize = tester.getSize(card);
    await tester.tapAt(cardTopLeft + Offset(cardSize.width / 2, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('market-card-transition')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home header stays fixed while cards pass beneath the fade', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final title = find.byKey(const Key('home-title'));
    final initialTitleTop = tester.getTopLeft(title).dy;
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dy, initialTitleTop);
    expect(find.byKey(const Key('home-card-etherfi-core')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the local card catalog from the home action', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
    expect(find.byKey(const Key('login-page')), findsNothing);
  });

  testWidgets('level card opens auth without extra links', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-home')), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.text('帮助中心'), findsNothing);
    expect(find.byKey(const Key('auth-back')), findsNothing);

    await tester.tap(find.byKey(const Key('switch-to-register')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-page')), findsOneWidget);
    expect(find.text('已有账号'), findsOneWidget);
  });

  testWidgets('opens a home card detail like H5', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final redotpay = find.byKey(const Key('home-card-redotpay'));
    final redotpaySize = tester.getSize(redotpay);
    await tester.tapAt(
      tester.getTopLeft(redotpay) + Offset(redotpaySize.width / 2, 20),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('market-card-transition')), findsOneWidget);
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

  testWidgets('guest card customization opens the local catalog', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
  });

  test('home card pinch scale uses the same H5 limits', () {
    expect(clampHomeCardHeightScale(0), homeCardHeightScaleMin);
    expect(clampHomeCardHeightScale(10), homeCardHeightScaleMax);
    expect(homeCardHeightPercent(1), 62);
  });

  testWidgets('two-finger hold then pinch changes the home card height', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-stack')));
    await tester.pumpAndSettle();

    final stack = find.byKey(const Key('card-stack'));
    final firstCard = find.byKey(const Key('home-card-etherfi-core'));
    final selectedCard = find.byKey(const Key('home-card-redotpay'));
    final initialReveal =
        tester.getTopLeft(selectedCard).dy - tester.getTopLeft(firstCard).dy;
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
    expect(
      tester.getTopLeft(selectedCard).dy - tester.getTopLeft(firstCard).dy,
      greaterThan(initialReveal),
    );
  });

  testWidgets('home title toggles immersive navigation', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-title-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-市场')), findsNothing);

    await tester.tap(find.byKey(const Key('home-title-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);

    final titleBottom = tester
        .getBottomLeft(find.byKey(const Key('home-title')))
        .dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(const Key('home-card-etherfi-core')))
        .dy;
    expect(firstCardTop - titleBottom, greaterThan(36));
  });

  testWidgets('add navigation opens the local catalog', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
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

    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-mode-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('home-mode-focus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-focus-stack')), findsOneWidget);
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

  testWidgets('opens the interactive card canvas from the market header', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-canvas-button')), findsOneWidget);
    expect(find.byIcon(Icons.scatter_plot_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-canvas-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-canvas-page')), findsOneWidget);
    expect(
      find.byKey(const Key('card-canvas-interactive-viewer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nav-市场')), findsNothing);
    expect(
      find.byKey(const Key('card-canvas-card-0-etherfi-core')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('card-canvas-layout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-canvas-layout-gallery')), findsOneWidget);
    await tester.tap(find.byKey(const Key('card-canvas-layout-gallery')));
    await tester.pump();
    expect(find.byKey(const Key('card-canvas-columns-slider')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('card-canvas-columns-slider')),
      const Offset(100, 0),
    );
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-canvas-angle-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-canvas-stagger-switch')), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-canvas-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(find.byKey(const Key('card-canvas-page')), findsNothing);
  });

  testWidgets(
    'card canvas toggles a dot grid and hides controls in fullscreen',
    (tester) async {
      await tester.pumpWidget(const CardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-市场')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-canvas-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('card-canvas-background-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('card-canvas-dot-grid-choice')));
      await tester.pump();
      expect(find.byKey(const Key('card-canvas-dot-grid')), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('card-canvas-immersive-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('card-canvas-immersive-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card-canvas-close')), findsNothing);
      expect(find.byKey(const Key('card-canvas-layout-button')), findsNothing);
      expect(find.byKey(const Key('card-canvas-zoom-in')), findsNothing);

      await tester.tap(find.byKey(const Key('card-canvas-immersive-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card-canvas-close')), findsOneWidget);
    },
  );

  testWidgets(
    'card canvas supports one-finger panning, bounded blank space, and animated zoom',
    (tester) async {
      await tester.pumpWidget(const CardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-市场')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-canvas-button')));
      await tester.pumpAndSettle();

      Matrix4 canvasMatrix() => tester
          .widget<Transform>(find.byKey(const Key('card-canvas-transform')))
          .transform;

      final initialMatrix = canvasMatrix().clone();
      final gesture = await tester.startGesture(const Offset(220, 360));
      await gesture.moveBy(const Offset(-84, -62));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final draggedMatrix = canvasMatrix().clone();
      expect(draggedMatrix.storage[12], isNot(initialMatrix.storage[12]));
      expect(draggedMatrix.storage[13], isNot(initialMatrix.storage[13]));
      expect(find.byKey(const Key('card-canvas-page')), findsOneWidget);
      expect(find.byKey(const Key('card-preview-page')), findsNothing);

      final boundaryGesture = await tester.startGesture(const Offset(220, 360));
      await boundaryGesture.moveBy(const Offset(2400, 2400));
      await tester.pump();
      await boundaryGesture.up();
      await tester.pump();

      final artworkFinder = find.descendant(
        of: find.byKey(const Key('card-canvas-field')),
        matching: find.byType(CardArtwork),
      );
      final leftmost = artworkFinder
          .evaluate()
          .map(
            (element) => tester
                .getTopLeft(find.byElementPredicate((e) => e == element))
                .dx,
          )
          .reduce(math.min);
      final topmost = artworkFinder
          .evaluate()
          .map(
            (element) => tester
                .getTopLeft(find.byElementPredicate((e) => e == element))
                .dy,
          )
          .reduce(math.min);
      final viewportSize = tester.getSize(
        find.byKey(const Key('card-canvas-interactive-viewer')),
      );
      expect(leftmost, lessThanOrEqualTo(viewportSize.width / 2 + 2));
      expect(topmost, lessThanOrEqualTo(viewportSize.height / 2 + 2));

      await tester.tap(find.byKey(const Key('card-canvas-reset')));
      await tester.pumpAndSettle();
      final scaleBeforeZoom = canvasMatrix().getMaxScaleOnAxis();
      await tester.tap(find.byKey(const Key('card-canvas-zoom-in')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final scaleDuringZoom = canvasMatrix().getMaxScaleOnAxis();
      expect(scaleDuringZoom, greaterThan(scaleBeforeZoom));
      expect(scaleDuringZoom, lessThan(scaleBeforeZoom * 1.18));
      await tester.pumpAndSettle();
      expect(
        canvasMatrix().getMaxScaleOnAxis(),
        closeTo(scaleBeforeZoom * 1.18, .001),
      );
    },
  );

  testWidgets('card canvas autoplay exposes direction and stop controls', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-canvas-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-canvas-autoplay-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('card-canvas-direction-northEast')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('card-canvas-direction-northEast')));
    await tester.ensureVisible(
      find.byKey(const Key('card-canvas-autoplay-toggle')),
    );
    await tester.tap(find.byKey(const Key('card-canvas-autoplay-toggle')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(
        of: find.byKey(const Key('card-canvas-autoplay-button')),
        matching: find.byIcon(Icons.pause_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('card-canvas-autoplay-button')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('card-canvas-autoplay-button')),
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('card canvas fits a narrow screen with large text', (
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
    await tester.tap(find.byKey(const Key('market-canvas-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-canvas-close')), findsOneWidget);
    expect(find.byKey(const Key('card-canvas-infinite-button')), findsNothing);
    expect(find.byKey(const Key('card-canvas-reset')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('card-canvas-autoplay-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('card-canvas-autoplay-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('card-canvas-autoplay-toggle')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    final cardSurface = tester.widget<Container>(
      find.byKey(const Key('catalog-card-surface-wise-account')),
    );
    expect((cardSurface.decoration! as BoxDecoration).boxShadow, hasLength(2));

    await tester.tap(find.byKey(const Key('catalog-card-wise-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('global-account-stage')), findsOneWidget);
    expect(find.byKey(const Key('detail-toggle-card')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-basic-info')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('detail-basic-info')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-china-kyc')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('detail-china-kyc')), findsOneWidget);
    expect(find.text('可申请 · 需验证'), findsOneWidget);
    expect(find.byKey(const Key('nav-市场')), findsNothing);
  });

  testWidgets('add navigation is available without login', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
  });

  testWidgets('global accounts are excluded from adding cards', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toggle-wise-account')), findsNothing);
    await tester.tap(find.byKey(const Key('add-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'wise',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
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

  testWidgets('profile gates account data behind login', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(find.text('未登录用户'), findsOneWidget);
    expect(find.byKey(const Key('profile-guest-account')), findsOneWidget);
    expect(find.byKey(const Key('profile-login')), findsNothing);

    expect(find.byKey(const Key('profile-membership-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-cards')), findsNothing);
    expect(find.byKey(const Key('profile-menu-pro')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-menu-pro')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pro-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('guest card changes persist in the local collection', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();
    final addPageScrollable = find.descendant(
      of: find.byKey(const Key('add-card-page')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(addPageScrollable.first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-n26-standard')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-card-n26-standard')), findsOneWidget);
  });

  testWidgets('favorites are stored locally for guests', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'N26',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-n26-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-favorite')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'card-app-guest-state-v1',
      ),
      contains('n26-standard'),
    );
  });

  testWidgets('ranking exposes cards users metrics stablecoins and articles', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking-page')), findsOneWidget);
    expect(find.text('排行榜暂时没加载出来'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-users')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-ranking-panel')), findsOneWidget);
    expect(find.byKey(const Key('user-ranking-demo-1')), findsOneWidget);
    expect(find.byKey(const Key('pro-crown-badge')), findsWidgets);

    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('metrics-data-table')), findsOneWidget);
    expect(
      find.byKey(const Key('metrics-stablecoin-shortcut')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('metrics-stablecoin-shortcut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stablecoin-market-overview')), findsOneWidget);
    expect(find.text('\$314.00B'), findsWidgets);
    expect(find.byKey(const Key('stablecoin-icon-usdt')), findsWidgets);
    expect(
      find.byKey(const Key('stablecoin-chain-icon-ethereum')),
      findsOneWidget,
    );
    expect(find.textContaining('前 1 合计'), findsNothing);
    expect(find.textContaining('其余稳定币占'), findsNothing);
    expect(
      tester.getBottomLeft(find.byKey(const Key('stablecoin-share-panel'))).dy,
      closeTo(
        tester
            .getBottomLeft(find.byKey(const Key('stablecoin-network-panel')))
            .dy,
        .1,
      ),
    );

    Navigator.of(
      tester.element(find.byKey(const Key('stablecoin-market-overview'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('metrics-data-table')), findsOneWidget);
    expect(find.text('主流 U 卡链上数据'), findsOneWidget);
    expect(find.byKey(const Key('metric-brand-etherfi')), findsOneWidget);
    expect(find.byType(SvgPicture), findsWidgets);
    final fixedColumn = find.byKey(const Key('metrics-fixed-card-column'));
    final scrollableValues = find.byKey(const Key('metrics-scrollable-values'));
    final valuesHeader = find.byKey(const Key('metrics-values-header'));
    final fixedLeft = tester.getTopLeft(fixedColumn).dx;
    final valuesLeft = tester.getTopLeft(valuesHeader).dx;
    expect(tester.getSize(fixedColumn).width, 164);
    expect(find.byKey(const Key('metric-name-etherfi')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('metric-name-visibility-etherfi')),
          )
          .opacity,
      1,
    );
    await tester.drag(scrollableValues, const Offset(-220, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(fixedColumn).width, inExclusiveRange(54, 164));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(fixedColumn).dx, fixedLeft);
    expect(tester.getSize(fixedColumn).width, 54);
    expect(find.byKey(const Key('metric-name-etherfi')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('metric-name-visibility-etherfi')),
          )
          .opacity,
      0,
    );
    expect(find.byKey(const Key('metric-brand-etherfi')), findsOneWidget);
    expect(tester.getTopLeft(valuesHeader).dx, lessThan(valuesLeft));

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

  testWidgets('long-range market history is gated and unlocks for Pro', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('metrics-stablecoin-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stablecoin-range-90d')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const CardApp(key: ValueKey('pro-history-app'), proUnlocked: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('metrics-stablecoin-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stablecoin-range-90d')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsNothing);
    expect(find.byKey(const Key('stablecoin-market-overview')), findsOneWidget);
  });

  testWidgets('profile groups language with settings and moves help/about', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-menu-language')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-help')), findsNothing);
    expect(find.byKey(const Key('profile-menu-about')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-settings'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-subpage-settings')), findsOneWidget);
    expect(find.byKey(const Key('settings-language')), findsNothing);
    expect(find.byKey(const Key('settings-help')), findsOneWidget);
    expect(find.byKey(const Key('settings-about')), findsOneWidget);
    expect(find.byKey(const Key('settings-version')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-help')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-help')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-help')), findsOneWidget);
    expect(find.text('如何添加卡片？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-settings')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-about')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-about')), findsOneWidget);
    expect(find.text('关于集卡'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-settings')), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings-version'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-version')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-version')), findsOneWidget);
    expect(find.text('版本 0.1.0  ·  构建 1'), findsOneWidget);
    expect(find.text('cn.lengziyu.cardapp'), findsOneWidget);
    await tester.tap(find.byKey(const Key('version-copy')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('复制成功'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
  });

  testWidgets('settings exposes notification and haptic controls', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-settings'))),
      alignment: .55,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();

    for (final key in const [
      Key('settings-notification-permission'),
      Key('settings-reminder-config'),
      Key('settings-haptics'),
      Key('settings-card-swipe-haptics'),
      Key('settings-card-swipe-strength'),
    ]) {
      await Scrollable.ensureVisible(
        tester.element(find.byKey(key)),
        alignment: .5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.text('未设置'), findsOneWidget);

    final hapticsSwitch = find.descendant(
      of: find.byKey(const Key('settings-haptics')),
      matching: find.byType(Switch),
    );
    await tester.tap(hapticsSwitch);
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'card-app-haptics-enabled-v1',
      ),
      isFalse,
    );
    await tester.tap(hapticsSwitch);
    await tester.pumpAndSettle();

    final strength = find.byKey(const Key('settings-card-swipe-strength'));
    await Scrollable.ensureVisible(
      tester.element(strength),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.tap(find.descendant(of: strength, matching: find.text('高')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'card-app-card-swipe-strength-v1',
      ),
      'strong',
    );

    await tester.drag(
      find.byKey(const Key('profile-subpage-settings')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings-reminder-config'))),
      alignment: .72,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-reminder-config')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-reminders')), findsOneWidget);
    expect(find.byKey(const Key('settings-content-push')), findsOneWidget);
  });

  testWidgets('display language offers countries and persists the selection', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-language'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-language')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-subpage-language')), findsOneWidget);
    for (final key in const [
      'system',
      'zh-CN',
      'zh-HK',
      'en-US',
      'ja-JP',
      'ko-KR',
      'vi-VN',
      'ru-RU',
      'es-ES',
      'fr-FR',
      'de-DE',
      'pt-BR',
      'tr-TR',
    ]) {
      expect(find.byKey(Key('language-$key')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('language-en-US')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Display language set to English'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('card-app-language-v1'),
      'en-US',
    );

    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-language'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-language')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-language')), findsOneWidget);
    expect(find.byKey(const Key('language-en-US')), findsOneWidget);
  });

  testWidgets('feedback is saved to the local outbox', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-feedback')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings-feedback'))),
      alignment: .55,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-feedback')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-feedback')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('submission-subject')), '体验建议');
    await tester.enterText(
      find.byKey(const Key('submission-description')),
      '希望进一步优化卡片筛选体验。',
    );
    await tester.tap(find.byKey(const Key('submission-submit')));
    await tester.pumpAndSettle();
    expect(find.text('反馈已提交，感谢你的建议。'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'card-app-guest-state-v1',
      ),
      contains('希望进一步优化卡片筛选体验'),
    );
  });

  testWidgets('card detail correction opens the local form', (tester) async {
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
  });

  testWidgets('card detail more menu exposes H5 actions', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    final redotpay = find.byKey(const Key('home-card-redotpay'));
    final redotpaySize = tester.getSize(redotpay);
    await tester.tapAt(
      tester.getTopLeft(redotpay) + Offset(redotpaySize.width / 2, 20),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-action-favorite')), findsOneWidget);
    expect(find.byKey(const Key('detail-effect-particle')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-compare')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-watch')), findsOneWidget);
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

  testWidgets('guest local history requires login from profile', (
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
    expect(find.byKey(const Key('profile-menu-history')), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-history'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.tap(find.byKey(const Key('profile-menu-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byKey(const Key('profile-subpage-history')), findsNothing);
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
