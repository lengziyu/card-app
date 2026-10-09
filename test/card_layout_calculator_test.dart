import 'package:cardfi/features/home/controllers/card_stack_controller.dart';
import 'package:cardfi/features/home/domain/card_layout_calculator.dart';
import 'package:cardfi/features/home/domain/card_stack_mode.dart';
import 'package:cardfi/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screenSize = Size(390, 620);
  const cardSize = Size(354, 354 / CardLayoutCalculator.cardAspectRatio);

  test('stack mode starts collapsed with only card headers visible', () {
    final states = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: -1,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );

    expect(states, hasLength(6));
    expect(states.every((state) => state.scale == 1), isTrue);
    for (var index = 1; index < states.length; index++) {
      final reveal = states[index].top - states[index - 1].top;
      expect(reveal, inInclusiveRange(58, 112));
      expect(states[index].zIndex, greaterThan(states[index - 1].zIndex));
    }
    expect(
      states[3].top - states[2].top,
      lessThan(cardSize.height / 2),
      reason: 'collapsed stack keeps compact header spacing',
    );
  });

  test('stack mode fans full-colour cards with the selected one expanded', () {
    final preferredHeight = CardLayoutCalculator.preferredHeight(
      mode: CardStackMode.stack,
      availableHeight: screenSize.height,
      cardHeight: cardSize.height,
      itemCount: 6,
      selectedIndex: 2,
    );
    expect(preferredHeight, screenSize.height);

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
    expect(states[1].scale, lessThan(states[2].scale));
    expect(states[3].scale, states[1].scale);
    expect(states.every((state) => state.focusDepth == 0), isTrue);
    expect(states.every((state) => state.opacity == 1), isTrue);
    expect(states.every((state) => state.left == states.first.left), isTrue);
    expect(states[2].zIndex, greaterThan(states[1].zIndex));
    expect(states[2].zIndex, greaterThan(states[3].zIndex));
    // 当前卡完整，下一张从背后伸出，后排延续条带直到屏幕边缘。
    expect(states[3].top, lessThan(states[2].top + cardSize.height));
    expect(
      states[5].top - states[4].top,
      closeTo(states[4].top - states[3].top, .001),
    );
    for (final state in states) {
      expect(state.rotation, 0);
    }
    expect(
      states.last.top + cardSize.height * states.last.scale,
      greaterThan(screenSize.height),
      reason: 'rear surfaces continue behind the navigation fade',
    );
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

    // 焦点卡最宽，向上下两侧按距离对称递减；素材仍保持清晰。
    expect(resting[2].scale, 1);
    expect(resting[1].scale, lessThan(resting[2].scale));
    expect(resting[0].scale, lessThan(resting[1].scale));
    expect(resting[3].scale, resting[1].scale);
    expect(resting[4].scale, resting[0].scale);
    expect(resting.every((state) => state.opacity == 1), isTrue);
    expect(resting.every((state) => state.rotation == 0), isTrue);
    // 焦点卡层级最高，向上下两侧递减；所以下方卡片不会反盖住上一张。
    expect(resting[2].zIndex, greaterThan(resting[1].zIndex));
    expect(resting[2].zIndex, greaterThan(resting[3].zIndex));
    expect(resting[1].zIndex, greaterThan(resting[0].zIndex));
    expect(resting[3].zIndex, greaterThan(resting[4].zIndex));
    expect(resting[4].zIndex, greaterThan(resting[5].zIndex));
    // 当前卡固定在可用卡片场景的垂直中心。
    expect(
      resting[2].top,
      closeTo((screenSize.height - cardSize.height) / 2 - 8, .001),
    );
    // 上方以稳定条带间距延伸，经过标题区域时由页面透明渐变淡出。
    expect(resting[0].top, lessThan(resting[1].top));
    expect(resting[0].top, lessThan(cardSize.height * .1));
    expect(
      resting[1].top - resting[0].top,
      closeTo(resting[2].top - resting[1].top, .001),
    );
    expect(resting[2].top - resting[1].top, inInclusiveRange(84, 128));
    // 下方最近一张只露出部分卡面，视觉重心仍属于当前卡。
    final trailingVisibleHeight =
        resting[3].top +
        cardSize.height * resting[3].scale -
        (resting[2].top + cardSize.height);
    expect(trailingVisibleHeight / cardSize.height, inInclusiveRange(.3, .6));
    for (var index = 3; index < resting.length; index++) {
      final previousVisualBottom =
          resting[index - 1].top + cardSize.height * resting[index - 1].scale;
      expect(
        resting[index].top,
        lessThan(previousVisualBottom),
        reason: 'each lower card starts behind the card immediately above it',
      );
    }
    expect(resting[4].top - resting[3].top, greaterThan(0));
    expect(
      resting.last.top + cardSize.height * resting.last.scale,
      greaterThan(screenSize.height),
    );
    // 向上拖拽：展开区连续交给下一张，所有卡都沿同一队列运动。
    expect(dragging[2].top, lessThan(resting[2].top));
    expect(dragging[3].top, lessThan(resting[3].top));
    expect(dragging[0].top, lessThan(resting[0].top));
  });

  test('stack fan scrolls with the selection so it always stays visible', () {
    final stackResting = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: 2,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    final stackDragging = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: 2,
      dragOffset: -70,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    // 向上拖拽时下一张卡向选中位置滑动，卡列顺序不变。
    expect(stackDragging[3].top, lessThan(stackResting[3].top));
    for (var index = 1; index < stackDragging.length; index++) {
      expect(
        stackDragging[index].top,
        greaterThan(stackDragging[index - 1].top),
      );
    }

    // 选中最后一张卡时卡列滚动，选中卡完整地留在场景内。
    final lastSelected = CardLayoutCalculator.calculate(
      mode: CardStackMode.stack,
      selectedIndex: 5,
      dragOffset: 0,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: 6,
    );
    expect(
      lastSelected[5].top + cardSize.height,
      lessThanOrEqualTo(screenSize.height),
    );

    final focusTops = <double>[];
    for (var selectedIndex = 0; selectedIndex < 6; selectedIndex++) {
      final states = CardLayoutCalculator.calculate(
        mode: CardStackMode.focus,
        selectedIndex: selectedIndex,
        dragOffset: 0,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: 6,
      );
      focusTops.add(states[selectedIndex].top);
    }
    expect(focusTops.toSet(), hasLength(1));
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
        expect(state.rotation.abs(), lessThanOrEqualTo(.03));
      }
    }
  });

  test('focus spacing is wider than the compact stack spacing', () {
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

    expect(focusReveal, greaterThan(stackReveal));
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

  test('stack and focus use different default selection policies', () {
    final stackController = CardStackController(
      vsync: const TestVSync(),
      cardIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
      initialMode: CardStackMode.stack,
    );
    addTearDown(stackController.dispose);
    expect(stackController.selectedId, isNull);
    expect(stackController.layoutSelectedIndex, -1);

    final focusController = CardStackController(
      vsync: const TestVSync(),
      cardIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
      initialMode: CardStackMode.focus,
    );
    addTearDown(focusController.dispose);
    expect(focusController.selectedId, 'd');
    expect(focusController.selectedIndex, 3);
  });

  test(
    'switching modes resets stack collapsed and focus to the middle card',
    () {
      final controller = CardStackController(
        vsync: const TestVSync(),
        cardIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
        initialMode: CardStackMode.focus,
      );
      addTearDown(controller.dispose);
      controller.configureLayout(screenSize: screenSize, cardSize: cardSize);

      controller.selectCard('f');
      expect(controller.selectedId, 'f');

      controller.setMode(CardStackMode.stack);
      expect(controller.selectedId, isNull);
      expect(controller.layoutSelectedIndex, -1);

      controller.selectCard('a');
      controller.setMode(CardStackMode.focus);
      expect(controller.selectedId, 'd');
      expect(controller.selectedIndex, 3);
    },
  );

  test('switching modes clears an in-progress card reorder', () {
    final controller = CardStackController(
      vsync: const TestVSync(),
      cardIds: const ['a', 'b', 'c', 'd'],
      initialMode: CardStackMode.wallet,
    );
    addTearDown(controller.dispose);
    controller.configureLayout(screenSize: screenSize, cardSize: cardSize);

    expect(controller.startWalletReorder('b'), isTrue);
    expect(controller.isReordering, isTrue);

    controller.setMode(CardStackMode.focus, animate: false);

    expect(controller.isReordering, isFalse);
    expect(controller.dragOffset, 0);
    expect(controller.selectedId, 'c');
  });

  test('stack drag changes selection while preserving order', () {
    final controller = CardStackController(
      vsync: const TestVSync(),
      cardIds: const ['a', 'b', 'c', 'd', 'e'],
      initialMode: CardStackMode.stack,
    );
    addTearDown(controller.dispose);
    controller.configureLayout(screenSize: screenSize, cardSize: cardSize);

    controller.selectCard('c');
    controller.startDrag();
    controller.updateDrag(-80);
    expect(controller.endDrag(velocity: -600), 3);
    expect(controller.selectedId, 'd');
    expect(controller.cardIds, const ['a', 'b', 'c', 'd', 'e']);
    final selectedTarget = controller.targetTransformFor('d')!;
    expect(selectedTarget.top, greaterThan(0));
    expect(selectedTarget.top + cardSize.height, lessThan(screenSize.height));
  });

  test('a fast fling skims across multiple cards at once', () {
    final controller = CardStackController(
      vsync: const TestVSync(),
      cardIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      initialMode: CardStackMode.focus,
    );
    addTearDown(controller.dispose);
    controller.configureLayout(screenSize: screenSize, cardSize: cardSize);

    expect(controller.selectedIndex, 3);
    controller.startDrag();
    controller.updateDrag(-260);
    expect(controller.endDrag(velocity: -2400), greaterThanOrEqualTo(5));
  });
}
