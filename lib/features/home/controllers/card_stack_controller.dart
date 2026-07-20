import 'dart:math' as math;

import 'package:card_app/features/home/domain/card_layout_calculator.dart';
import 'package:card_app/features/home/domain/card_stack_mode.dart';
import 'package:card_app/features/home/domain/card_transform_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CardStackController extends ChangeNotifier {
  CardStackController({
    required TickerProvider vsync,
    required List<String> cardIds,
    required CardStackMode initialMode,
    double initialRevealScale = 1,
  }) : _cardIds = List.of(cardIds),
       _mode = initialMode,
       _selectedId = cardIds.isEmpty ? null : cardIds[cardIds.length ~/ 2],
       _walletExpanded = initialMode != CardStackMode.wallet,
       _revealScale = initialRevealScale,
       _motion = AnimationController(
         vsync: vsync,
         duration: motionDuration,
         value: 1,
       ) {
    _motion.addListener(notifyListeners);
    _motion.addStatusListener(_handleMotionStatus);
  }

  static const Duration motionDuration = Duration(milliseconds: 420);
  static const double distanceThresholdFactor = .18;
  static const double velocityThreshold = 700;

  final AnimationController _motion;
  List<String> _cardIds;
  CardStackMode _mode;
  String? _selectedId;
  bool _hasUserSelected = false;
  bool _walletExpanded;
  double _revealScale;
  double _dragOffset = 0;
  String? _reorderingId;
  double _reorderOriginTop = 0;
  double _reorderDragTop = 0;
  bool _reduceMotion = false;
  Size _screenSize = Size.zero;
  Size _cardSize = Size.zero;
  Map<String, CardTransformState> _from = const {};
  Map<String, CardTransformState> _target = const {};
  Curve _curve = Curves.easeOutCubic;

  CardStackMode get mode => _mode;
  List<String> get cardIds => List.unmodifiable(_cardIds);
  String? get selectedId =>
      _mode == CardStackMode.wallet && !_walletExpanded ? null : _selectedId;
  bool get walletExpanded => _walletExpanded;
  double get revealScale => _revealScale;
  double get dragOffset => _dragOffset;
  bool get isDragging => _dragOffset != 0;
  bool get isReordering => _reorderingId != null;
  bool get isConfigured => _screenSize != Size.zero && _cardSize != Size.zero;

  int get selectedIndex {
    final id = _selectedId;
    if (id == null) return 0;
    final index = _cardIds.indexOf(id);
    return index < 0 ? 0 : index;
  }

  int get layoutSelectedIndex =>
      _mode == CardStackMode.wallet && !_walletExpanded ? -1 : selectedIndex;

  void configureLayout({required Size screenSize, required Size cardSize}) {
    if (_screenSize == screenSize && _cardSize == cardSize) return;
    final current = isConfigured
        ? _snapshotCurrent()
        : const <String, CardTransformState>{};
    _screenSize = screenSize;
    _cardSize = cardSize;
    final next = _calculateTarget();
    if (current.isEmpty || _motion.value == 1) {
      _from = next;
      _target = next;
      _motion.value = 1;
      return;
    }
    _startMotion(current, next, curve: _curve);
  }

  void syncCards(List<String> nextIds) {
    if (listEquals(_cardIds, nextIds)) return;
    final nextSet = nextIds.toSet();
    final merged = [
      ..._cardIds.where(nextSet.contains),
      ...nextIds.where((id) => !_cardIds.contains(id)),
    ];
    if (listEquals(_cardIds, merged)) return;
    _transition(() {
      _cardIds = merged;
      if (!_hasUserSelected || !_cardIds.contains(_selectedId)) {
        _selectedId = _defaultSelectedId();
      }
      if (_mode == CardStackMode.stack && _selectedId != null) {
        _moveIdToFocusSlot(_selectedId!);
      }
    });
  }

  void setMode(CardStackMode nextMode, {bool animate = true}) {
    if (_mode == nextMode) return;
    _transition(() {
      _mode = nextMode;
      _dragOffset = 0;
      if (nextMode == CardStackMode.wallet) {
        _walletExpanded = false;
      } else {
        _walletExpanded = true;
        if (!_hasUserSelected || _selectedId == null) {
          _selectedId = _defaultSelectedId();
        }
        if (nextMode == CardStackMode.stack && _selectedId != null) {
          _moveIdToFocusSlot(_selectedId!);
        }
      }
    }, animate: animate);
  }

  /// 返回 true 表示点到的已经是当前卡，应继续打开详情。
  bool selectCard(String id) {
    final index = _cardIds.indexOf(id);
    if (index < 0) return false;
    if (_mode == CardStackMode.stack) {
      if (_selectedId == id) return true;
      _transition(() {
        _hasUserSelected = true;
        _selectedId = id;
        _moveIdToFocusSlot(id);
      });
      return false;
    }
    if (_mode == CardStackMode.wallet && !_walletExpanded) {
      _transition(() {
        _walletExpanded = true;
        _hasUserSelected = true;
        _selectedId = id;
        _dragOffset = 0;
      });
      return false;
    }
    if (_selectedId == id) return true;
    _transition(() {
      _hasUserSelected = true;
      _selectedId = id;
      _dragOffset = 0;
    });
    return false;
  }

  void startDrag() {
    if (_reorderingId != null ||
        _mode == CardStackMode.stack ||
        (_mode == CardStackMode.wallet && !_walletExpanded) ||
        _cardIds.length < 2) {
      return;
    }
    if (_motion.isAnimating) {
      final current = _snapshotCurrent();
      _motion.stop();
      _from = current;
      _target = current;
      _motion.value = 1;
    }
  }

  void updateDrag(double delta) {
    if (_reorderingId != null ||
        _mode == CardStackMode.stack ||
        (_mode == CardStackMode.wallet && !_walletExpanded) ||
        _cardIds.length < 2 ||
        delta == 0) {
      return;
    }
    final atFirst = selectedIndex == 0 && _dragOffset + delta > 0;
    final atLast =
        selectedIndex == _cardIds.length - 1 && _dragOffset + delta < 0;
    final appliedDelta = atFirst || atLast ? delta * .28 : delta;
    final limit = math.max(72.0, _cardSize.height * .62);
    _dragOffset = (_dragOffset + appliedDelta).clamp(-limit, limit).toDouble();
    final next = _calculateTarget();
    _from = next;
    _target = next;
    _motion.value = 1;
    notifyListeners();
  }

  int endDrag({required double velocity}) {
    if (_reorderingId != null ||
        _mode == CardStackMode.stack ||
        (_mode == CardStackMode.wallet && !_walletExpanded) ||
        _dragOffset == 0) {
      return selectedIndex;
    }
    final current = _snapshotCurrent();
    final distancePassed =
        _dragOffset.abs() >= _cardSize.height * distanceThresholdFactor;
    final velocityPassed = velocity.abs() >= velocityThreshold;
    final directionSource = velocityPassed ? velocity : _dragOffset;
    var nextIndex = selectedIndex;
    if (distancePassed || velocityPassed) {
      nextIndex += directionSource < 0 ? 1 : -1;
      nextIndex = nextIndex.clamp(0, _cardIds.length - 1);
    }
    _hasUserSelected = true;
    _selectedId = _cardIds[nextIndex];
    _dragOffset = 0;
    _startMotion(current, _calculateTarget(), curve: Curves.easeOutBack);
    return nextIndex;
  }

  void cancelDrag() {
    if (_dragOffset == 0) return;
    final current = _snapshotCurrent();
    _dragOffset = 0;
    _startMotion(current, _calculateTarget(), curve: Curves.easeOutBack);
  }

  bool startWalletReorder(String id) {
    if (_mode != CardStackMode.wallet ||
        !_cardIds.contains(id) ||
        _cardIds.length < 2 ||
        !isConfigured) {
      return false;
    }
    if (_motion.isAnimating) {
      final current = _snapshotCurrent();
      _motion.stop();
      _from = current;
      _target = current;
      _motion.value = 1;
    }
    final originTop = transformFor(id).top;
    _reorderingId = id;
    _reorderOriginTop = originTop;
    _reorderDragTop = originTop;
    final next = _calculateTarget();
    _from = next;
    _target = next;
    _motion.value = 1;
    notifyListeners();
    return true;
  }

  bool updateWalletReorder(double delta) {
    final activeId = _reorderingId;
    if (activeId == null || _mode != CardStackMode.wallet || !isConfigured) {
      return false;
    }
    // LongPressMoveUpdate reports offsetFromOrigin, so keep the dragged card
    // anchored to its original screen position. Reordering the backing list
    // must never change the card that is currently under the pointer.
    _reorderDragTop = _reorderOriginTop + delta;
    final changed = _reorderWalletForDrag(activeId);
    final next = _calculateTarget();
    _from = next;
    _target = next;
    _motion.value = 1;
    notifyListeners();
    return changed;
  }

  List<String> endWalletReorder() {
    if (_reorderingId == null) return cardIds;
    final current = _snapshotCurrent();
    _reorderingId = null;
    _reorderOriginTop = 0;
    _reorderDragTop = 0;
    _startMotion(current, _calculateTarget(), curve: Curves.easeOutBack);
    return cardIds;
  }

  void cancelWalletReorder() {
    if (_reorderingId == null) return;
    final current = _snapshotCurrent();
    _reorderingId = null;
    _reorderOriginTop = 0;
    _reorderDragTop = 0;
    _startMotion(current, _calculateTarget(), curve: Curves.easeOutBack);
  }

  void setRevealScale(double nextScale, {bool animate = false}) {
    final safeScale = nextScale.clamp(.5, 2.8).toDouble();
    if ((safeScale - _revealScale).abs() < .001) return;
    if (animate) {
      _transition(() => _revealScale = safeScale);
      return;
    }
    _revealScale = safeScale;
    if (!isConfigured) return;
    final next = _calculateTarget();
    _from = next;
    _target = next;
    _motion.value = 1;
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    _reduceMotion = value;
  }

  CardTransformState transformFor(String id) {
    final end = _target[id];
    if (end == null) {
      return const CardTransformState(
        top: 0,
        left: 0,
        scale: 1,
        opacity: 0,
        rotation: 0,
        elevation: 0,
        zIndex: 0,
      );
    }
    final begin =
        _from[id] ??
        end.copyWith(top: end.top + 24, scale: end.scale * .96, opacity: 0);
    if (_motion.value >= 1) return end;
    return CardTransformState.lerp(
      begin,
      end,
      _curve.transform(_motion.value).clamp(0.0, 1.0),
    );
  }

  List<String> get paintOrder {
    final indexed = _cardIds.indexed.toList();
    indexed.sort((left, right) {
      final depth = transformFor(
        left.$2,
      ).zIndex.compareTo(transformFor(right.$2).zIndex);
      return depth == 0 ? left.$1.compareTo(right.$1) : depth;
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  void _moveIdToFocusSlot(String id) {
    final index = _cardIds.indexOf(id);
    if (index < 0 || _cardIds.length < 2) return;
    final focusSlot = _cardIds.length ~/ 2;
    if (index == focusSlot) return;
    final next = [..._cardIds];
    final cardId = next.removeAt(index);
    _cardIds = next..insert(focusSlot, cardId);
  }

  String? _defaultSelectedId() =>
      _cardIds.isEmpty ? null : _cardIds[_cardIds.length ~/ 2];

  void _transition(
    VoidCallback mutate, {
    Curve curve = Curves.easeOutCubic,
    bool animate = true,
  }) {
    final current = isConfigured
        ? _snapshotCurrent()
        : const <String, CardTransformState>{};
    mutate();
    if (!isConfigured) return;
    final next = _calculateTarget();
    if (!animate || _reduceMotion) {
      _from = next;
      _target = next;
      _motion.value = 1;
      notifyListeners();
      return;
    }
    _startMotion(current, next, curve: curve);
  }

  void _startMotion(
    Map<String, CardTransformState> current,
    Map<String, CardTransformState> next, {
    required Curve curve,
  }) {
    _curve = curve;
    _from = current;
    _target = next;
    if (_reduceMotion) {
      _from = next;
      _motion.value = 1;
      notifyListeners();
      return;
    }
    _motion
      ..duration = motionDuration
      ..forward(from: 0);
  }

  Map<String, CardTransformState> _calculateTarget() {
    if (!isConfigured || _cardIds.isEmpty) return const {};
    final states = CardLayoutCalculator.calculate(
      mode: _mode,
      selectedIndex: layoutSelectedIndex,
      dragOffset: _dragOffset,
      screenSize: _screenSize,
      cardSize: _cardSize,
      itemCount: _cardIds.length,
      revealScale: _revealScale,
    );
    final transforms = {
      for (var index = 0; index < _cardIds.length; index++)
        _cardIds[index]: states[index],
    };
    final reorderingId = _reorderingId;
    final active = reorderingId == null ? null : transforms[reorderingId];
    if (active != null) {
      transforms[reorderingId!] = active.copyWith(
        top: _reorderDragTop,
        scale: 1.018,
        rotation: -.014,
        elevation: 38,
        zIndex: _cardIds.length * 4,
      );
    }
    return transforms;
  }

  bool _reorderWalletForDrag(String activeId) {
    final activeIndex = _cardIds.indexOf(activeId);
    if (activeIndex < 0) return false;
    final baseStates = CardLayoutCalculator.calculate(
      mode: _mode,
      selectedIndex: layoutSelectedIndex,
      dragOffset: 0,
      screenSize: _screenSize,
      cardSize: _cardSize,
      itemCount: _cardIds.length,
      revealScale: _revealScale,
    );
    final activeTop = _reorderDragTop;
    var targetIndex = activeIndex;
    var nearestDistance = (activeTop - baseStates[activeIndex].top).abs();
    for (var index = 0; index < baseStates.length; index++) {
      if (index == activeIndex) continue;
      final distance = (activeTop - baseStates[index].top).abs();
      if (distance >= nearestDistance) continue;
      nearestDistance = distance;
      targetIndex = index;
    }
    if (targetIndex == activeIndex) return false;

    final nextIds = [..._cardIds];
    final moved = nextIds.removeAt(activeIndex);
    nextIds.insert(targetIndex, moved);
    _cardIds = nextIds;

    return true;
  }

  Map<String, CardTransformState> _snapshotCurrent() => {
    for (final id in _cardIds) id: transformFor(id),
  };

  void _handleMotionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _from = _target;
  }

  @override
  void dispose() {
    _motion
      ..removeListener(notifyListeners)
      ..removeStatusListener(_handleMotionStatus)
      ..dispose();
    super.dispose();
  }
}
