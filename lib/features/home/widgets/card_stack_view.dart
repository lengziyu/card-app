import 'dart:math' as math;
import 'dart:ui';

import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/home/controllers/card_stack_controller.dart';
import 'package:card_app/features/home/domain/card_layout_calculator.dart';
import 'package:card_app/features/home/domain/card_transform_state.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/home/widgets/wallet_card_item.dart';
import 'package:flutter/material.dart';

typedef HomeCardOpenTransition =
    void Function(CardSummary card, CatalogCardSourceGeometry geometry);

class CardStackView extends StatefulWidget {
  const CardStackView({
    required this.cards,
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

  @override
  void didUpdateWidget(covariant CardStackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heightScale != widget.heightScale && !_pinching) {
      widget.controller.setRevealScale(
        widget.heightScale / homeCardStackDefaultScale,
        animate: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.setReduceMotion(MediaQuery.disableAnimationsOf(context));
    final cardsById = {for (final card in widget.cards) card.id: card};
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth - CardLayoutCalculator.horizontalMargin * 2,
          420.0,
        );
        final cardHeight = cardWidth / CardLayoutCalculator.cardAspectRatio;
        final cardSize = Size(cardWidth, cardHeight);
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final mode = widget.controller.mode;
            final layoutHeight = CardLayoutCalculator.preferredHeight(
              mode: widget.controller.mode,
              availableHeight: widget.availableHeight,
              cardHeight: cardHeight,
              itemCount: widget.controller.cardIds.length,
              revealScale: widget.controller.revealScale,
              selectedIndex: widget.controller.layoutSelectedIndex,
            );
            // Focus is an immersive surface: keep its centering math tied to
            // the viewport slot, but let the stack paint farther underneath
            // the floating close control so the lower peeks are not clipped.
            final focusOverflow = mode == CardStackMode.focus
                ? math.min(124.0, widget.availableHeight * .22)
                : 0.0;
            final height = layoutHeight + focusOverflow;
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
            final firstVisibleFocusIndex = math.max(
              0,
              widget.controller.selectedIndex - 2,
            );
            final cardLayers = <Widget>[
              for (final id in widget.controller.paintOrder)
                if (mode != CardStackMode.focus ||
                    widget.controller.cardIds.indexOf(id) >=
                        firstVisibleFocusIndex)
                  if (cardsById[id] case final card?)
                    _PositionedWalletCard(
                      key: ValueKey('positioned-$id'),
                      card: card,
                      mode: mode,
                      selected: widget.controller.selectedId == id,
                      cardSize: cardSize,
                      controller: widget.controller,
                      onLongPressStart: (details) =>
                          _onCardLongPressStart(card, details),
                      onLongPressMoveUpdate: _onCardLongPressMoveUpdate,
                      onLongPressEnd: _onCardLongPressEnd,
                      onLongPressCancel: _onCardLongPressCancel,
                      onTap: () => _onCardTap(card),
                      onTapWithGeometry: (geometry) =>
                          _onCardTap(card, geometry: geometry),
                      sharedContentHidden:
                          widget.transitioningCardId == card.id,
                    ),
              if (mode == CardStackMode.focus)
                const Positioned.fill(child: _FocusEdgeSofteners()),
            ];

            return Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: GestureDetector(
                key: stackKey,
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: SizedBox(
                  height: height,
                  child: mode == CardStackMode.focus
                      ? Stack(clipBehavior: Clip.none, children: cardLayers)
                      : ClipRect(
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: cardLayers,
                          ),
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
    _pinching = true;
    _dragging = false;
    _pinchHeightStart = widget.heightScale;
    _pendingHeightScale = null;
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
    final nextHeightScale = _pendingHeightScale;
    _rawPinching = false;
    _pinching = false;
    _pendingHeightScale = null;
    if (nextHeightScale == null) return;
    widget.onHeightScaleChanged(nextHeightScale);
    AppHaptics.selection();
  }
}

class _FocusEdgeSofteners extends StatelessWidget {
  const _FocusEdgeSofteners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: const [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FocusEdgeFade(top: true),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -52,
            child: _FocusEdgeFade(top: false),
          ),
        ],
      ),
    );
  }
}

class _FocusEdgeFade extends StatelessWidget {
  const _FocusEdgeFade({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: top ? 42 : 58,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PositionedWalletCard extends StatelessWidget {
  const _PositionedWalletCard({
    required this.card,
    required this.mode,
    required this.selected,
    required this.cardSize,
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
                focusDepth: _visualDepthFor(state),
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

  double _visualDepthFor(CardTransformState state) {
    if (mode == CardStackMode.wallet) return 0;
    final scaleStep = mode == CardStackMode.focus ? .07 : .012;
    // Derive the treatment from the animated geometry instead of switching
    // it immediately with `selected`. This lets blur, colour lift and the
    // white veil cross-fade while the next card naturally comes forward.
    return ((1 - state.scale) / scaleStep).clamp(0.0, 4.0).toDouble();
  }
}
