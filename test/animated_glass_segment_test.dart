import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/shell/widgets/animated_glass_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light primary tabs use a visible borderless track', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AnimatedGlassSegment<int>(
                items: const [
                  GlassSegmentItem(value: 0, label: 'U卡'),
                  GlassSegmentItem(value: 1, label: '其他'),
                ],
                selected: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const Key('animated-glass-segment-surface')),
    );
    final indicator = tester.widget<DecoratedBox>(
      find.byKey(const Key('animated-glass-segment-indicator')),
    );
    final surfaceDecoration = surface.decoration! as BoxDecoration;
    expect(surfaceDecoration.border, isNull);
    expect(surfaceDecoration.color, const Color(0x247382A8));
    expect((surfaceDecoration.gradient! as LinearGradient).colors, const [
      Color(0x2C8B9AC0),
      Color(0x18798AAD),
    ]);
    expect((indicator.decoration as BoxDecoration).border, isNull);
  });

  testWidgets('light secondary tabs have layered floating shadows', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AnimatedPillSegment<int>(
                items: const [
                  GlassSegmentItem(value: 0, label: '全部', key: Key('pill-all')),
                  GlassSegmentItem(value: 1, label: '上新'),
                ],
                selected: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final pill = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('pill-all')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final shadows = (pill.decoration! as BoxDecoration).boxShadow!;
    expect(shadows, hasLength(2));
    expect(shadows.first.blurRadius, 24);
    expect(shadows.first.offset, const Offset(0, 9));
  });
}
