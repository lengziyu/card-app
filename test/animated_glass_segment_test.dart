import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/shell/widgets/animated_glass_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light primary tabs use borderless H5 surfaces', (tester) async {
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
    expect((surface.decoration! as BoxDecoration).border, isNull);
    expect((indicator.decoration as BoxDecoration).border, isNull);
  });
}
