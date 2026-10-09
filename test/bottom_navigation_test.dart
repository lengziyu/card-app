import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/shell/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses Phosphor regular and fill icons for navigation state', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(selectedIndex: 0));

    expect(
      _navigationIcon(tester, '我的卡片').icon!.fontFamily,
      AppIcons.cardsSelected.fontFamily,
    );
    expect(
      _navigationIcon(tester, '市场').icon!.fontFamily,
      AppIcons.market.fontFamily,
    );
    expect(
      _navigationIcon(tester, '排行').icon!.fontFamily,
      AppIcons.ranking.fontFamily,
    );
    expect(
      _navigationIcon(tester, '我的').icon!.fontFamily,
      AppIcons.profile.fontFamily,
    );

    await tester.pumpWidget(_testApp(selectedIndex: 1));
    await tester.pumpAndSettle();

    expect(
      _navigationIcon(tester, '我的卡片').icon!.fontFamily,
      AppIcons.cards.fontFamily,
    );
    expect(
      _navigationIcon(tester, '市场').icon!.fontFamily,
      AppIcons.marketSelected.fontFamily,
    );
  });

  testWidgets('hands off navigation icons during a destination change', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(selectedIndex: 0));
    await tester.pumpWidget(_testApp(selectedIndex: 1));
    await tester.pump(const Duration(milliseconds: 180));

    expect(_navigationIcons('我的卡片'), findsNWidgets(2));
    expect(_navigationIcons('市场'), findsNWidgets(2));

    await tester.pumpAndSettle();

    expect(_navigationIcons('我的卡片'), findsOneWidget);
    expect(_navigationIcons('市场'), findsOneWidget);
  });

  testWidgets('bill shortcut is available without a Pro crown', (tester) async {
    await tester.pumpWidget(_testApp(selectedIndex: 0));
    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('nav-quick-bill')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsNothing,
    );
  });

  testWidgets('quick menu reverses in place and only runs the tapped action', (
    tester,
  ) async {
    var bills = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _testApp(selectedIndex: 0, onAnalyzeBill: () => bills++),
    );
    final toggle = find.byKey(const Key('nav-add'));
    final shortcut = find.byKey(const Key('nav-quick-bill'));
    expect(find.semantics.byLabel('拍照识别账单'), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final openingPosition = tester.getCenter(shortcut);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getCenter(shortcut), openingPosition);
    expect(find.semantics.byLabel('拍照识别账单'), findsNothing);
    await tester.pump(const Duration(milliseconds: 40));
    final closingPosition = tester.getCenter(shortcut);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getCenter(shortcut), closingPosition);
    await tester.pumpAndSettle();

    expect(find.semantics.byLabel('拍照识别账单'), findsWidgets);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(bills, 1);
    expect(find.semantics.byLabel('拍照识别账单'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion keeps shortcuts usable and hidden when closed', (
    tester,
  ) async {
    var additions = 0;
    await tester.pumpWidget(
      _testApp(selectedIndex: 0, reduceMotion: true, onAdd: () => additions++),
    );
    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('nav-quick-add-card')));
    await tester.pump();
    expect(additions, 1);
    final shortcut = find.byKey(const Key('nav-quick-add-card'));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: shortcut, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark navigation keeps every primary icon white', (tester) async {
    AppColors.configure(Brightness.dark);
    addTearDown(() => AppColors.configure(Brightness.light));

    await tester.pumpWidget(_testApp(selectedIndex: 0));

    for (final label in const ['我的卡片', '市场', '排行', '我的']) {
      expect(_navigationIcon(tester, label).color, Colors.white);
    }

    final surface = tester.widget<Container>(
      find.byKey(const Key('bottom-navigation-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first.a, greaterThan(.6));
  });
}

Icon _navigationIcon(WidgetTester tester, String label) {
  return tester.widget<Icon>(_navigationIcons(label));
}

Finder _navigationIcons(String label) {
  return find.descendant(
    of: find.byKey(Key('nav-$label')),
    matching: find.byType(Icon),
  );
}

Widget _testApp({
  required int selectedIndex,
  bool reduceMotion = false,
  VoidCallback? onAdd,
  VoidCallback? onAnalyzeBill,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      bottomNavigationBar: BottomNavigation(
        selectedIndex: selectedIndex,
        addSelected: false,
        onDestinationSelected: (_) {},
        onAdd: onAdd ?? () {},
        onAnalyzeBill: onAnalyzeBill ?? () {},
      ),
    ),
  );
}
