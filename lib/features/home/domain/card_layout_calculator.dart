import 'dart:math' as math;

import 'package:card_app/features/home/domain/card_stack_mode.dart';
import 'package:card_app/features/home/domain/card_transform_state.dart';
import 'package:flutter/material.dart';

/// 首页卡包的纯布局引擎。
///
/// 输入只包含模式、选中项、拖拽量和可用尺寸；Widget 不再自行拼坐标。
abstract final class CardLayoutCalculator {
  static const double cardAspectRatio = 1.586;
  static const double horizontalMargin = 18;
  static const double _contentInset = 8;

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
      CardStackMode.stack => _stack(
        selectedIndex: math.max(0, safeSelected),
        screenSize: screenSize,
        cardSize: cardSize,
        itemCount: itemCount,
        revealScale: revealScale,
      ),
      CardStackMode.focus => _focus(
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
    if (mode == CardStackMode.focus) return availableHeight;
    if (mode == CardStackMode.stack) {
      final contentHeight =
          cardHeight + _stackReveal(revealScale) * math.max(0, itemCount - 1);
      return math.max(availableHeight, contentHeight + _contentInset * 2);
    }
    final reveal = _walletReveal(revealScale);
    final contentHeight = selectedIndex < 0
        ? cardHeight + reveal * math.max(0, itemCount - 1)
        : itemCount == 1 || selectedIndex >= itemCount - 1
        ? cardHeight + reveal * math.max(0, itemCount - 1)
        : cardHeight * 2 + reveal * math.max(0, itemCount - 2);
    return math.max(availableHeight, contentHeight + _contentInset * 2);
  }

  /// 堆叠模式：整副卡组锚定在场景顶部，以紧密卡头节奏向下展开。
  static List<CardTransformState> _stack({
    required int selectedIndex,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final centeredLeft = (screenSize.width - cardSize.width) / 2;
    final reveal = _stackReveal(revealScale);
    final selectedTop = _contentInset + selectedIndex * reveal;
    return List.generate(itemCount, (index) {
      final distance = (index - selectedIndex).abs().toDouble();
      final selected = distance == 0;
      // Every card stays on one compact vertical track. Cards below the
      // selected item move down by only one reveal step, so most of their
      // artwork remains behind the card directly above them. Combined with
      // proximity z-ordering, this leaves one clean card-edge strip per item
      // instead of exposing almost the entire first card below the selection.
      final top = selectedTop + (index - selectedIndex) * reveal;
      final side = index.isEven ? -1.0 : 1.0;
      final scale = selected
          ? 1.0
          : math.max(.955, 1 - distance * .012).toDouble();
      return CardTransformState(
        top: top,
        left:
            centeredLeft + (selected ? 0 : side * math.min(4, distance * 1.6)),
        scale: scale,
        // Depth is expressed by a colour lift in WalletCardItem. Keeping the
        // surface opaque avoids darkening cards against the page background.
        opacity: 1,
        rotation: selected ? 0 : side * math.min(.012, .004 + distance * .002),
        elevation: selected ? 28 : math.max(7, 16 - distance * 2).toDouble(),
        zIndex: _proximityZIndex(
          index: index,
          selectedIndex: selectedIndex,
          itemCount: itemCount,
        ),
      );
    });
  }

  static List<CardTransformState> _focus({
    required int selectedIndex,
    required double dragOffset,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final targetIndex = _dragTarget(
      selectedIndex: selectedIndex,
      dragOffset: dragOffset,
      itemCount: itemCount,
    );
    final current = _focusBase(
      selectedIndex: selectedIndex,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: itemCount,
      revealScale: revealScale,
    );
    if (targetIndex == selectedIndex || dragOffset == 0) return current;
    final target = _focusBase(
      selectedIndex: targetIndex,
      screenSize: screenSize,
      cardSize: cardSize,
      itemCount: itemCount,
      revealScale: revealScale,
    );
    // The reveal distance is the distance the focused card travels when the
    // next card takes its place. Using that same distance for every card keeps
    // the stack coherent while dragging: the card under the finger, its
    // neighbours and their depth all move along one continuous track.
    final progress = (dragOffset.abs() / _focusReveal(revealScale))
        .clamp(0.0, 1.0)
        .toDouble();
    return List.generate(itemCount, (index) {
      return CardTransformState.lerp(current[index], target[index], progress);
    });
  }

  static List<CardTransformState> _focusBase({
    required int selectedIndex,
    required Size screenSize,
    required Size cardSize,
    required int itemCount,
    required double revealScale,
  }) {
    final left = (screenSize.width - cardSize.width) / 2;
    final reveal = _focusReveal(revealScale);
    const leadingInset = 20.0;
    final visiblePredecessors = math.min(selectedIndex, 2);
    final selectedTop = math
        .max(
          leadingInset + visiblePredecessors * reveal,
          (screenSize.height - cardSize.height) / 2 - 8,
        )
        .toDouble();
    return List.generate(itemCount, (index) {
      final distance = (index - selectedIndex).abs().toDouble();
      final selected = distance == 0;
      final top = index < selectedIndex
          ? selectedTop - (selectedIndex - index) * reveal
          : index == selectedIndex
          ? selectedTop
          : selectedTop +
                cardSize.height -
                reveal +
                (index - selectedIndex - 1) * reveal;
      return CardTransformState(
        top: top,
        left: left,
        scale: selected ? 1 : math.max(.76, 1 - distance * .07).toDouble(),
        // Keep focus cards fully opaque while the stacking geometry is being
        // tuned. Depth is still expressed through scale and elevation.
        opacity: 1,
        rotation: 0,
        elevation: selected ? 30 : math.max(4, 18 - distance * 4).toDouble(),
        zIndex: _proximityZIndex(
          index: index,
          selectedIndex: selectedIndex,
          itemCount: itemCount,
        ),
      );
    });
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
    return (62 * revealScale).clamp(48.0, 82.0).toDouble();
  }

  static double _stackReveal(double revealScale) {
    return (54 * revealScale).clamp(46.0, 68.0).toDouble();
  }

  static double _focusReveal(double revealScale) {
    return (104 * revealScale).clamp(88.0, 122.0).toDouble();
  }

  static int _proximityZIndex({
    required int index,
    required int selectedIndex,
    required int itemCount,
  }) {
    if (index == selectedIndex) return itemCount * 4;
    final distance = (index - selectedIndex).abs();
    return itemCount * 4 - distance;
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
