import 'package:card_app/app/card_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the card collection home', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(find.text('EtherFi Cash'), findsOneWidget);
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

    expect(find.text('还没有收藏的卡片'), findsOneWidget);
  });

  testWidgets('every primary navigation destination responds', (tester) async {
    await tester.pumpWidget(const CardApp());
    await tester.pumpAndSettle();

    for (final destination in const {
      '市场': '市场',
      '排行': '排行榜',
      '我的': '我的',
    }.entries) {
      await tester.tap(find.byKey(Key('nav-${destination.key}')));
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
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
}
