import 'dart:async';
import 'dart:math' as math;

import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CardStack extends StatefulWidget {
  const CardStack({
    required this.cards,
    required this.heightScale,
    required this.scrollController,
    required this.onOpenCard,
    required this.onHeightScaleChanged,
    required this.onReorder,
    required this.onInteractionChanged,
    super.key,
  });

  final List<CardSummary> cards;
  final double heightScale;
  final ScrollController scrollController;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<double> onHeightScaleChanged;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  static const _dragHold = Duration(milliseconds: 140);
  static const _dragStartThreshold = 6.0;
  static const _earlyDragThreshold = 18.0;
  static const _autoScrollEdge = 84.0;
  static const _autoScrollStep = 14.0;

  late final AnimationController _entryController;
  late List<CardSummary> _orderedCards;
  final Map<int, Offset> _pointers = {};

  Timer? _dragArmTimer;
  Timer? _autoScrollTimer;
  int? _primaryPointer;
  String? _pressedCardId;
  String? _draggingCardId;
  Offset? _pressStartLocal;
  double _dragStartLocalY = 0;
  double _lastDragLocalY = 0;
  double _dragOffset = 0;
  double _previewHeight = 0;
  double _fullCardHeight = 0;
  double _cardStep = 0;
  bool _dragArmed = false;
  bool _pressCancelled = false;
  bool _isPinching = false;
  double _pinchStartDistance = 0;
  double _pinchStartScale = 1;

  @override
  void initState() {
    super.initState();
    _orderedCards = [...widget.cards];
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void didUpdateWidget(CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIds = widget.cards.map((card) => card.id).toList();
    final currentIds = _orderedCards.map((card) => card.id).toList();
    if (!_sameOrder(nextIds, currentIds)) {
      _orderedCards = [...widget.cards];
    }
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _dragArmTimer?.cancel();
    _autoScrollTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _beginPinch();
      return;
    }
    if (_pointers.length != 1 || _isPinching) return;

    final card = _cardAt(event.localPosition.dy);
    if (card == null) return;
    _primaryPointer = event.pointer;
    _pressedCardId = card.id;
    _pressStartLocal = event.localPosition;
    _dragStartLocalY = event.localPosition.dy;
    _lastDragLocalY = event.localPosition.dy;
    _dragArmed = event.kind == PointerDeviceKind.mouse;
    _pressCancelled = false;
    setState(() {});

    if (!_dragArmed) {
      _dragArmTimer = Timer(_dragHold, () {
        if (!mounted || _primaryPointer != event.pointer || _isPinching) return;
        _dragArmed = true;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_isPinching) {
      _updatePinch();
      return;
    }
    if (event.pointer != _primaryPointer || _pressStartLocal == null) return;

    final distance = event.localPosition.dy - _pressStartLocal!.dy;
    _lastDragLocalY = event.localPosition.dy;
    if (!_dragArmed && distance.abs() > _earlyDragThreshold) {
      _cancelPress();
      return;
    }
    if (!_dragArmed || distance.abs() <= _dragStartThreshold) return;

    if (_draggingCardId == null) {
      _draggingCardId = _pressedCardId;
      _dragStartLocalY = _pressStartLocal!.dy;
      _setInteractionActive(true);
    }
    _updateDrag(event.localPosition.dy);
    _updateAutoScroll(event.position.dy);
  }

  void _handlePointerUp(PointerEvent event) {
    final wasPinching = _isPinching;
    _pointers.remove(event.pointer);
    if (wasPinching) {
      if (_pointers.length < 2) {
        _isPinching = false;
        _setInteractionActive(false);
        setState(() {});
      }
      if (event.pointer == _primaryPointer) _resetPress();
      return;
    }
    if (event.pointer != _primaryPointer) return;

    final tappedCardId = _pressedCardId;
    final didDrag = _draggingCardId != null;
    final canTap = !_pressCancelled && !didDrag && tappedCardId != null;
    _finishDrag();
    if (canTap) {
      final card = _orderedCards
          .where((candidate) => candidate.id == tappedCardId)
          .firstOrNull;
      if (card != null) widget.onOpenCard(card);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pressCancelled = true;
    _handlePointerUp(event);
  }

  void _beginPinch() {
    final points = _pointers.values.take(2).toList();
    _dragArmTimer?.cancel();
    _finishDrag(notify: false);
    _isPinching = true;
    _pressCancelled = true;
    _pinchStartDistance = (points[0] - points[1]).distance;
    _pinchStartScale = widget.heightScale;
    _setInteractionActive(true);
    setState(() {});
  }

  void _updatePinch() {
    if (_pointers.length < 2 || _pinchStartDistance <= 0) return;
    final points = _pointers.values.take(2).toList();
    final distance = (points[0] - points[1]).distance;
    widget.onHeightScaleChanged(
      clampHomeCardHeightScale(
        _pinchStartScale * distance / _pinchStartDistance,
      ),
    );
  }

  void _updateDrag(double localY) {
    if (_draggingCardId == null) return;
    _dragOffset = localY - _dragStartLocalY;
    _reorderForPointer(localY);
    setState(() {});
  }

  void _reorderForPointer(double localY) {
    final activeId = _draggingCardId;
    if (activeId == null || _orderedCards.length < 2) return;
    final activeIndex = _orderedCards.indexWhere((card) => card.id == activeId);
    var targetIndex = activeIndex;

    for (var index = 0; index < _orderedCards.length; index++) {
      if (index == activeIndex) continue;
      final height = index == _orderedCards.length - 1
          ? _fullCardHeight
          : _previewHeight;
      final midpoint = index * _cardStep + height / 2;
      if (index < activeIndex && localY < midpoint) targetIndex = index;
      if (index > activeIndex && localY > midpoint) targetIndex = index;
    }
    if (targetIndex == activeIndex) return;

    final oldTop = activeIndex * _cardStep;
    final card = _orderedCards.removeAt(activeIndex);
    _orderedCards.insert(targetIndex, card);
    final newTop = targetIndex * _cardStep;
    _dragStartLocalY += newTop - oldTop;
    _dragOffset = localY - _dragStartLocalY;
    widget.onReorder(_orderedCards.map((item) => item.id).toList());
  }

  void _updateAutoScroll(double globalY) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final direction = globalY < _autoScrollEdge
        ? -1
        : globalY > screenHeight - _autoScrollEdge
        ? 1
        : 0;
    if (direction == 0) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      return;
    }
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _draggingCardId == null) return;
      final controller = widget.scrollController;
      if (!controller.hasClients) return;
      final current = controller.offset;
      final next = (current + direction * _autoScrollStep).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      );
      final applied = next - current;
      if (applied == 0) return;
      controller.jumpTo(next);
      _lastDragLocalY += applied;
      _updateDrag(_lastDragLocalY);
    });
  }

  CardSummary? _cardAt(double localY) {
    for (var index = _orderedCards.length - 1; index >= 0; index--) {
      final top = index * _cardStep;
      final height = index == _orderedCards.length - 1
          ? _fullCardHeight
          : _previewHeight;
      if (localY >= top && localY <= top + height) {
        return _orderedCards[index];
      }
    }
    return null;
  }

  void _cancelPress() {
    _dragArmTimer?.cancel();
    _pressCancelled = true;
    _pressedCardId = null;
    setState(() {});
  }

  void _finishDrag({bool notify = true}) {
    _dragArmTimer?.cancel();
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    final wasDragging = _draggingCardId != null;
    _draggingCardId = null;
    _dragOffset = 0;
    _resetPress();
    if (notify && wasDragging) _setInteractionActive(false);
    if (mounted) setState(() {});
  }

  void _resetPress() {
    _primaryPointer = null;
    _pressedCardId = null;
    _pressStartLocal = null;
    _dragArmed = false;
    _pressCancelled = false;
  }

  void _setInteractionActive(bool active) {
    widget.onInteractionChanged(active);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth, 420.0);
        _previewHeight =
            cardWidth * (homeCardPreviewDefault / 1010) * widget.heightScale;
        _fullCardHeight = cardWidth * (630 / 1010);
        _cardStep = math.max(0.0, _previewHeight - 24);
        final lastCardTop = math.max(0, _orderedCards.length - 1) * _cardStep;
        final paintingOrder = List.generate(_orderedCards.length, (i) => i);
        final draggingIndex = _orderedCards.indexWhere(
          (card) => card.id == _draggingCardId,
        );
        if (draggingIndex >= 0) {
          paintingOrder
            ..remove(draggingIndex)
            ..add(draggingIndex);
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: SizedBox(
            height: lastCardTop + _fullCardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final index in paintingOrder)
                  _StackedCard(
                    key: Key('home-card-${_orderedCards[index].id}'),
                    card: _orderedCards[index],
                    top:
                        index * _cardStep +
                        (_orderedCards[index].id == _draggingCardId
                            ? _dragOffset
                            : 0),
                    width: cardWidth,
                    height: index == _orderedCards.length - 1
                        ? _fullCardHeight
                        : _previewHeight,
                    isLast: index == _orderedCards.length - 1,
                    isPressed: _orderedCards[index].id == _pressedCardId,
                    isDragging: _orderedCards[index].id == _draggingCardId,
                    reduceMotion: reduceMotion,
                    entry: _entryController,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StackedCard extends StatelessWidget {
  const _StackedCard({
    required this.card,
    required this.top,
    required this.width,
    required this.height,
    required this.isLast,
    required this.isPressed,
    required this.isDragging,
    required this.reduceMotion,
    required this.entry,
    super.key,
  });

  final CardSummary card;
  final double top;
  final double width;
  final double height;
  final bool isLast;
  final bool isPressed;
  final bool isDragging;
  final bool reduceMotion;
  final Animation<double> entry;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AnimatedPositioned(
      duration: isDragging || reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      top: top,
      height: height,
      child: AnimatedBuilder(
        animation: entry,
        builder: (context, child) {
          final progress = reduceMotion ? 1.0 : entry.value;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 26),
              child: child,
            ),
          );
        },
        child: Semantics(
          button: true,
          label: '${card.name}，${card.label}，轻触查看详情，长按拖动排序',
          child: AnimatedRotation(
            turns: isDragging ? -1.2 / 360 : 0,
            duration: duration,
            child: AnimatedScale(
              duration: duration,
              scale: isDragging ? 1.01 : (isPressed ? 0.975 : 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Color(card.tint).withValues(
                        alpha: isDragging ? 0.28 : (isLast ? 0.18 : 0.10),
                      ),
                      blurRadius: isDragging ? 40 : (isLast ? 32 : 18),
                      offset: Offset(0, isDragging ? 22 : 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CardArtwork(card: card, alignment: Alignment.topCenter),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
