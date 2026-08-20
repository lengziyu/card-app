import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/shell/widgets/animated_glass_segment.dart';
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

  testWidgets('primary tabs distinguish selection from reselection', (
    tester,
  ) async {
    var selected = 0;
    var reselectionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) => AnimatedGlassSegment<int>(
                  items: const [
                    GlassSegmentItem(
                      value: 0,
                      label: '热门榜',
                      key: Key('tab-ranking'),
                    ),
                    GlassSegmentItem(
                      value: 1,
                      label: '卡友榜',
                      key: Key('tab-users'),
                    ),
                  ],
                  selected: selected,
                  onChanged: (value) => setState(() => selected = value),
                  onReselected: (_) => reselectionCount++,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tab-users')));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(reselectionCount, 0);

    await tester.tap(find.byKey(const Key('tab-users')));
    await tester.pump();
    expect(selected, 1);
    expect(reselectionCount, 1);
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
