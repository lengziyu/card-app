import 'dart:math' as math;

import 'package:cardfi/features/home/domain/card_stack_mode.dart';
import 'package:cardfi/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';

/// 首页卡包的纯布局引擎。
///
/// 输入只包含模式、选中项、拖拽量和可用尺寸；Widget 不再自行拼坐标。
///
/// 堆叠与聚焦共用同一套"连续扇形卡列"模型：每张卡露出一段等高的卡头条带，
/// 选中卡完整展开（下一张卡从它的底边继续），z 顺序即列表顺序。拖拽量被换算成
/// 小数选中位置，因此手指可以 1:1 连续滑过多张卡而不是一次一张。
abstract final class CardLayoutCalculator {
  static const double cardAspectRatio = 1.586;

  // 三种模式共用：比全出血略收一点，左右各多留约 4–6pt。
  static const double horizontalMargin = 20;
  static const double _contentInset = 8;

  /// 选中卡底边与下一张卡头之间的间隙。
  static const double _fanGap = 10;

  /// 三种模式从同一顶部基线开始。
  static const double _stackTopInset = _contentInset;

  /// 聚焦模式非选中卡的每层缩小量，同时也是视图推导模糊/蒙层深度的基准。
  static const double focusDepthScaleStep = .085;

  static List<CardTransformState> calculate({
    required CardStackMode mode,
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    double revealScale = 1,
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
      ),
      CardStackMode.focus => _focusFan(
        selectedIndex: math.max(0, safeSelected),
        dragOffset: dragOffset,
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
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
    // 扇形卡列自己在场景内滚动，场景高度始终等于可用高度；超出的条带
    // 允许绘制到场景之外（不裁剪），与参照的全出血卡列一致。
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
  /// 与展开距离一致（卡高 + 间隙 − 条带高），保证拖拽时正在展开/收起的
  /// 卡片 1:1 跟随手指。
  static double dragStep({
    required CardStackMode mode,
    required Size cardSize,
    double revealScale = 1,
  }) {
    if (mode == CardStackMode.focus) {
      // 聚焦里正在交接的卡片行程是"卡高 − 条带高"（下方卡与选中卡
      // 重叠一条带的距离）。
      return math.max(72, cardSize.height - _focusReveal(revealScale));
    }
    return math.max(72, cardSize.height + _fanGap - _stackReveal(revealScale));
  }

  /// 堆叠：连续扇形卡列，所有卡等大全彩、z 序即列表顺序，只露卡头条带。
  static List<CardTransformState> _stackFan({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final reveal = _stackReveal(revealScale);
    final left = (screenSize.width - cardSize.width) / 2;

    // 初始态：全部卡只露卡头条带，没有任何一张被展开高亮。
    if (selectedIndex < 0) {
      return List.generate(itemCount, (index) {
        final side = index.isEven ? -1.0 : 1.0;
        return CardTransformState(
          top: _stackTopInset + index * reveal,
          left: left,
          scale: 1,
          opacity: 1,
          rotation: side * (.016 + (index % 3) * .004),
          elevation: (26 - index * 2).clamp(8.0, 26.0).toDouble(),
          zIndex: index,
        );
      });
    }

    final step = dragStep(
      mode: CardStackMode.stack,
      cardSize: cardSize,
      revealScale: revealScale,
    );
    final maxPosition = (itemCount - 1).toDouble();
    // 小数选中位置：拖拽把选中项在卡列上连续移动，越过端点时轻微越界，
    // 由调用方的阻尼负责手感。
    final position = (selectedIndex - dragOffset / step)
        .clamp(-.45, maxPosition + .45)
        .toDouble();
    final expand = cardSize.height + _fanGap - reveal;
    final contentHeight =
        _stackTopInset +
        _contentInset +
        maxPosition * reveal +
        cardSize.height +
        (itemCount > 1 ? _fanGap : 0);
    final naturalSelectedTop = _stackTopInset + position * reveal;
    final centeredTop = (screenSize.height - cardSize.height) / 2 - 8;
    // 跟随选中项居中，但滚动被钳制在内容范围内：卡列在两端保持锚定，
    // 中段像滚轮一样跟手。
    final scroll = (naturalSelectedTop - centeredTop)
        .clamp(0.0, math.max(0.0, contentHeight - screenSize.height))
        .toDouble();
    return List.generate(itemCount, (index) {
      final distance = (index - position).abs();
      // 选中槽位之后的卡整体让出一张卡的高度；clamp 让这段展开量在
      // 相邻两张卡之间连续转移，拖拽时几何保持连贯。
      final expansion = (index - position).clamp(0.0, 1.0);
      final proximity = math.min(1.0, distance);
      final top = _stackTopInset + index * reveal + expand * expansion - scroll;
      final side = index.isEven ? -1.0 : 1.0;
      return CardTransformState(
        top: top,
        left: left,
        scale: 1,
        opacity: 1,
        // 堆叠模式带一点交替的倾斜，像随手码放的卡片；选中卡摆正。
        rotation: side * (.016 + (index % 3) * .004) * proximity,
        elevation: (26 - 12 * proximity - math.max(0, distance - 1) * 1.5)
            .clamp(8.0, 26.0)
            .toDouble(),
        zIndex: index,
      );
    });
  }

  /// 聚焦：选中卡固定在视觉焦点，上方卡露"卡头"（被更近的卡压住下半），
  /// 下方卡露"卡底"（被更近的卡压住上半），离焦点越远越小、越深。
  static List<CardTransformState> _focusFan({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final reveal = _focusReveal(revealScale);
    final step = dragStep(
      mode: CardStackMode.focus,
      cardSize: cardSize,
      revealScale: revealScale,
    );
    final maxPosition = (itemCount - 1).toDouble();
    final position = (selectedIndex - dragOffset / step)
        .clamp(-.45, maxPosition + .45)
        .toDouble();
    final left = (screenSize.width - cardSize.width) / 2;
    // 当前卡固定在可用场景的垂直中心；上下的卡片从这一张向外展开，
    // 既保留景深层级，也不会让首次进入聚焦模式显得贴近页头。
    final focusTop = (screenSize.height - cardSize.height) / 2;
    final nearest = position.round().clamp(0, itemCount - 1).toInt();
    return List.generate(itemCount, (index) {
      final offset = index - position;
      final distance = offset.abs();
      // 上方按条带高度排布；正在交接的卡走"卡高 − 条带高"的行程滑到
      // 选中卡之下；更下方的卡从选中卡底边上方一条带处继续，只露卡底。
      final top = offset <= 0
          ? focusTop + offset * reveal
          : offset >= 1
          ? focusTop + cardSize.height + (offset - 2) * reveal
          : focusTop + offset * (cardSize.height - reveal);
      final depth = math.min(3.5, distance);
      return CardTransformState(
        top: top,
        left: left,
        scale: 1 - depth * focusDepthScaleStep,
        opacity: 1,
        rotation: 0,
        elevation:
            (30 - 13 * math.min(1.0, distance) - math.max(0, distance - 1) * 4)
                .clamp(4.0, 30.0)
                .toDouble(),
        zIndex: _proximityZIndex(
          index: index,
          selectedIndex: nearest,
          itemCount: itemCount,
        ),
      );
    });
  }

  static int _proximityZIndex({
    required int index,
    required int selectedIndex,
    required int itemCount,
  }) {
    if (index == selectedIndex) return itemCount * 4;
    return itemCount * 4 - (index - selectedIndex).abs();
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

  static double _focusReveal(double revealScale) {
    return (104 * revealScale).clamp(84.0, 128.0).toDouble();
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
