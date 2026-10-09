import 'package:cardfi/features/home/controllers/card_stack_controller.dart';
import 'package:cardfi/features/home/domain/card_layout_calculator.dart';
import 'package:cardfi/features/home/domain/card_stack_mode.dart';
import 'package:cardfi/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
const _viewport = Size(390, 620);
const _card = Size(350, 350 / CardLayoutCalculator.cardAspectRatio);

CardStackController _controller(CardStackMode mode) {
  final controller = CardStackController(
    vsync: const TestVSync(),
    cardIds: _ids,
    initialMode: mode,
  );
  controller.configureLayout(screenSize: _viewport, cardSize: _card);
  addTearDown(controller.dispose);
  return controller;
}

void _expectSameSurface(
  CardTransformState actual,
  CardTransformState expected,
) {
  expect(actual.top, closeTo(expected.top, .001));
  expect(actual.scale, closeTo(expected.scale, .001));
  expect(actual.focusDepth, closeTo(expected.focusDepth, .001));
  expect(actual.zIndex, expected.zIndex);
}

void main() {
  test('fan rear cards extend beyond the scene while the active card fits', () {
    for (final mode in [CardStackMode.stack, CardStackMode.focus]) {
      for (final viewportHeight in [280.0, 620.0]) {
        final cardHeight = viewportHeight == 280 ? 120.0 : _card.height;
        final cardSize = Size(
          cardHeight * CardLayoutCalculator.cardAspectRatio,
          cardHeight,
        );
        for (final count in [1, 9, 40]) {
          for (final selected in [0, count ~/ 2, count - 1]) {
            for (final fraction in [-.4, 0.0, .25, .5, .75, 1.0]) {
              final states = CardLayoutCalculator.calculate(
                mode: mode,
                selectedIndex: selected,
                dragOffset: -cardHeight * fraction,
                screenSize: Size(390, viewportHeight),
                cardSize: cardSize,
                itemCount: count,
              );
              final nearest = (selected + fraction).round().clamp(0, count - 1);
              final active = states[nearest];
              expect(active.top, greaterThanOrEqualTo(0));
              expect(
                active.top + cardHeight * active.scale,
                lessThanOrEqualTo(viewportHeight),
              );
              if (count >= 9 && selected == count ~/ 2) {
                expect(states.first.top, lessThan(0));
                expect(
                  states.last.top + cardHeight * states.last.scale,
                  greaterThan(viewportHeight),
                );
              }
            }
          }
        }
      }
    }
  });

  test(
    'two-finger scene offsets translate the fan without edge compression',
    () {
      for (final mode in [CardStackMode.stack, CardStackMode.focus]) {
        final origin = CardLayoutCalculator.calculate(
          mode: mode,
          selectedIndex: 3,
          dragOffset: 0,
          screenSize: _viewport,
          cardSize: _card,
          itemCount: _ids.length,
        );
        for (final offset in [-400.0, 400.0]) {
          final panned = CardLayoutCalculator.calculate(
            mode: mode,
            selectedIndex: 3,
            dragOffset: 0,
            screenSize: _viewport,
            cardSize: _card,
            itemCount: _ids.length,
            sceneOffset: offset,
          );
          for (var index = 0; index < _ids.length; index++) {
            expect(
              panned[index].top,
              closeTo(origin[index].top + offset, .001),
            );
            expect(panned[index].scale, origin[index].scale);
          }
        }
      }
    },
  );

  testWidgets(
    'opening a collapsed stack can be dragged and released without a jump',
    (tester) async {
      final controller = _controller(CardStackMode.stack);
      controller.selectCard('e');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final before = controller.transformFor('e');
      controller.startDrag();
      _expectSameSurface(controller.transformFor('e'), before);
      controller.updateDrag(-2);
      final moving = controller.transformFor('e');
      expect((moving.top - before.top).abs(), lessThan(8));
      controller.endDrag(velocity: 0);
      _expectSameSurface(controller.transformFor('e'), moving);
      await tester.pumpAndSettle();
    },
  );

  test(
    'focus cards separate before swapping layers and keep a continuous path',
    () {
      final step = CardLayoutCalculator.dragStep(
        mode: CardStackMode.focus,
        cardSize: _card,
      );
      CardTransformState? previousUpper;
      CardTransformState? previousLower;
      var swaps = 0;
      for (var sample = 0; sample <= 100; sample++) {
        final states = CardLayoutCalculator.calculate(
          mode: CardStackMode.focus,
          selectedIndex: 3,
          dragOffset: -step * sample / 100,
          screenSize: _viewport,
          cardSize: _card,
          itemCount: _ids.length,
        );
        final upper = states[3];
        final lower = states[4];
        if (previousUpper != null && previousLower != null) {
          expect((upper.top - previousUpper.top).abs(), lessThan(4));
          expect((lower.top - previousLower.top).abs(), lessThan(4));
          if (upper.zIndex < lower.zIndex &&
              previousUpper.zIndex > previousLower.zIndex) {
            expect(upper.top + _card.height * upper.scale, lessThan(lower.top));
            expect(
              previousUpper.top + _card.height * previousUpper.scale,
              lessThan(previousLower.top),
            );
            swaps++;
          }
        }
        previousUpper = upper;
        previousLower = lower;
      }
      expect(swaps, 1);
    },
  );

  test('default focus drag follows the finger in both directions', () {
    final controller = _controller(CardStackMode.focus);
    final top = controller.transformFor('d').top;
    controller.startDrag();
    controller.updateDrag(-28);
    expect(controller.transformFor('d').top, closeTo(top - 28, .001));
    controller.updateDrag(56);
    expect(controller.transformFor('d').top, closeTo(top + 28, .001));
  });

  testWidgets('clicking a distant card does not paint its final order early', (
    tester,
  ) async {
    final controller = _controller(CardStackMode.focus);
    final before = controller.transformFor('d');
    expect(controller.paintOrder.last, 'd');
    controller.selectCard('g');
    expect(controller.selectedId, 'g');
    expect(controller.visualSelectedId, 'd');
    expect(controller.paintOrder.last, 'd');
    _expectSameSurface(controller.transformFor('d'), before);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(controller.visualPosition, greaterThan(3));
    expect(controller.visualPosition, lessThan(6));
    expect(controller.paintOrder.last, controller.visualSelectedId);
    await tester.pumpAndSettle();
    expect(controller.paintOrder.last, 'g');
    expect(controller.transformFor('g').focusDepth, 0);
  });

  for (final mode in [CardStackMode.focus, CardStackMode.stack]) {
    testWidgets('$mode card tap resets an unfinished drag before settling', (
      tester,
    ) async {
      final controller = _controller(mode);
      if (mode == CardStackMode.stack) {
        controller.selectCard('d');
        await tester.pumpAndSettle();
      }
      controller.startDrag();
      controller.updateDrag(-38);
      final before = controller.transformFor('e');
      controller.selectCard('e');
      _expectSameSurface(controller.transformFor('e'), before);
      expect(controller.dragOffset, 0);
      await tester.pumpAndSettle();
      expect(controller.visualPosition, 4);
      _expectSameSurface(
        controller.transformFor('e'),
        controller.targetTransformFor('e')!,
      );
    });

    testWidgets('$mode click animation can be taken over without a jump', (
      tester,
    ) async {
      final controller = _controller(mode);
      if (mode == CardStackMode.stack) {
        controller.selectCard('d');
        await tester.pumpAndSettle();
      }
      controller.selectCard('g');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final surfaces = {for (final id in _ids) id: controller.transformFor(id)};
      final position = controller.visualPosition;
      controller.startDrag();
      expect(controller.visualPosition, closeTo(position, .001));
      for (final id in _ids) {
        _expectSameSurface(controller.transformFor(id), surfaces[id]!);
      }
      controller.updateDrag(-2);
      for (final id in _ids) {
        expect(
          (controller.transformFor(id).top - surfaces[id]!.top).abs(),
          lessThan(4),
        );
      }
      controller.endDrag(velocity: 0);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('cancelled focus drag returns along the same path', (
    tester,
  ) async {
    final controller = _controller(CardStackMode.focus);
    controller.startDrag();
    controller.updateDrag(-36);
    final before = controller.transformFor('e');
    controller.cancelDrag();
    _expectSameSurface(controller.transformFor('e'), before);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final position = controller.visualPosition;
    final expected = CardLayoutCalculator.calculate(
      mode: CardStackMode.focus,
      selectedIndex: 3,
      dragOffset:
          (3 - position) *
          CardLayoutCalculator.dragStep(
            mode: CardStackMode.focus,
            cardSize: _card,
          ),
      screenSize: _viewport,
      cardSize: _card,
      itemCount: _ids.length,
    );
    _expectSameSurface(controller.transformFor('e'), expected[4]);
    await tester.pumpAndSettle();
    expect(controller.visualSelectedId, 'd');
  });

  testWidgets('short slow drags return and a deliberate fling can skip cards', (
    tester,
  ) async {
    final controller = _controller(CardStackMode.focus);
    controller.startDrag();
    controller.updateDrag(-20);
    expect(controller.endDrag(velocity: -120), 3);
    await tester.pumpAndSettle();
    controller.startDrag();
    controller.updateDrag(-20);
    expect(controller.endDrag(velocity: -3600), greaterThan(4));
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion stops a pending animation at the selected card', (
    tester,
  ) async {
    final controller = _controller(CardStackMode.focus);
    controller.selectCard('g');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    controller.setReduceMotion(true);
    controller.selectCard('a');
    expect(controller.isAnimating, isFalse);
    expect(controller.visualPosition, 0);
    expect(controller.paintOrder.last, 'a');
    expect(controller.transformFor('a').focusDepth, 0);
  });
}
