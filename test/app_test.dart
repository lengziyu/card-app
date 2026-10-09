import 'dart:math' as math;

import 'package:cardfi/app/card_app.dart' as app;
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/data/local_card_details.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/presentation/card_preview_page.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/interactive_card_artwork.dart';
import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/motion/edge_swipe_back.dart';
import 'package:cardfi/features/home/domain/card_layout_calculator.dart';
import 'package:cardfi/features/home/domain/home_card_layout.dart';
import 'package:cardfi/features/home/widgets/card_stack_view.dart';
import 'package:cardfi/features/home/widgets/home_card_scene_fade.dart';
import 'package:cardfi/features/market/presentation/card_advisor_page.dart';
import 'package:cardfi/features/market/presentation/market_page.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
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
      appName: 'CardFi',
      packageName: 'cn.lengziyu.cardapp',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  test('cinematic card reconstruction keeps a mobile-safe paint budget', () {
    for (final effect in const [
      CardVisualEffect.shards,
      CardVisualEffect.scanReveal,
      CardVisualEffect.foldReveal,
      CardVisualEffect.photoEtch,
      CardVisualEffect.liquidCast,
      CardVisualEffect.bandAlign,
    ]) {
      expect(
        cardReconstructionParticleBudget(effect),
        inInclusiveRange(520, 720),
      );
    }
  });

  test('iOS card details hide payment support while Android keeps it', () {
    const channels = {
      PaymentChannel.applePay,
      PaymentChannel.googlePay,
      PaymentChannel.wechatPay,
    };

    expect(paymentChannelsForPlatform(channels, TargetPlatform.iOS), isEmpty);
    expect(
      paymentChannelsForPlatform(channels, TargetPlatform.android),
      channels,
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

  testWidgets('guests see Pro locks for home stack and focus modes', (
    tester,
  ) async {
    await tester.pumpWidget(CardApp(authRepository: _GuestAuthRepository()));
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
    expect(find.byKey(const Key('home-focus-stack')), findsNothing);
  });

  testWidgets('market comparison entry requires login for free users', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-compare-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('market-compare-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('card-comparison-page')), findsNothing);
  });

  testWidgets('AI assistants require login before opening their shared entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      CardApp(
        key: const ValueKey('free-ai'),
        authRepository: _GuestAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();

    final aiEntry = find.byKey(const Key('market-ai-advisor-button'));
    await tester.tap(aiEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('ai-assistant-hub')), findsNothing);

    await tester.pumpWidget(
      CardApp(
        key: const ValueKey('pro-ai'),
        proUnlocked: true,
        authRepository: const _SignedInAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-ai-advisor-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-assistant-hub')), findsOneWidget);
    expect(find.byKey(const Key('ai-assistant-card-match')), findsOneWidget);
    expect(
      find.byKey(const Key('ai-assistant-application-prep')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-assistant-card-match')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-advisor-page')), findsOneWidget);
  });

  testWidgets('advisor detail hides the retained advisor until returning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CardApp(authRepository: _SignedInAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-ai-advisor-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-assistant-card-match')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-advisor-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('card-advisor-previous')),
      findsOneWidget,
      reason: 'the advisor should be on its second step before opening detail',
    );

    tester
        .widget<CardAdvisorPage>(find.byType(CardAdvisorPage))
        .onOpenCard(localCardCatalog.first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(find.byKey(const Key('card-advisor-page')), findsNothing);
    expect(
      find.byKey(const Key('card-advisor-page'), skipOffstage: false),
      findsOneWidget,
      reason:
          'the advisor stays mounted so its result and scroll state survive',
    );
    final retainedLayer = tester.widget<Offstage>(
      find.byKey(const Key('card-advisor-retained-layer')),
    );
    expect(retainedLayer.offstage, isTrue);

    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-preview-page')), findsNothing);
    expect(find.byKey(const Key('card-advisor-page')), findsOneWidget);
    expect(find.byKey(const Key('card-advisor-previous')), findsOneWidget);
    expect(
      tester
          .widget<Offstage>(
            find.byKey(const Key('card-advisor-retained-layer')),
          )
          .offstage,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('card detail opens AI application prep for the current card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CardApp(
        proUnlocked: true,
        authRepository: _SignedInAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-redotpay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(
      find.byKey(const Key('detail-ai-application-assistant')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('detail-action-application-assistant')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('detail-action-application-assistant')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('card-application-assistant-page')),
      findsOneWidget,
    );
    expect(find.textContaining('RedotPay'), findsWidgets);
    expect(
      find.byKey(const Key('application-assistant-card-picker')),
      findsNothing,
    );
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
    await tester.pumpWidget(
      const CardApp(
        proUnlocked: true,
        authRepository: _SignedInAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-comparison-page')), findsOneWidget);
    expect(find.byKey(const Key('comparison-left-card')), findsOneWidget);
    expect(find.byKey(const Key('comparison-right-card')), findsOneWidget);
    expect(find.byKey(const Key('comparison-row-卡片类型')), findsOneWidget);
    expect(find.byKey(const Key('comparison-row-返现概览')), findsOneWidget);
    expect(find.byKey(const Key('comparison-row-评级')), findsOneWidget);
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
    expect(find.byKey(const Key('catalog-card-wise-account')), findsNothing);
    expect(
      find.byKey(const Key('catalog-card-airwallex-global-account')),
      findsNothing,
    );
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

  testWidgets('regular users can compare exactly two cards', (tester) async {
    await tester.pumpWidget(
      const CardApp(authRepository: _SignedInAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-comparison-page')), findsOneWidget);
    expect(find.text('已选 2/2'), findsOneWidget);
    expect(find.byKey(const Key('comparison-add-card')), findsNothing);
  });

  testWidgets('active Pro users can manage the local workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CardApp(
        proUnlocked: true,
        authRepository: _SignedInAuthRepository(),
      ),
    );
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
    expect(find.byKey(const Key('pro-open-bill-history')), findsNothing);
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
    expect(find.byKey(const Key('bill-open-history')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bill-analysis-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-workspace-page')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pro-manage-watchlist')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('pro-workspace-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('pro-manage-watchlist'))),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
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

  testWidgets('bill analysis returns to the main tab it was opened from', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CardApp(
        proUnlocked: true,
        authRepository: _SignedInAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-bill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bill-analysis-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bill-analysis-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(find.byKey(const Key('pro-workspace-page')), findsNothing);
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
        matching: find.byIcon(AppIcons.homeFocus),
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
    expect(
      tester
          .widget<ImageFiltered>(
            find.byKey(const Key('home-card-filter-redotpay')),
          )
          .enabled,
      isFalse,
    );
    expect(find.byKey(const Key('home-card-veil-redotpay')), findsNothing);
    expect(
      tester
          .widget<ImageFiltered>(
            find.byKey(const Key('home-card-filter-bybit-card')),
          )
          .enabled,
      isTrue,
    );
    expect(find.byKey(const Key('home-card-veil-bybit-card')), findsOneWidget);

    final viewport = tester.getRect(find.byKey(const Key('home-fan-viewport')));
    expect(
      viewport.top,
      lessThan(tester.getTopLeft(find.byKey(const Key('home-title'))).dy),
    );
    expect(
      viewport.bottom,
      greaterThan(tester.getBottomLeft(find.byKey(const Key('nav-add'))).dy),
    );
    expect(
      find.descendant(
        of: find.byType(CardStackView),
        matching: find.byType(ClipRect),
      ),
      findsNothing,
    );

    double visualWidth(Finder finder) =>
        (tester.getTopRight(finder) - tester.getTopLeft(finder)).distance;
    expect(
      visualWidth(find.byKey(const Key('home-focus-card-redotpay'))),
      greaterThan(
        visualWidth(find.byKey(const Key('home-focus-card-bybit-card'))),
      ),
      reason: 'the focused middle card must be the widest layer',
    );

    final initiallyFocused = find.byKey(const Key('home-focus-card-redotpay'));
    final initialTop = tester.getTopLeft(initiallyFocused).dy;
    await tester.drag(
      find.byKey(const Key('home-focus-stack')),
      const Offset(0, -280),
    );
    await tester.pump(const Duration(milliseconds: 80));

    // 上一轮吸附尚未结束时再次落指，卡列应从当前画面直接接管，不能
    // 瞬移到上一轮目标位置。2px 的新手势只允许产生很小的视觉位移。
    final interruptedTop = tester.getTopLeft(initiallyFocused).dy;
    final continuedGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('home-focus-stack'))),
    );
    await continuedGesture.moveBy(const Offset(0, -2));
    await tester.pump();
    expect(
      (tester.getTopLeft(initiallyFocused).dy - interruptedTop).abs(),
      lessThan(12),
    );
    await continuedGesture.moveBy(const Offset(0, -96));
    await continuedGesture.up();
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
    // 首次上滑展开首张卡，后一张卡为它让出完整卡面空间。
    expect(tester.getTopLeft(selectedCard).dy, greaterThan(selectedTop));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.drag(stack, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(stack).dy, moduleTop);
    // 参照效果：非选中卡保持全彩，不再有模糊或白色蒙层。
    expect(find.byKey(const Key('home-card-blur-redotpay')), findsNothing);
    expect(find.byKey(const Key('home-card-veil-redotpay')), findsNothing);
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
    final firstCardSize = tester.getSize(firstCard);
    expect(
      firstCardSize.height,
      closeTo(firstCardSize.width / CardLayoutCalculator.cardAspectRatio, .1),
    );
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

  testWidgets('home header stays fixed while cards scroll below it', (
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

  testWidgets('wallet card drag reaches the outer scroll view', (tester) async {
    final originalPhysicalSize = tester.view.physicalSize;
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view
        ..physicalSize = originalPhysicalSize
        ..devicePixelRatio = originalDevicePixelRatio;
    });
    tester.view
      ..physicalSize = const Size(390, 600)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-card-etherfi-core'));
    final initialTop = tester.getTopLeft(card).dy;
    final gesture = await tester.startGesture(
      tester.getTopLeft(card) + const Offset(200, 24),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(card).dy,
      lessThan(initialTop - 20),
      reason: 'a drag starting on a wallet card must scroll the card list',
    );
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

    expect(find.text('邮箱地址'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.byKey(const Key('auth-password-field')), findsNothing);
  });

  testWidgets('a verified sign-in returns home with the card celebration', (
    tester,
  ) async {
    await tester.pumpWidget(
      CardApp(authRepository: const _VerifiedAuthRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-membership-card')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-account-field')),
      'member@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-otp-field')), '123456');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.byKey(const Key('login-page')), findsNothing);
    expect(find.byKey(const Key('auth-success-card-burst-1')), findsOneWidget);
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

  testWidgets('home card detail starts from particles without a full card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'card-app-language-v1': 'zh-CN',
      'card-app-card-visual-effect-v1': CardVisualEffect.flame.name,
    });
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final redotpay = find.byKey(const Key('home-card-redotpay'));
    final redotpaySize = tester.getSize(redotpay);
    await tester.tapAt(
      tester.getTopLeft(redotpay) + Offset(redotpaySize.width / 2, 20),
    );
    await tester.pump();
    await tester.pump();

    final interactiveArtwork = tester.widget<InteractiveCardArtwork>(
      find.byType(InteractiveCardArtwork),
    );
    expect(interactiveArtwork.effect, CardVisualEffect.flame);
    expect(
      interactiveArtwork.animateInitialEffect,
      isTrue,
      reason: 'the reconstruction must start on the first detail frame',
    );
    expect(
      interactiveArtwork.animateEffectChanges,
      isTrue,
      reason: 'restoring a saved effect must not settle to a full card',
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('market-card-transition')),
        matching: find.byType(CardArtwork),
      ),
      findsNothing,
      reason: 'a complete card must not appear before particle reconstruction',
    );
    expect(
      find.byKey(const Key('market-card-flight-position')),
      findsNothing,
      reason: 'the home entrance is owned entirely by the effect stage',
    );
    expect(
      tester
          .widget<InteractiveCardArtwork>(find.byType(InteractiveCardArtwork))
          .animateInitialEffect,
      isTrue,
    );
    final detailOpacity = tester
        .widget<Opacity>(find.byKey(const Key('detail-card-handoff-opacity')))
        .opacity;
    expect(detailOpacity, 1);

    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-card-handoff-opacity')))
          .opacity,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('market card stays continuous through detail and back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'card-app-language-v1': 'zh-CN',
      'card-app-card-visual-effect-v1': CardVisualEffect.flame.name,
    });
    await tester.pumpWidget(
      const CardApp(catalogRepository: LocalCardCatalogRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    final sourceRow = find.byKey(const Key('catalog-card-etherfi-core'));
    final sourcePosition = tester.getTopLeft(sourceRow);
    await tester.tap(find.byKey(const Key('catalog-card-etherfi-core')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final interactiveArtwork = tester.widget<InteractiveCardArtwork>(
      find.byType(InteractiveCardArtwork),
    );
    expect(interactiveArtwork.effect, CardVisualEffect.flame);
    expect(
      interactiveArtwork.animateInitialEffect,
      isFalse,
      reason: 'a shared card must not dissolve again when it reaches detail',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('market-card-transition')),
        matching: find.byType(CardArtwork),
      ),
      findsOneWidget,
      reason: 'the selected card stays visible throughout the shared flight',
    );
    expect(
      find.byKey(const Key('market-card-flight-position')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-card-handoff-opacity')))
          .opacity,
      0,
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
    expect(
      tester
          .widget<InteractiveCardArtwork>(find.byType(InteractiveCardArtwork))
          .animateInitialEffect,
      isFalse,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-card-handoff-opacity')))
          .opacity,
      1,
    );
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const Key('market-card-flight-position')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsNothing);
    expect(tester.getTopLeft(sourceRow), sourcePosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolled detail fades back without a misplaced flying card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CardApp(catalogRepository: LocalCardCatalogRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    final source = find.byKey(const Key('catalog-card-etherfi-core'));
    final sourcePosition = tester.getTopLeft(source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    final detailScrollable = find
        .descendant(
          of: find.byKey(const Key('card-preview-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(detailScrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    final detailOffset = tester
        .state<ScrollableState>(detailScrollable)
        .position
        .pixels;
    expect(detailOffset, greaterThan(20));

    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('market-card-flight-position')), findsNothing);
    expect(
      tester.state<ScrollableState>(detailScrollable).position.pixels,
      detailOffset,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-return-opacity')))
          .opacity,
      allOf(greaterThan(0), lessThan(1)),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(source), sourcePosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('market detail opens and returns with reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const CardApp(catalogRepository: LocalCardCatalogRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('market-page')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-card-etherfi-core')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-card-flight-position')), findsNothing);
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-card-handoff-opacity')))
          .opacity,
      1,
    );
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsNothing);
    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card detail shows its published rating and review count', (
    tester,
  ) async {
    final card = localCardCatalog.firstWhere(
      (candidate) => candidate.id == 'etherfi-core',
    );
    final detail = const LocalCardDetailRepository().detailFor(card);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardPreviewPage(
            card: card,
            detail: detail,
            added: false,
            favorite: false,
            onBack: () {},
            onAddedChanged: (_) {},
            onFavoriteChanged: (_) {},
            onCorrection: () {},
            onCompare: () {},
            onViewSimilar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(detail.rating, 4.9);
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-rating')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('card-preview-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('detail-rating')), findsOneWidget);
    expect(find.text('4.9 (1,536)'), findsOneWidget);
  });

  testWidgets('crypto account detail keeps a compact disclosure badge', (
    tester,
  ) async {
    const card = CardSummary(
      id: 'crypto-account',
      name: 'Crypto Account',
      issuer: 'Crypto',
      category: CardCategory.bankAccount,
      label: '全球账户',
      tint: 0xFF112233,
      kind: CatalogItemKind.globalAccount,
      accountType: 'cryptoPlatform',
    );
    const detail = CardDetail(
      cardId: 'crypto-account',
      tags: ['全球账户'],
      region: '以官网实时资格为准',
      funding: '以官网实时能力为准',
      availability: '以官网实时流程为准',
      features: [],
      fees: [],
      kycNote: '以官方流程为准。',
      paymentChannels: <PaymentChannel>{},
      sourceLabel: '测试来源',
      note: '测试说明',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardPreviewPage(
            card: card,
            detail: detail,
            added: false,
            favorite: false,
            onBack: () {},
            onAddedChanged: (_) {},
            onFavoriteChanged: (_) {},
            onCorrection: () {},
            onCompare: () {},
            onViewSimilar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-crypto-related-info')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('card-preview-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.byKey(const Key('detail-crypto-related-notice')), findsNothing);
    expect(
      find.byKey(const Key('detail-crypto-related-badge')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('detail-crypto-related-info')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('detail-crypto-related-sheet')),
      findsOneWidget,
    );
    expect(find.text('加密相关'), findsWidgets);
  });

  testWidgets('card detail shows all published opening requirements', (
    tester,
  ) async {
    const card = CardSummary(
      id: 'opening-requirement-card',
      name: 'Opening Card',
      issuer: 'Issuer',
      category: CardCategory.uCard,
      label: '测试卡',
      tint: 0xFF685CFF,
    );
    const detail = CardDetail(
      cardId: 'opening-requirement-card',
      tags: [],
      region: '全球',
      funding: 'USDT',
      availability: '开放申请',
      features: [],
      fees: [
        FeeLine(label: '外汇费', value: '0%', note: 'Core：0–0.5%\nLuxe：0–0.25%'),
      ],
      kycNote: '身份材料以官方流程为准。',
      paymentChannels: <PaymentChannel>{},
      sourceLabel: '测试来源',
      note: '测试说明',
      openingRequirements: CardOpeningRequirements(
        summary: '护照 + 海外证明',
        states: {
          OpeningRequirementKind.inviteCode:
              OpeningRequirementState.notRequired,
          OpeningRequirementKind.idCard: OpeningRequirementState.notRequired,
          OpeningRequirementKind.passport: OpeningRequirementState.required,
          OpeningRequirementKind.overseasAddressProof:
              OpeningRequirementState.required,
          OpeningRequirementKind.overseasPhone: OpeningRequirementState.unknown,
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardPreviewPage(
            card: card,
            detail: detail,
            added: false,
            favorite: false,
            onBack: () {},
            onAddedChanged: (_) {},
            onFavoriteChanged: (_) {},
            onCorrection: () {},
            onCompare: () {},
            onViewSimilar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-opening-requirements')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('开卡条件'), findsOneWidget);
    expect(find.text('通常需要：护照 + 海外证明'), findsOneWidget);
    for (final kind in OpeningRequirementKind.values) {
      expect(
        find.byKey(Key('opening-requirement-${kind.name}')),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-fees')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    final feeValue = tester.widget<Align>(
      find.byKey(const Key('detail-fee-value-外汇费')),
    );
    expect(feeValue.alignment, Alignment.centerRight);
    expect(find.byKey(const Key('detail-fee-notes')), findsNothing);
    expect(find.text('Core：0–0.5%\nLuxe：0–0.25%'), findsNothing);
    await tester.tap(find.byKey(const Key('detail-fee-外汇费')));
    await tester.pumpAndSettle();
    expect(find.text('Core：0–0.5%\nLuxe：0–0.25%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card detail keeps funding and availability in one compact row', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-card-redotpay'));
    final cardSize = tester.getSize(card);
    await tester.tapAt(
      tester.getTopLeft(card) + Offset(cardSize.width / 2, 20),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-basic-info')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('card-preview-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const Key('detail-funding-availability')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-region-more')), findsNothing);
    expect(find.byKey(const Key('detail-funding-more')), findsNothing);
    expect(find.byKey(const Key('detail-region-value')), findsOneWidget);
    expect(find.byKey(const Key('detail-funding-value')), findsOneWidget);
    final fundingLabel = tester.widget<Text>(find.text('入金方式'));
    expect(fundingLabel.style?.fontSize, 11.5);
    final regionValue = find.byKey(const Key('detail-region-value'));
    await tester.tapAt(tester.getTopLeft(regionValue) + const Offset(28, 28));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-full-value-sheet')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-full-value-sheet')),
        matching: find.text('按 RedotPay 开放地区'),
      ),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    final fundingValue = find.byKey(const Key('detail-funding-value'));
    await tester.tapAt(tester.getTopLeft(fundingValue) + const Offset(28, 28));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-full-value-sheet')),
        matching: find.text('平台账户余额'),
      ),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-payments')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('card-preview-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('detail-payment-applePay')), findsOneWidget);
    expect(find.byKey(const Key('detail-payment-googlePay')), findsOneWidget);
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

  testWidgets('two-finger vertical pan moves the full fan and keeps it down', (
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
    final originalTop = tester.getTopLeft(firstCard).dy;
    final lastCard = find.byKey(const Key('home-card-bybit-card'));
    final originalLastBottom = tester.getBottomLeft(lastCard).dy;
    final center = tester.getTopLeft(stack) + const Offset(195, 140);
    tester.binding.handlePointerEvent(
      PointerDownEvent(pointer: 21, position: center - const Offset(38, 0)),
    );
    tester.binding.handlePointerEvent(
      PointerDownEvent(pointer: 22, position: center + const Offset(38, 0)),
    );
    await tester.pump(const Duration(milliseconds: 160));
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 21,
        position: center + const Offset(-38, 3),
        delta: const Offset(0, 3),
      ),
    );
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 22,
        position: center + const Offset(38, 3),
        delta: const Offset(0, 3),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(firstCard).dy, closeTo(originalTop + 3, 2));

    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 21,
        position: center + const Offset(-38, 280),
        delta: const Offset(0, 274),
      ),
    );
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: 22,
        position: center + const Offset(38, 280),
        delta: const Offset(0, 274),
      ),
    );
    await tester.pump();

    final pannedTop = tester.getTopLeft(firstCard).dy;
    expect(pannedTop, closeTo(originalTop + 280, 2));
    final viewport = tester.getRect(find.byKey(const Key('home-fan-viewport')));
    expect(tester.getBottomLeft(lastCard).dy, greaterThan(viewport.bottom));
    expect(
      tester.getBottomLeft(lastCard).dy,
      closeTo(originalLastBottom + 280, 2),
    );

    tester.binding.handlePointerEvent(
      PointerUpEvent(pointer: 21, position: center + const Offset(-38, 280)),
    );
    tester.binding.handlePointerEvent(
      PointerUpEvent(pointer: 22, position: center + const Offset(38, 280)),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(firstCard).dy, closeTo(pannedTop, 2));
  });

  testWidgets(
    'fan edge fades leave floating header and navigation interactive',
    (tester) async {
      await tester.pumpWidget(const CardApp(proUnlocked: true));
      await tester.pumpAndSettle();

      for (final mode in const [
        (button: Key('home-mode-stack'), scene: Key('card-stack')),
        (button: Key('home-mode-focus'), scene: Key('home-focus-stack')),
      ]) {
        await tester.tap(find.byKey(const Key('home-mode-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(mode.button));
        await tester.pumpAndSettle();

        final fade = find.byKey(const Key('home-fan-edge-fade'));
        expect(fade, findsOneWidget);
        expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
        expect(
          find.ancestor(of: find.byKey(mode.scene), matching: fade),
          findsOneWidget,
        );
        for (final control in [
          find.byKey(const Key('home-title-toggle')),
          find.byKey(const Key('home-mode-button')),
          find.byKey(const Key('home-add-button')),
          find.byKey(const Key('nav-add')),
        ]) {
          expect(find.ancestor(of: control, matching: fade), findsNothing);
        }
        final sceneSize = tester.getSize(find.byKey(mode.scene));
        await tester.tap(find.byKey(const Key('home-title-toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nav-add')), findsNothing);
        expect(
          tester
              .widget<HomeCardSceneFade>(find.byType(HomeCardSceneFade))
              .navigationVisible,
          isFalse,
        );
        expect(tester.getSize(find.byKey(mode.scene)), sceneSize);
        await tester.tap(find.byKey(const Key('home-title-toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nav-add')), findsOneWidget);
      }
    },
  );

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

  testWidgets('reselecting the active ranking tab toggles screenshot mode', (
    tester,
  ) async {
    await tester.pumpWidget(CardApp(authRepository: _GuestAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-ranking')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('nav-市场')), findsNothing);
    expect(find.text('底部导航已隐藏，再次点击当前分栏恢复。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tab-ranking')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('nav-市场')), findsOneWidget);
    expect(find.text('底部导航已恢复。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('add navigation opens the local catalog', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-card-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog-card-etherfi-core')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-preview-page')), findsOneWidget);
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

  testWidgets('main navigation hides the outgoing page immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-市场')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pump();

    expect(
      tester
          .widget<Offstage>(
            find.byKey(
              const ValueKey('main-tab-offstage-1'),
              skipOffstage: false,
            ),
          )
          .offstage,
      isTrue,
    );
    expect(
      tester
          .widget<Offstage>(
            find.byKey(
              const ValueKey('main-tab-offstage-2'),
              skipOffstage: false,
            ),
          )
          .offstage,
      isFalse,
    );
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
    expect(find.byIcon(AppIcons.canvas), findsOneWidget);

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
        matching: find.byIcon(AppIcons.canvasPause),
      ),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('card-canvas-autoplay-button')),
        matching: find.byIcon(AppIcons.canvasPlay),
      ),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('card-canvas-autoplay-button')),
        matching: find.byIcon(AppIcons.canvasPlay),
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

    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-action-favorite')), findsNothing);
    expect(find.byKey(const Key('detail-effect-particle')), findsNothing);
    expect(find.byKey(const Key('detail-action-similar')), findsNothing);
    expect(find.byKey(const Key('detail-action-compare')), findsNothing);
    expect(find.byKey(const Key('detail-action-correction')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-remove')), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('detail-kyc')), findsNothing);
    expect(find.text('可申请 · 需验证'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-supported-currencies')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('detail-supported-currencies')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-currency-USD')), findsOneWidget);
    expect(find.byKey(const Key('detail-currency-EUR')), findsOneWidget);
    expect(find.text('🇺🇸'), findsOneWidget);
    final currencyGrid = tester.getSize(
      find.byKey(const Key('detail-currency-grid')),
    );
    expect(
      tester.getSize(find.byKey(const Key('detail-currency-USD'))).width,
      closeTo((currencyGrid.width - 24) / 4, .1),
    );
    expect(find.byKey(const Key('nav-市场')), findsNothing);
  });

  testWidgets('leading-edge swipe closes an AppShell overlay', (tester) async {
    await tester.pumpWidget(const CardApp(edgeSwipeBackEnabled: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-menu-settings')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('profile-page')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-menu-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-subpage-settings')), findsOneWidget);
    expect(find.byType(EdgeSwipeBack), findsOneWidget);
    expect(
      tester.widget<EdgeSwipeBack>(find.byType(EdgeSwipeBack)).enabled,
      isTrue,
    );

    final hitRegion = find.byKey(const Key('edge-swipe-back-hit-region'));
    final pageLeft = tester
        .getTopLeft(find.byKey(const Key('profile-subpage-settings')))
        .dx;
    final gesture = await tester.startGesture(tester.getCenter(hitRegion));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('profile-subpage-settings'))).dx,
      greaterThan(pageLeft + 250),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-subpage-settings')), findsNothing);
    expect(find.byKey(const Key('profile-menu-settings')), findsOneWidget);
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

  testWidgets(
    'guest card changes require login and do not create a collection',
    (tester) async {
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
      expect(find.byKey(const Key('login-page')), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'card-app-guest-state-v1',
        ),
        isNull,
      );
    },
  );

  testWidgets('guest favorites require login and are not stored', (
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
    expect(find.text('加入我的卡片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-favorite')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'card-app-guest-state-v1',
      ),
      isNull,
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
    final selectedRange = tester.widget<AnimatedContainer>(
      find.byKey(const Key('stablecoin-range-surface-90d')),
    );
    expect(
      (selectedRange.decoration! as BoxDecoration).color,
      const Color(0xFAFFFFFF),
    );
  });

  testWidgets('stablecoin Pro crowns stay above their range labels', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-排行')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-metrics')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('metrics-stablecoin-shortcut')));
    await tester.pumpAndSettle();

    _expectCrownAboveLabel(
      tester,
      controlKey: const Key('stablecoin-range-90d'),
      label: '90D',
    );
    _expectCrownAboveLabel(
      tester,
      controlKey: const Key('stablecoin-range-all'),
      label: 'All',
    );
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
    expect(find.text('关于 CardFi'), findsOneWidget);
    expect(find.text('信息来源与权利'), findsOneWidget);
    expect(find.text('更正与下架'), findsOneWidget);
    expect(find.textContaining('相关商标、图片和名称归其权利人所有'), findsOneWidget);
    expect(find.textContaining('核实后将及时更正或下架'), findsOneWidget);
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

  testWidgets(
    'guest settings expose public notifications and hide account tools',
    (tester) async {
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
      expect(
        find.byKey(const Key('settings-notification-permission')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-reminder-config')), findsOneWidget);
      expect(find.byKey(const Key('settings-feedback')), findsNothing);
      expect(find.byKey(const Key('settings-app-messages')), findsNothing);
      expect(find.byKey(const Key('settings-help')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-support')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      for (final key in const [
        Key('settings-privacy-policy'),
        Key('settings-terms-of-use'),
        Key('settings-account-deletion'),
        Key('settings-support'),
      ]) {
        expect(find.byKey(key), findsOneWidget);
      }

      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('settings-privacy-policy'))),
        alignment: .5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-privacy-policy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-subpage-privacy')), findsOneWidget);
      expect(find.text('我们处理哪些数据'), findsOneWidget);
      expect(find.text('你的权利'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-subpage-back')));
      await tester.pumpAndSettle();

      final hapticsSwitch = find.descendant(
        of: find.byKey(const Key('settings-haptics')),
        matching: find.byType(Switch),
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('settings-haptics'))),
        alignment: .5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
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
    },
  );

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
    for (final language in AppLanguage.releaseLanguages) {
      expect(
        find.byKey(Key('language-${language.storageKey}')),
        findsOneWidget,
      );
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

  testWidgets('guest settings do not expose the feedback form', (tester) async {
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
    expect(find.byKey(const Key('settings-feedback')), findsNothing);
    expect(find.byKey(const Key('settings-app-messages')), findsNothing);
    expect(find.byKey(const Key('settings-help')), findsOneWidget);
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
    SharedPreferences.setMockInitialValues({
      'card-app-language-v1': 'zh-CN',
      LocalGuestStateRepository.storageKeyForUser(
        'verified-user',
      ): '{"version":2,"addedCardIds":["redotpay"],"favoriteCardIds":[],"favoriteArticleIds":[],"recentCardIds":[],"submissions":[]}',
    });
    await tester.pumpWidget(
      const CardApp(authRepository: _SignedInAuthRepository()),
    );
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
    expect(find.byKey(const Key('detail-action-compare')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-watch')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-similar')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-official')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-correction')), findsOneWidget);
    expect(find.byKey(const Key('detail-action-remove')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-effects')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-effects-menu')), findsOneWidget);
    expect(find.byKey(const Key('detail-effect-particle')), findsOneWidget);
    expect(find.byKey(const Key('detail-effect-ice')), findsNothing);
    for (final effect in const ['fireworks', 'prism', 'supernova']) {
      final effectButton = find.byKey(Key('detail-effect-$effect'));
      expect(effectButton, findsOneWidget);
      expect(
        find.descendant(
          of: effectButton,
          matching: find.byKey(const Key('pro-crown-badge')),
        ),
        findsNothing,
      );
    }
    for (final effect in const [
      'shards',
      'scanReveal',
      'foldReveal',
      'photoEtch',
      'liquidCast',
      'bandAlign',
    ]) {
      expect(find.byKey(Key('detail-effect-$effect')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('detail-effect-shards')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveCardArtwork>(find.byType(InteractiveCardArtwork))
          .effect,
      CardVisualEffect.particle,
    );
    const freeEffects = [
      CardVisualEffect.fireworks,
      CardVisualEffect.prism,
      CardVisualEffect.supernova,
    ];
    for (var index = 0; index < freeEffects.length; index++) {
      final effect = freeEffects[index];
      if (index > 0) {
        await tester.tap(find.byKey(const Key('detail-effects')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.byKey(Key('detail-effect-${effect.name}')));
      await tester.pump();
      expect(
        tester
            .widget<InteractiveCardArtwork>(find.byType(InteractiveCardArtwork))
            .effect,
        effect,
      );
    }
    await tester.tap(find.byKey(const Key('detail-effects')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('detail-effect-flame')));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'card-app-card-visual-effect-v1',
      ),
      CardVisualEffect.flame.name,
    );
    expect(find.byKey(const Key('detail-action-favorite')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-action-similar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-page')), findsOneWidget);
    expect(find.byKey(const Key('card-preview-page')), findsNothing);
  });

  testWidgets('card visual effect is reused by later card details', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final redotpay = find.byKey(const Key('home-card-redotpay'));
    final redotpaySize = tester.getSize(redotpay);
    await tester.tapAt(
      tester.getTopLeft(redotpay) + Offset(redotpaySize.width / 2, 20),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-effects')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-effect-flame')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-back')));
    await tester.pumpAndSettle();

    final etherfi = find.byKey(const Key('home-card-etherfi-core'));
    final etherfiSize = tester.getSize(etherfi);
    await tester.tapAt(
      tester.getTopLeft(etherfi) + Offset(etherfiSize.width / 2, 20),
    );
    await tester.pumpAndSettle();

    final artwork = tester.widget<InteractiveCardArtwork>(
      find.byType(InteractiveCardArtwork),
    );
    expect(artwork.effect, CardVisualEffect.flame);
  });

  testWidgets('scrolling away from card artwork does not replay its effect', (
    tester,
  ) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-card-redotpay'));
    final cardSize = tester.getSize(card);
    await tester.tapAt(
      tester.getTopLeft(card) + Offset(cardSize.width / 2, 20),
    );
    await tester.pumpAndSettle();

    final artwork = find.byType(InteractiveCardArtwork);
    final stateBeforeScroll = tester.state<State>(artwork);
    final detailScroll = find.byType(ListView).first;
    await tester.fling(detailScroll, const Offset(0, -1800), 3000);
    await tester.pumpAndSettle();
    await tester.fling(detailScroll, const Offset(0, 1800), 3000);
    await tester.pumpAndSettle();

    expect(tester.state<State>(artwork), same(stateBeforeScroll));
  });

  testWidgets('Pro users can select all card visual effects', (tester) async {
    await tester.pumpWidget(const CardApp(proUnlocked: true));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('home-card-redotpay'));
    final cardSize = tester.getSize(card);
    await tester.tapAt(
      tester.getTopLeft(card) + Offset(cardSize.width / 2, 20),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-effects')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('detail-effects-menu')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsNWidgets(9),
    );

    for (final effect in const ['fireworks', 'prism', 'supernova']) {
      expect(find.byKey(Key('detail-effect-$effect')), findsOneWidget);
    }
    for (final effect in const ['magnetic', 'liquidMetal', 'spaceFold']) {
      expect(find.byKey(Key('detail-effect-$effect')), findsOneWidget);
    }
    for (final effect in const [
      'shards',
      'scanReveal',
      'foldReveal',
      'photoEtch',
      'liquidCast',
      'bandAlign',
    ]) {
      expect(find.byKey(Key('detail-effect-$effect')), findsOneWidget);
    }
    expect(find.byKey(const Key('detail-effect-orbit')), findsNothing);
    await tester.tap(find.byKey(const Key('detail-effect-bandAlign')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveCardArtwork>(find.byType(InteractiveCardArtwork))
          .effect,
      CardVisualEffect.bandAlign,
    );
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
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, const Duration(milliseconds: 80));
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

void _expectCrownAboveLabel(
  WidgetTester tester, {
  required Key controlKey,
  required String label,
}) {
  final control = find.byKey(controlKey);
  final crown = find.descendant(
    of: control,
    matching: find.byKey(const Key('pro-crown-badge')),
  );
  final text = find.descendant(of: control, matching: find.text(label));
  expect(crown, findsOneWidget);
  expect(text, findsOneWidget);
  expect(tester.getBottomLeft(crown).dy, lessThan(tester.getTopLeft(text).dy));
}

void _noop() {}

void _ignoreCard(CardSummary _) {}

class _FailingRepository implements CardCatalogRepository {
  const _FailingRepository();

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) =>
      Future.error(Exception('offline'));
}

class CardApp extends app.CardApp {
  const CardApp({
    super.enableRemoteData,
    super.proUnlocked,
    super.catalogRepository,
    super.edgeSwipeBackEnabled,
    AuthRepository? authRepository,
    super.key,
  }) : super(authRepository: authRepository ?? const _GuestAuthRepository());
}

class _GuestAuthRepository implements AuthRepository {
  const _GuestAuthRepository();

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

class _VerifiedAuthRepository
    implements AuthRepository, PasswordlessAuthRepository {
  const _VerifiedAuthRepository();

  @override
  bool get configured => true;

  @override
  bool get appleConfigured => false;

  @override
  bool get googleConfigured => false;

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<AuthUser> verifyEmailOtp({
    required String email,
    required String token,
  }) => Future.value(_user(email));

  @override
  Future<AuthUser> signInWithApple() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> signInWithGoogle() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> linkAppleIdentity() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser> linkGoogleIdentity() =>
      Future.error(const AuthFailure('UNAVAILABLE', 'Unavailable in test'));

  @override
  Future<AuthUser?> initialize() async => null;

  @override
  Future<String?> idToken() async => 'test-access-token';

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => Future.value(_user(email));

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
      Future.value(_user(email));

  @override
  Future<AuthUser> updateDisplayName(String displayName) =>
      Future.value(_user('member@example.com'));

  static AuthUser _user(String email) => AuthUser(
    id: 'verified-user',
    email: email,
    displayName: null,
    emailVerified: true,
  );
}

class _SignedInAuthRepository extends _VerifiedAuthRepository {
  const _SignedInAuthRepository();

  @override
  Future<AuthUser?> initialize() =>
      Future.value(_VerifiedAuthRepository._user('member@example.com'));
}
