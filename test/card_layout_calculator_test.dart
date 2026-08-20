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
    // 参照效果：所有卡片等宽、全彩，不缩小也不加蒙层。
    expect(states.every((state) => state.scale == 1), isTrue);
    expect(states.every((state) => state.opacity == 1), isTrue);
    expect(states.every((state) => state.left == states.first.left), isTrue);
    // z 顺序即列表顺序：每张卡只露出卡头条带。
    for (var index = 1; index < states.length; index++) {
      expect(states[index].zIndex, greaterThan(states[index - 1].zIndex));
    }
    // 选中卡上方与下方的条带保持同一节奏。
    expect(states[1].top - states[0].top, inInclusiveRange(58, 112));
    expect(states[2].top - states[1].top, inInclusiveRange(58, 112));
    expect(states[5].top - states[4].top, inInclusiveRange(58, 112));
    // 选中卡完整展开：下一张卡从它的底边（加小间隙）继续。
    expect(
      states[3].top - (states[2].top + cardSize.height),
      inInclusiveRange(0, 16),
    );
    // 堆叠模式带一点交替倾斜，选中卡摆正。
    expect(states[2].rotation, 0);
    expect(states[1].rotation, isNot(0));
    expect(states[1].rotation.sign, isNot(states[0].rotation.sign));
    expect(states.every((state) => state.rotation.abs() <= .03), isTrue);
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

    // 选中卡最大最亮，离焦点越远逐层缩小（视图据此推导模糊/蒙层深度）。
    expect(resting[2].scale, 1);
    expect(resting[1].scale, lessThan(resting[2].scale));
    expect(resting[0].scale, lessThan(resting[1].scale));
    expect(resting[3].scale, lessThan(resting[2].scale));
    expect(resting.every((state) => state.opacity == 1), isTrue);
    expect(resting.every((state) => state.rotation == 0), isTrue);
    // z 序按离选中卡的距离递减：上方卡被更近的卡压住下半（露卡头），
    // 下方卡被更近的卡压住上半（露卡底）。
    expect(resting[2].zIndex, greaterThan(resting[1].zIndex));
    expect(resting[1].zIndex, greaterThan(resting[0].zIndex));
    expect(resting[2].zIndex, greaterThan(resting[3].zIndex));
    expect(resting[3].zIndex, greaterThan(resting[4].zIndex));
    expect(resting[4].zIndex, greaterThan(resting[5].zIndex));
    // 当前卡固定在可用卡片场景的垂直中心。
    expect(
      resting[2].top,
      closeTo((screenSize.height - cardSize.height) / 2, .001),
    );
    // 上方最远卡可以越过场景顶边，由渐隐遮罩溶解。
    expect(resting[0].top, lessThan(resting[1].top));
    expect(
      resting[1].scale,
      closeTo(1 - CardLayoutCalculator.focusDepthScaleStep, .001),
    );
    expect(resting[1].top - resting[0].top, inInclusiveRange(84, 128));
    expect(resting[2].top - resting[1].top, inInclusiveRange(84, 128));
    // 下一张卡的顶边压在选中卡底边之上一条带处，只露出卡底。
    expect(
      resting[2].top + cardSize.height - resting[3].top,
      inInclusiveRange(84, 128),
    );
    expect(resting[4].top - resting[3].top, inInclusiveRange(84, 128));
    // 向上拖拽：整副卡列连续跟手，选中卡上移、下一张卡向焦点靠近。
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
    final firstTop = controller.transformFor('a').top;
    controller.startDrag();
    controller.updateDrag(-80);
    expect(controller.endDrag(velocity: -600), 3);
    expect(controller.selectedId, 'd');
    expect(controller.cardIds, const ['a', 'b', 'c', 'd', 'e']);
    // 卡列跟随选中项滚动，第一张卡上移或保持不动，但不会下移。
    expect(controller.transformFor('a').top, lessThanOrEqualTo(firstTop));
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
