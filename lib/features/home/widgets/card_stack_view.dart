import 'dart:math' as math;

import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/home/controllers/card_stack_controller.dart';
import 'package:cardfi/features/home/domain/card_layout_calculator.dart';
import 'package:cardfi/features/home/domain/home_card_layout.dart';
import 'package:cardfi/features/home/widgets/wallet_card_item.dart';
import 'package:flutter/material.dart';

enum _TwoFingerGesture { undecided, pinch, scenePan }

typedef HomeCardOpenTransition =
    void Function(CardSummary card, CatalogCardSourceGeometry geometry);

class CardStackView extends StatefulWidget {
  const CardStackView({
    required this.cards,
    required this.displayMode,
    required this.controller,
    required this.availableHeight,
    required this.heightScale,
    required this.onHeightScaleChanged,
    required this.onReorderCards,
    required this.onOpenCard,
    this.onOpenCardTransition,
    this.transitioningCardId,
    super.key,
  });

  final List<CardSummary> cards;
  final CardStackMode displayMode;
  final CardStackController controller;
  final double availableHeight;
  final double heightScale;
  final ValueChanged<double> onHeightScaleChanged;
  final ValueChanged<List<String>> onReorderCards;
  final ValueChanged<CardSummary> onOpenCard;
  final HomeCardOpenTransition? onOpenCardTransition;
  final String? transitioningCardId;

  @override
  State<CardStackView> createState() => _CardStackViewState();
}

class _CardStackViewState extends State<CardStackView> {
  final Map<int, Offset> _pointers = {};
  bool _dragging = false;
  bool _pinching = false;
  bool _rawPinching = false;
  double _dragDistance = 0;
  double _pinchGestureStart = 1;
  double _pinchHeightStart = homeCardStackDefaultScale;
  double _pointerPinchDistance = 0;
  double? _pendingHeightScale;
  final Map<int, Offset> _twoFingerStartPoints = {};
  Offset _twoFingerStartCentroid = Offset.zero;
  double _twoFingerSceneOffsetStart = 0;
  double _twoFingerSceneOffset = 0;
  _TwoFingerGesture _twoFingerGesture = _TwoFingerGesture.undecided;

  static const double _twoFingerSceneUpLimit = 48;

  double get _twoFingerSceneDownLimit =>
      (widget.availableHeight * .55).clamp(280.0, 420.0).toDouble();

  @override
  void didUpdateWidget(covariant CardStackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayMode != widget.displayMode) {
      _resetScenePosition();
    }
    if (oldWidget.heightScale != widget.heightScale && !_pinching) {
      widget.controller.setRevealScale(
        widget.heightScale / homeCardStackDefaultScale,
        animate: true,
      );
    }
  }

  void _resetScenePosition() {
    _pointers.clear();
    _twoFingerStartPoints.clear();
    _rawPinching = false;
    _pinching = false;
    _dragging = false;
    _dragDistance = 0;
    _pendingHeightScale = null;
    _twoFingerSceneOffset = 0;
    _twoFingerSceneOffsetStart = 0;
    _twoFingerGesture = _TwoFingerGesture.undecided;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    widget.controller.setReduceMotion(reduceMotion);
    if (widget.availableHeight <= 0 &&
        widget.controller.mode != CardStackMode.wallet) {
      return const SizedBox.shrink();
    }
    final cardsById = {for (final card in widget.cards) card.id: card};
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final mode = widget.controller.mode;
            final widthLimit = math.min(
              constraints.maxWidth - CardLayoutCalculator.horizontalMargin * 2,
              440.0,
            );
            final cardWidth = mode == CardStackMode.wallet
                ? widthLimit
                : math.min(
                    widthLimit,
                    math.max(1.0, widget.availableHeight - 16) *
                        .46 *
                        CardLayoutCalculator.cardAspectRatio,
                  );
            // 三种展示模式共用素材的原始卡面比例。钱包模式只调整卡片
            // 之间露出的高度，不能拉高卡面，否则 CardArtwork 的 cover
            // 会裁掉左右两侧的内容。
            const cardAspectRatio = CardLayoutCalculator.cardAspectRatio;
            final cardHeight = cardWidth / cardAspectRatio;
            final cardSize = Size(cardWidth, cardHeight);
            final layoutHeight = CardLayoutCalculator.preferredHeight(
              mode: widget.controller.mode,
              availableHeight: widget.availableHeight,
              cardHeight: cardHeight,
              itemCount: widget.controller.cardIds.length,
              revealScale: widget.controller.revealScale,
              selectedIndex: widget.controller.layoutSelectedIndex,
            );
            final height = layoutHeight;
            final screenSize = Size(constraints.maxWidth, layoutHeight);
            widget.controller.configureLayout(
              screenSize: screenSize,
              cardSize: cardSize,
            );
            final stackKey = switch (mode) {
              CardStackMode.stack => const Key('card-stack'),
              CardStackMode.focus => const Key('home-focus-stack'),
              CardStackMode.wallet => const Key('home-mode-wallet'),
            };
            // 钱包模式的纵向手势属于外层 CustomScrollView。这里不要再
            // 注册 ScaleGestureRecognizer，否则 Android 上它可能先赢得
            // 手势竞技场，导致卡包列表偶发无法滚动（尤其是一加等设备）。
            // 堆叠/聚焦模式仍需要内部拖拽和双指缩放。
            final supportsSceneGestures = mode != CardStackMode.wallet;
            final cardLayers = <Widget>[
              for (final id in widget.controller.paintOrder)
                if (cardsById[id] case final card?)
                  _PositionedWalletCard(
                    key: ValueKey('positioned-$id'),
                    card: card,
                    mode: mode,
                    selected: widget.controller.visualSelectedId == id,
                    cardSize: cardSize,
                    cardAspectRatio: cardAspectRatio,
                    controller: widget.controller,
                    onLongPressStart: (details) =>
                        _onCardLongPressStart(card, details),
                    onLongPressMoveUpdate: _onCardLongPressMoveUpdate,
                    onLongPressEnd: _onCardLongPressEnd,
                    onLongPressCancel: _onCardLongPressCancel,
                    onTap: () => _onCardTap(card),
                    onTapWithGeometry: (geometry) =>
                        _onCardTap(card, geometry: geometry),
                    sharedContentHidden: widget.transitioningCardId == card.id,
                  ),
            ];

            return Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: GestureDetector(
                key: stackKey,
                behavior: HitTestBehavior.opaque,
                onScaleStart: supportsSceneGestures ? _onScaleStart : null,
                onScaleUpdate: supportsSceneGestures ? _onScaleUpdate : null,
                onScaleEnd: supportsSceneGestures ? _onScaleEnd : null,
                // 卡列可经过浮动控件后方，页面对卡片层统一做边缘透明渐变。
                child: SizedBox(
                  key: mode == CardStackMode.wallet
                      ? null
                      : const Key('home-fan-viewport'),
                  height: height,
                  child: mode == CardStackMode.wallet
                      ? ClipRect(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: cardLayers,
                          ),
                        )
                      : Stack(
                          key: const Key('home-fan-scene'),
                          clipBehavior: Clip.none,
                          children: cardLayers,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onCardTap(CardSummary card, {CatalogCardSourceGeometry? geometry}) {
    if (widget.controller.isReordering) return;
    if (widget.controller.mode == CardStackMode.wallet) {
      AppHaptics.lightImpact();
      _openCard(card, geometry);
      return;
    }
    if (widget.controller.selectCard(card.id)) {
      AppHaptics.lightImpact();
      _openCard(card, geometry);
      return;
    }
    AppHaptics.selection();
  }

  void _openCard(CardSummary card, CatalogCardSourceGeometry? geometry) {
    final transition = widget.onOpenCardTransition;
    if (transition != null && geometry != null) {
      transition(card, geometry);
      return;
    }
    widget.onOpenCard(card);
  }

  void _onCardLongPressStart(CardSummary card, LongPressStartDetails details) {
    if (widget.controller.mode != CardStackMode.wallet) return;
    if (!widget.controller.startWalletReorder(card.id)) return;
    _dragging = false;
    _pinching = false;
    AppHaptics.mediumImpact();
  }

  void _onCardLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!widget.controller.isReordering) return;
    final changed = widget.controller.updateWalletReorder(
      details.offsetFromOrigin.dy,
    );
    if (!changed) return;
    widget.onReorderCards(widget.controller.cardIds);
    AppHaptics.selection();
  }

  void _onCardLongPressEnd(LongPressEndDetails details) {
    if (!widget.controller.isReordering) return;
    final order = widget.controller.endWalletReorder();
    widget.onReorderCards(order);
    AppHaptics.lightImpact();
  }

  void _onCardLongPressCancel() {
    widget.controller.cancelWalletReorder();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_rawPinching || widget.controller.isReordering) return;
    _dragging = false;
    _pinching = details.pointerCount > 1;
    _dragDistance = 0;
    _pinchGestureStart = 1;
    _pinchHeightStart = widget.heightScale;
    _pendingHeightScale = null;
    if (!_pinching) widget.controller.startDrag();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_rawPinching || widget.controller.isReordering) return;
    if (details.pointerCount > 1) {
      if (!_pinching) {
        _pinching = true;
        _dragging = false;
        widget.controller.cancelDrag();
        _pinchGestureStart = details.scale;
        _pinchHeightStart = widget.heightScale;
      }
      final gestureScale = _pinchGestureStart == 0
          ? 1.0
          : details.scale / _pinchGestureStart;
      final nextHeightScale = clampHomeCardHeightScale(
        _pinchHeightStart * gestureScale,
      );
      _pendingHeightScale = nextHeightScale;
      widget.controller.setRevealScale(
        nextHeightScale / homeCardStackDefaultScale,
      );
      return;
    }
    if (_pinching) return;
    final delta = details.focalPointDelta.dy;
    _dragDistance += delta;
    if (!_dragging && _dragDistance.abs() > 2) {
      _dragging = true;
    }
    if (_dragging) widget.controller.updateDrag(delta);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_rawPinching || widget.controller.isReordering) return;
    if (_pinching) {
      final nextHeightScale = _pendingHeightScale;
      if (nextHeightScale != null) {
        widget.onHeightScaleChanged(nextHeightScale);
        AppHaptics.selection();
      }
      _pinching = false;
      _pendingHeightScale = null;
      return;
    }
    if (!_dragging) return;
    final previousIndex = widget.controller.selectedIndex;
    final nextIndex = widget.controller.endDrag(
      velocity: details.velocity.pixelsPerSecond.dy,
    );
    if (nextIndex != previousIndex) AppHaptics.cardSwipe();
    _dragging = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2) return;
    final points = _pointers.values.take(2).toList(growable: false);
    _pointerPinchDistance = (points[0] - points[1]).distance;
    if (_pointerPinchDistance <= 0) return;
    _rawPinching = true;
    _pinching = false;
    _dragging = false;
    _pinchHeightStart = widget.heightScale;
    _pendingHeightScale = null;
    _twoFingerStartPoints
      ..clear()
      ..addEntries(
        _pointers.entries
            .take(2)
            .map((entry) => MapEntry(entry.key, entry.value)),
      );
    _twoFingerStartCentroid = (points[0] + points[1]) / 2;
    _twoFingerSceneOffsetStart = _twoFingerSceneOffset;
    _twoFingerGesture = _TwoFingerGesture.undecided;
    widget.controller.cancelDrag();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    if (widget.controller.isReordering) return;
    _pointers[event.pointer] = event.localPosition;
    if (!_rawPinching || _pointers.length < 2 || _pointerPinchDistance <= 0) {
      return;
    }
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    final centroid = (points[0] + points[1]) / 2;
    final distanceDelta = distance - _pointerPinchDistance;
    final verticalTranslation = centroid.dy - _twoFingerStartCentroid.dy;

    if (_twoFingerGesture == _TwoFingerGesture.undecided) {
      final pointerIds = _pointers.keys.take(2).toList(growable: false);
      final firstMovement =
          _pointers[pointerIds[0]]! - _twoFingerStartPoints[pointerIds[0]]!;
      final secondMovement =
          _pointers[pointerIds[1]]! - _twoFingerStartPoints[pointerIds[1]]!;
      final fingersMoveTogether =
          firstMovement.dy.abs() >= 1 &&
          secondMovement.dy.abs() >= 1 &&
          firstMovement.dy * secondMovement.dy > 0;

      if (widget.controller.mode != CardStackMode.wallet &&
          fingersMoveTogether &&
          verticalTranslation.abs() >= 2 &&
          verticalTranslation.abs() >= distanceDelta.abs() * .25) {
        _twoFingerGesture = _TwoFingerGesture.scenePan;
        AppHaptics.selection();
      } else if (distanceDelta.abs() > 14 &&
          distanceDelta.abs() > verticalTranslation.abs() * 1.35) {
        _twoFingerGesture = _TwoFingerGesture.pinch;
        _pinching = true;
      }
    }

    if (_twoFingerGesture == _TwoFingerGesture.scenePan) {
      final nextOffset = (_twoFingerSceneOffsetStart + verticalTranslation)
          .clamp(-_twoFingerSceneUpLimit, _twoFingerSceneDownLimit)
          .toDouble();
      if (nextOffset != _twoFingerSceneOffset) {
        _twoFingerSceneOffset = nextOffset;
        widget.controller.setSceneOffset(nextOffset);
      }
      return;
    }
    if (_twoFingerGesture != _TwoFingerGesture.pinch) return;
    final nextHeightScale = clampHomeCardHeightScale(
      _pinchHeightStart * distance / _pointerPinchDistance,
    );
    _pendingHeightScale = nextHeightScale;
    widget.controller.setRevealScale(
      nextHeightScale / homeCardStackDefaultScale,
    );
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (!_rawPinching || _pointers.length >= 2) return;
    final wasScenePan = _twoFingerGesture == _TwoFingerGesture.scenePan;
    final nextHeightScale = _pendingHeightScale;
    _rawPinching = false;
    _pinching = false;
    _pendingHeightScale = null;
    _twoFingerStartPoints.clear();
    _twoFingerGesture = _TwoFingerGesture.undecided;
    if (wasScenePan) {
      widget.controller.cancelDrag();
      return;
    }
    if (nextHeightScale == null) return;
    widget.onHeightScaleChanged(nextHeightScale);
    AppHaptics.selection();
  }
}

class _PositionedWalletCard extends StatelessWidget {
  const _PositionedWalletCard({
    required this.card,
    required this.mode,
    required this.selected,
    required this.cardSize,
    required this.cardAspectRatio,
    required this.controller,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onTap,
    required this.onTapWithGeometry,
    required this.sharedContentHidden,
    super.key,
  });

  final CardSummary card;
  final CardStackMode mode;
  final bool selected;
  final Size cardSize;
  final double cardAspectRatio;
  final CardStackController controller;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;
  final VoidCallback onTap;
  final ValueChanged<CatalogCardSourceGeometry> onTapWithGeometry;
  final bool sharedContentHidden;

  @override
  Widget build(BuildContext context) {
    final state = controller.transformFor(card.id);
    return Positioned(
      top: state.top,
      left: state.left,
      width: cardSize.width,
      child: IgnorePointer(
        ignoring: state.opacity < .08,
        child: Opacity(
          opacity: state.opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: state.rotation,
            alignment: Alignment.topCenter,
            child: Transform.scale(
              scale: state.scale,
              alignment: Alignment.topCenter,
              child: WalletCardItem(
                card: card,
                mode: mode,
                selected: selected,
                elevation: state.elevation,
                focusDepth: state.focusDepth,
                aspectRatio: cardAspectRatio,
                onLongPressStart: onLongPressStart,
                onLongPressMoveUpdate: onLongPressMoveUpdate,
                onLongPressEnd: onLongPressEnd,
                onLongPressCancel: onLongPressCancel,
                onTap: onTap,
                onTapWithGeometry: onTapWithGeometry,
                sharedContentHidden: sharedContentHidden,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
