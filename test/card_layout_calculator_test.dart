import 'package:card_app/features/home/controllers/card_stack_controller.dart';
import 'package:card_app/features/home/domain/card_layout_calculator.dart';
import 'package:card_app/features/home/domain/card_stack_mode.dart';
import 'package:card_app/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screenSize = Size(390, 620);
  const cardSize = Size(354, 354 / CardLayoutCalculator.cardAspectRatio);

  test('stack mode keeps a middle card full in an expanded vertical deck', () {
    final preferredHeight = CardLayoutCalculator.preferredHeight(
      mode: CardStackMode.stack,
      availableHeight: screenSize.height,
      cardHeight: cardSize.height,
      itemCount: 6,
      selectedIndex: 2,
    );
    final states = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: 2,
      dragOffset: 0,
      screenSize: Size(screenSize.width, preferredHeight),
      cardSize: cardSize,
      itemCount: 6,
    );

    expect(states, hasLength(6));
    expect(states[2].scale, 1);
    expect(states[2].opacity, 1);
    expect(states[2].zIndex, greaterThan(states[1].zIndex));
    expect(states[2].zIndex, greaterThan(states[3].zIndex));
    expect(states[1].zIndex, greaterThan(states[0].zIndex));
    expect(states[3].zIndex, greaterThan(states[4].zIndex));
    expect(states[4].zIndex, greaterThan(states[5].zIndex));
    expect(states[1].top, lessThan(states[2].top));
    expect(states[1].left, isNot(states[2].left));
    expect(states[1].rotation.abs(), lessThanOrEqualTo(.012));
    expect(states[1].rotation, isNot(0));
    expect(states.every((state) => state.opacity == 1), isTrue);
    expect(states[0].scale, lessThan(states[1].scale));
    expect(states[3].top - states[2].top, inInclusiveRange(46, 68));
    expect(states[3].top, lessThan(states[2].top + cardSize.height));
    expect(states[4].top - states[3].top, inInclusiveRange(46, 68));
    for (var index = 1; index < states.length; index++) {
      expect(
        states[index].top - states[index - 1].top,
        inInclusiveRange(46, 68),
        reason: 'stack card $index must stay on the compact reveal track',
      );
    }
    expect(states.last.top, greaterThanOrEqualTo(0));
    expect(states.last.top + cardSize.height, lessThan(preferredHeight));
  });

  test('focus mode keeps the selected card full and reacts during drag', () {
    final resting = CardLayoutCalculator.calculate(
      mode: CardStackMode.focus,
      selectedIndex: 2,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    final dragging = CardLayoutCalculator.calculate(
      mode: CardStackMode.focus,
      selectedIndex: 2,
      dragOffset: -64,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );

    expect(resting[2].scale, 1);
    expect(resting[2].zIndex, greaterThan(resting[1].zIndex));
    expect(resting[2].zIndex, greaterThan(resting[3].zIndex));
    expect(resting[1].zIndex, greaterThan(resting[0].zIndex));
    expect(resting[3].zIndex, greaterThan(resting[4].zIndex));
    expect(resting[4].zIndex, greaterThan(resting[5].zIndex));
    expect(
      (resting[2].top + cardSize.height / 2 - screenSize.height / 2).abs(),
      lessThanOrEqualTo(40),
    );
    expect(resting[0].top, greaterThanOrEqualTo(20));
    expect(resting[1].top, lessThan(resting[2].top));
    expect(
      resting[2].top + cardSize.height - resting[3].top,
      inInclusiveRange(88, 122),
    );
    expect(resting[1].scale, lessThan(resting[2].scale));
    expect(resting[0].scale, lessThan(resting[1].scale));
    expect(resting[1].opacity, 1);
    expect(resting[0].opacity, 1);
    expect(resting[3].top, lessThan(resting[2].top + cardSize.height));
    expect(resting[4].top - resting[3].top, inInclusiveRange(88, 122));
    expect(dragging[2].top, resting[2].top - 64);
    expect(dragging[3].top, lessThan(resting[3].top));
  });

  test('expanded modes stay inside an iPhone-width viewport', () {
    for (final mode in [CardStackMode.stack, CardStackMode.focus]) {
      final states = CardLayoutCalculator.calculate(
        mode: mode,
        selectedIndex: 2,
        dragOffset: 0,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: 6,
      );

      for (final state in states) {
        expect(state.left, greaterThanOrEqualTo(12));
        expect(
          state.left + cardSize.width,
          lessThanOrEqualTo(screenSize.width - 12),
        );
        expect(state.rotation.abs(), lessThanOrEqualTo(.012));
      }
    }
  });

  test('focus spacing is visibly wider than compact stack spacing', () {
    final stack = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: 2,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    final focus = CardLayoutCalculator.calculate(
      mode: CardStackMode.focus,
      selectedIndex: 2,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    final stackReveal = stack[1].top - stack[0].top;
    final focusReveal = focus[1].top - focus[0].top;

    expect(focusReveal, greaterThan(stackReveal * 1.6));
    expect(focus[2].top, greaterThan(stack[2].top));
    expect(focus.every((state) => state.rotation == 0), isTrue);
  });

  test('wallet mode starts fully collapsed with only card headers visible', () {
    final states = CardLayoutCalculator.calculate(
      mode: CardStackMode.wallet,
      selectedIndex: -1,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );

    expect(states.first.scale, 1);
    for (var index = 1; index < states.length; index++) {
      final reveal = states[index].top - states[index - 1].top;
      expect(reveal, lessThan(cardSize.height / 2));
      expect(states[index].zIndex, greaterThan(states[index - 1].zIndex));
    }
  });

  test('transform interpolation includes every animated surface', () {
    const begin = CardTransformState(
      top: 0,
      left: 4,
      scale: .9,
      opacity: .6,
      rotation: -.02,
      elevation: 8,
      zIndex: 1,
    );
    const end = CardTransformState(
      top: 100,
      left: 8,
      scale: 1,
      opacity: 1,
      rotation: .02,
      elevation: 28,
      zIndex: 5,
    );

    final middle = CardTransformState.lerp(begin, end, .5);

    expect(middle.top, 50);
    expect(middle.left, 6);
    expect(middle.scale, .95);
    expect(middle.opacity, .8);
    expect(middle.rotation, 0);
    expect(middle.elevation, 18);
    expect(middle.zIndex, 3);
  });

  test(
    'wallet reorder moves the dragged card through the controller order',
    () {
      final controller = CardStackController(
        vsync: const TestVSync(),
        cardIds: const ['a', 'b', 'c', 'd'],
        initialMode: CardStackMode.wallet,
      );
      addTearDown(controller.dispose);
      controller.configureLayout(screenSize: screenSize, cardSize: cardSize);

      final originTop = controller.transformFor('a').top;
      expect(controller.startWalletReorder('a'), isTrue);
      final changed = controller.updateWalletReorder(140);

      expect(changed, isTrue);
      expect(controller.cardIds.first, isNot('a'));
      expect(controller.cardIds, contains('a'));
      expect(controller.transformFor('a').top, originTop + 140);

      controller.updateWalletReorder(150);
      expect(
        controller.transformFor('a').top,
        originTop + 150,
        reason: 'cumulative pointer movement must not be added to a new slot',
      );
      expect(controller.endWalletReorder(), controller.cardIds);
    },
  );

  test('stack and focus default to the true middle card', () {
    for (final mode in [CardStackMode.stack, CardStackMode.focus]) {
      final controller = CardStackController(
        vsync: const TestVSync(),
        cardIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
        initialMode: mode,
      );
      addTearDown(controller.dispose);

      expect(controller.selectedId, 'd');
      expect(controller.selectedIndex, 3);
    }
  });
}
