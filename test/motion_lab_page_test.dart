import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/debug/presentation/motion_lab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('motion lab exposes both reusable success effects', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: MotionLabPage(onBack: () {})),
        ),
      ),
    );

    expect(find.byKey(const Key('motion-lab-page')), findsOneWidget);
    expect(find.byKey(const Key('motion-lab-card-burst')), findsOneWidget);
    expect(find.byKey(const Key('motion-lab-pro-gift')), findsOneWidget);

    await tester.tap(find.text('播放爆卡效果'));
    await tester.tap(find.text('播放礼包效果'));
    expect(tester.takeException(), isNull);
  });
}
