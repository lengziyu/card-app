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
    SharedPreferences.setMockInitialValues({});
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
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
  });

  testWidgets('home switches to the ArkFlow-style focus mode smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.byKey(const Key('home-mode-menu')), findsOneWidget);
    expect(find.text('堆叠'), findsOneWidget);
    expect(find.text('聚焦'), findsOneWidget);
    expect(find.text('钱包'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-mode-focus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-focus-stack')), findsOneWidget);
    expect(find.byKey(const Key('card-stack')), findsNothing);
    expect(find.byKey(const Key('home-focus-close')), findsNothing);
    expect(find.byKey(const Key('nav-市场')), findsOneWidget);

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

  testWidgets('home exposes only mode and add actions', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-mode-button')), findsOneWidget);
    expect(find.byKey(const Key('home-sort-button')), findsNothing);
    expect(find.byKey(const Key('home-wallet-button')), findsNothing);
    expect(find.byKey(const Key('home-add-button')), findsOneWidget);

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
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-wallet')));
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
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-mode-wallet')));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-wallet-card-etherfi-core'));
    final cardTopLeft = tester.getTopLeft(card);
    final cardSize = tester.getSize(card);
    await tester.tapAt(cardTopLeft + Offset(cardSize.width / 2, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('home-mode-wallet')), findsNothing);
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

  testWidgets('asks guests to log in before adding cards', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byKey(const Key('add-card-page')), findsNothing);
  });

  testWidgets('auth uses a top home action without language or support links', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-add-button')));
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

    await tester.tap(find.byKey(const Key('home-card-redotpay')));
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

  testWidgets('guest card customization opens the login guide', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
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

    final titleBottom = tester
        .getBottomLeft(find.byKey(const Key('home-title')))
        .dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(const Key('home-card-etherfi-core')))
        .dy;
    expect(firstCardTop - titleBottom, greaterThan(36));
  });

  testWidgets('add navigation is protected for guests', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
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

    expect(find.byKey(const Key('login-page')), findsOneWidget);
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
    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('searching to add a card requires login', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
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

  testWidgets('profile presents an account-first guest state', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
    expect(find.text('未登录用户'), findsOneWidget);
    expect(find.byKey(const Key('profile-guest-account')), findsOneWidget);
    expect(find.byKey(const Key('profile-login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('guest changes never create a local card collection', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-card-n26-standard')), findsNothing);
  });

  testWidgets('favorites require login and are not stored for guests', (
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
      'N26',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-n26-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-favorite')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
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

  testWidgets('profile keeps language help and about outside settings', (
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
    expect(find.byKey(const Key('profile-menu-help')), findsOneWidget);
    expect(find.byKey(const Key('profile-menu-about')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-menu-help')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-help')), findsOneWidget);
    expect(find.text('如何添加卡片？'), findsOneWidget);
    expect(find.byKey(const Key('nav-我的')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('profile-menu-about'))),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-about')), findsOneWidget);
    expect(find.text('关于集卡'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-subpage-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);

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
    expect(find.byKey(const Key('settings-help')), findsNothing);
    expect(find.byKey(const Key('settings-about')), findsNothing);
    expect(find.byKey(const Key('settings-version')), findsOneWidget);

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
    expect(find.text('显示语言已设为 English'), findsOneWidget);
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

  testWidgets('feedback is in settings and requires login', (tester) async {
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
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-feedback')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-feedback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('feedback-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('card detail correction requires login', (tester) async {
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

    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('card detail more menu exposes H5 actions', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-card-redotpay')));
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

  testWidgets('guest card browsing does not expose a personal history menu', (
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
    expect(find.byKey(const Key('profile-menu-history')), findsNothing);
  });

  testWidgets('card height setting changes the home stack', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    final firstCard = find.byKey(const Key('home-card-etherfi-core'));
    final selectedCard = find.byKey(const Key('home-card-redotpay'));
    final initialReveal =
        tester.getTopLeft(selectedCard).dy - tester.getTopLeft(firstCard).dy;

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

    final updatedReveal =
        tester.getTopLeft(selectedCard).dy - tester.getTopLeft(firstCard).dy;
    expect(updatedReveal, greaterThan(initialReveal));
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
