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

  testWidgets('bill shortcut carries its Pro crown', (tester) async {
    await tester.pumpWidget(_testApp(selectedIndex: 0));
    await tester.tap(find.byKey(const Key('nav-add')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('nav-quick-bill')),
        matching: find.byKey(const Key('pro-crown-badge')),
      ),
      findsOneWidget,
    );
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

Widget _testApp({required int selectedIndex}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: BottomNavigation(
        selectedIndex: selectedIndex,
        addSelected: false,
        onDestinationSelected: (_) {},
        onAdd: () {},
        onAnalyzeBill: () {},
      ),
    ),
  );
}
