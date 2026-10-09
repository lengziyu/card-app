import 'dart:math' as math;

import 'package:cardfi/features/home/domain/card_stack_mode.dart';
import 'package:cardfi/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';

/// 首页卡包的纯布局引擎。
///
/// 输入只包含模式、选中项、拖拽量和可用尺寸；Widget 不再自行拼坐标。
///
/// 堆叠与聚焦共用连续卡列：主卡完整显示，后排延伸到浮动控件下方。
/// 拖拽量换算成小数选中位置，交接时主卡跟随手指，边缘淡出由页面处理。
abstract final class CardLayoutCalculator {
  static const double cardAspectRatio = 1.586;

  // 三种模式共用：比全出血略收一点，左右各多留约 4–6pt。
  static const double horizontalMargin = 20;
  static const double _contentInset = 8;

  /// 选中卡底边与下一张卡头之间的间隙。
  static const double _fanGap = 10;

  /// 参照效果中，焦点卡最宽；每离开焦点一层约收窄 7.5%。
  static const double focusDepthScaleStep = .075;

  static List<CardTransformState> calculate({
    required CardStackMode mode,
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    double revealScale = 1,
    double sceneOffset = 0,
  }) {
    if (itemCount <= 0) return const [];
    final safeSelected = selectedIndex < 0
        ? -1
        : selectedIndex.clamp(0, itemCount - 1);
    return switch (mode) {
      CardStackMode.stack => _stackFan(
        selectedIndex: safeSelected,
        dragOffset: dragOffset,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
        sceneOffset: sceneOffset,
      ),
      CardStackMode.focus => _focusFan(
        selectedIndex: math.max(0, safeSelected),
        dragOffset: dragOffset,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
        sceneOffset: sceneOffset,
      ),
      CardStackMode.wallet => _wallet(
        selectedIndex: safeSelected,
        dragOffset: dragOffset,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
      ),
    };
  }

  static double preferredHeight({
    required CardStackMode mode,
    required double availableHeight,
    required double cardHeight,
    required int itemCount,
    int selectedIndex = -1,
    double revealScale = 1,
  }) {
    if (itemCount <= 0) return math.min(availableHeight, cardHeight);
    // 连续卡列占满页面，后排经过上下边缘时由透明渐变自然淡出。
    if (mode != CardStackMode.wallet) return availableHeight;
    final reveal = _walletReveal(revealScale);
    final contentHeight = selectedIndex < 0
        ? cardHeight + reveal * math.max(0, itemCount - 1)
        : itemCount == 1 || selectedIndex >= itemCount - 1
        ? cardHeight + reveal * math.max(0, itemCount - 1)
        : cardHeight * 2 + reveal * math.max(0, itemCount - 2);
    return math.max(availableHeight, contentHeight + _contentInset * 2);
  }

  /// 一次完整卡片切换所需的手指位移。
  ///
  /// 堆叠与聚焦使用完整卡高作为行程，让主卡在交接时保持 1:1 跟手。
  static double dragStep({
    required CardStackMode mode,
    required Size cardSize,
    double revealScale = 1,
  }) {
    return mode == CardStackMode.wallet
        ? math.max(72, cardSize.height + _fanGap - _stackReveal(revealScale))
        : cardSize.height;
  }

  /// 堆叠初始露出卡头，展开后与聚焦共用连续卡列。
  static List<CardTransformState> _stackFan({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
    required double sceneOffset,
  }) {
    if (selectedIndex >= 0) {
      return _continuousFan(
        mode: CardStackMode.stack,
        selectedIndex: selectedIndex,
        dragOffset: dragOffset,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
        sceneOffset: sceneOffset,
      );
    }
    final left = (screenSize.width - cardSize.width) / 2;
    final origin = _contentInset + sceneOffset;
    final reveal = _stackReveal(revealScale);
    return List.generate(
      itemCount,
      (index) => CardTransformState(
        top: origin + index * reveal,
        left: left,
        scale: 1,
        opacity: _surfaceVisible(
          origin + index * reveal,
          cardSize.height,
          screenSize.height,
        ),
        rotation: 0,
        elevation: (20 - index * 1.5).clamp(8.0, 20.0).toDouble(),
        zIndex: index,
      ),
    );
  }

  static List<CardTransformState> _focusFan({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
    required double sceneOffset,
  }) => _continuousFan(
    mode: CardStackMode.focus,
    selectedIndex: selectedIndex,
    dragOffset: dragOffset,
    screenSize: screenSize,
    cardSize: cardSize,
    itemCount: itemCount,
    revealScale: revealScale,
    sceneOffset: sceneOffset,
  );

  static List<CardTransformState> _continuousFan({
    required CardStackMode mode,
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
    required double sceneOffset,
  }) {
    final height = cardSize.height;
    final maxPosition = (itemCount - 1).toDouble();
    final position = (selectedIndex - dragOffset / height)
        .clamp(-.4, maxPosition + .4)
        .toDouble();
    final left = (screenSize.width - cardSize.width) / 2;
    final anchor = (screenSize.height - height) / 2 - 8 + sceneOffset;
    final reveal = mode == CardStackMode.focus
        ? _focusReveal(cardSize, revealScale)
        : math.min(_stackReveal(revealScale), height * .42);
    final trailingStep = mode == CardStackMode.focus
        ? height - reveal
        : height * (.6 * revealScale).clamp(.56, .72);
    final nearest = position.round().clamp(0, itemCount - 1).toInt();
    return List.generate(itemCount, (index) {
      final offset = index - position;
      final distance = offset.abs();
      final depth = distance.clamp(0.0, 3.2).toDouble();
      final scaleStep = mode == CardStackMode.focus
          ? focusDepthScaleStep
          : .035;
      final scale = (1 - depth * scaleStep).clamp(.76, 1.0).toDouble();
      final slot = offset < 0 ? reveal : trailingStep;
      final travel = distance <= 1
          ? _focusTravel(offset, height, offset < 0 ? slot : height - slot)
          : offset.sign * (slot + (distance - 1) * reveal);
      return CardTransformState(
        top: anchor + travel,
        left: left,
        scale: scale,
        opacity: _surfaceVisible(
          anchor + travel,
          height * scale,
          screenSize.height,
        ),
        rotation: 0,
        elevation: (22 - depth * 4).clamp(8.0, 22.0).toDouble(),
        zIndex: itemCount - (index - nearest).abs(),
        focusDepth: mode == CardStackMode.focus ? depth : 0,
      );
    });
  }

  // 完全离开屏幕的卡片无需绘制；仍在边缘内的部分只由位置渐变淡出。
  static double _surfaceVisible(
    double top,
    double height,
    double sceneHeight,
  ) => top + height <= 0 || top >= sceneHeight ? 0 : 1;

  static double _focusTravel(double offset, double cardHeight, double reveal) {
    final depth = offset.abs();
    if (depth <= .5) return offset * cardHeight;
    final sign = offset.sign;
    final slot = offset < 0 ? reveal : cardHeight - reveal;
    if (depth >= 1) return sign * (slot + (depth - 1) * reveal);

    // 在半个卡位处，两张卡先分开再交换层级，完整圆角始终保留。
    // Hermite 段把跟手速度平滑接到后排条带，避免中途突然停住或跳位。
    final t = (depth - .5) * 2;
    final t2 = t * t;
    final t3 = t2 * t;
    final travel =
        (2 * t3 - 3 * t2 + 1) * cardHeight * .5 +
        (t3 - 2 * t2 + t) * cardHeight * .5 +
        (-2 * t3 + 3 * t2) * slot +
        (t3 - t2) * reveal * .5;
    return sign * travel;
  }

  static List<CardTransformState> _wallet({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    if (selectedIndex < 0) {
      return _walletCollapsed(
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
      );
    }
    final targetIndex = _dragTarget(
      selectedIndex: selectedIndex,
      dragOffset: dragOffset,
      itemCount: itemCount,
    );
    final current = _walletBase(
      selectedIndex: selectedIndex,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: itemCount,
      revealScale: revealScale,
    );
    if (targetIndex == selectedIndex || dragOffset == 0) return current;
    final target = _walletBase(
      selectedIndex: targetIndex,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: itemCount,
      revealScale: revealScale,
    );
    final progress = (dragOffset.abs() / (cardSize.height * .48))
        .clamp(0.0, 1.0)
        .toDouble();
    return List.generate(itemCount, (index) {
      final interpolated = CardTransformState.lerp(
        current[index],
        target[index],
        progress,
      );
      if (index != selectedIndex) return interpolated;
      return interpolated.copyWith(top: current[index].top + dragOffset);
    });
  }

  static List<CardTransformState> _walletCollapsed({
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final left = (screenSize.width - cardSize.width) / 2;
    final reveal = _walletReveal(revealScale);
    return List.generate(
      itemCount,
      (index) => CardTransformState(
        top: _contentInset + index * reveal,
        left: left,
        scale: 1,
        opacity: 1,
        rotation: 0,
        elevation: 12,
        zIndex: index,
      ),
    );
  }

  static List<CardTransformState> _walletBase({
    required int selectedIndex,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final left = (screenSize.width - cardSize.width) / 2;
    final reveal = _walletReveal(revealScale);
    return List.generate(itemCount, (index) {
      final top = index <= selectedIndex
          ? _contentInset + index * reveal
          : _contentInset +
                selectedIndex * reveal +
                cardSize.height +
                (index - selectedIndex - 1) * reveal;
      return CardTransformState(
        top: top,
        left: left,
        scale: index == selectedIndex ? 1 : .992,
        opacity: 1,
        rotation: 0,
        elevation: index == selectedIndex ? 30 : 12,
        zIndex: index == selectedIndex ? itemCount + 4 : index,
      );
    });
  }

  static double _walletReveal(double revealScale) {
    // 未展开的钱包默认多露出一点下一张卡，方便未登录时浏览演示卡组；
    // 卡面本身仍统一使用标准比例，不能通过拉高卡面来增加可见面积。
    return (72 * revealScale).clamp(56.0, 92.0).toDouble();
  }

  static double _stackReveal(double revealScale) {
    return (84 * revealScale).clamp(58.0, 112.0).toDouble();
  }

  static double _focusReveal(Size cardSize, double revealScale) {
    // 默认约露出四成卡高；窄屏和双指缩放仍按卡面比例计算。
    return cardSize.height * (.42 * revealScale).clamp(.28, .62);
  }

  static int _dragTarget({
    required int selectedIndex,
    required double dragOffset,
    required int itemCount,
  }) {
    if (dragOffset < 0 && selectedIndex < itemCount - 1) {
      return selectedIndex + 1;
    }
    if (dragOffset > 0 && selectedIndex > 0) return selectedIndex - 1;
    return selectedIndex;
  }
}
