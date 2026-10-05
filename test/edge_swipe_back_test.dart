import 'package:cardfi/core/motion/edge_swipe_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject({
    required VoidCallback onBack,
    bool enabled = true,
    bool followGesture = true,
    Widget? child,
  }) => MaterialApp(
    home: EdgeSwipeBack(
      enabled: enabled,
      followGesture: followGesture,
      onBack: onBack,
      child: child ?? const ColoredBox(key: Key('page'), color: Colors.blue),
    ),
  );

  testWidgets('commits a right drag that starts at the leading edge', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(subject(onBack: () => backCount++));

    await tester.dragFrom(
      const Offset(8, 300),
      const Offset(280, 0),
      touchSlopX: 0,
    );
    await tester.pumpAndSettle();

    expect(backCount, 1);
  });

  testWidgets('short edge drag follows the finger and then rebounds', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(subject(onBack: () => backCount++));
    final initialLeft = tester.getTopLeft(find.byKey(const Key('page'))).dx;
    final gesture = await tester.startGesture(const Offset(8, 300));

    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('page'))).dx,
      greaterThan(80),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(backCount, 0);
    expect(tester.getTopLeft(find.byKey(const Key('page'))).dx, initialLeft);
  });

  testWidgets('a horizontal drag in page content is not stolen', (
    tester,
  ) async {
    var backCount = 0;
    var contentDragCount = 0;
    await tester.pumpWidget(
      subject(
        onBack: () => backCount++,
        child: GestureDetector(
          key: const Key('horizontal-content'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (_) => contentDragCount++,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    );

    await tester.dragFrom(
      const Offset(200, 300),
      const Offset(280, 0),
      touchSlopX: 0,
    );
    await tester.pumpAndSettle();

    expect(backCount, 0);
    expect(contentDragCount, 1);
  });

  testWidgets('disabled edge swipe leaves the page untouched', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(subject(enabled: false, onBack: () => backCount++));

    await tester.dragFrom(
      const Offset(8, 300),
      const Offset(300, 0),
      touchSlopX: 0,
    );
    await tester.pumpAndSettle();

    expect(backCount, 0);
    expect(tester.getTopLeft(find.byKey(const Key('page'))).dx, 0);
  });

  testWidgets('vertical movement at the edge does not navigate back', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(subject(onBack: () => backCount++));

    await tester.dragFrom(
      const Offset(8, 180),
      const Offset(0, 260),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();

    expect(backCount, 0);
    expect(tester.getTopLeft(find.byKey(const Key('page'))).dx, 0);
  });

  testWidgets('leftward movement at the edge does not navigate back', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(subject(onBack: () => backCount++));

    await tester.dragFrom(
      const Offset(18, 300),
      const Offset(-16, 0),
      touchSlopX: 0,
    );
    await tester.pumpAndSettle();

    expect(backCount, 0);
    expect(tester.getTopLeft(find.byKey(const Key('page'))).dx, 0);
  });

  testWidgets('non-following mode delegates the final reverse animation', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      subject(followGesture: false, onBack: () => backCount++),
    );
    final gesture = await tester.startGesture(const Offset(8, 300));

    await gesture.moveBy(const Offset(280, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('page'))).dx, 0);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(backCount, 1);
  });
}
