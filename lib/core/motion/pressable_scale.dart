import 'dart:async';

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:flutter/material.dart';

typedef PressableScaleBuilder =
    Widget Function(BuildContext context, bool pressed);

/// Tap feedback that stays in the tap gesture arena, so vertical scrolling can
/// cancel it without accidentally opening the target.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.scale = MotionTokens.pressedScale,
    this.haptic = true,
    super.key,
  });

  final VoidCallback onTap;
  final PressableScaleBuilder builder;
  final String? semanticLabel;
  final double scale;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _tapPending = false;
  bool _reduceMotion = false;
  Stopwatch? _pressStopwatch;
  Timer? _tapTimer;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails _) {
    if (_tapPending) return;
    _pressStopwatch = Stopwatch()..start();
    _setPressed(true);
  }

  void _handleTapCancel() {
    _pressStopwatch = null;
    _setPressed(false);
  }

  void _handleTap() {
    if (_tapPending) return;
    _tapPending = true;
    final elapsed = _pressStopwatch?.elapsed ?? MotionTokens.press;
    final remaining = _reduceMotion || elapsed >= MotionTokens.press
        ? Duration.zero
        : MotionTokens.press - elapsed;
    _tapTimer = Timer(remaining, () {
      if (!mounted) return;
      if (widget.haptic) AppHaptics.selection();
      widget.onTap();
      _pressStopwatch = null;
      _tapPending = false;
      _setPressed(false);
    });
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _reduceMotion = reduceMotion;
    final child = AnimatedScale(
      key: const Key('pressable-scale-transform'),
      scale: reduceMotion || !_pressed ? 1 : widget.scale,
      duration: reduceMotion ? Duration.zero : MotionTokens.press,
      curve: MotionTokens.standardEnter,
      child: widget.builder(context, _pressed && !reduceMotion),
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel == null
          ? null
          : context.tr(widget.semanticLabel!),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: child,
      ),
    );
  }
}
