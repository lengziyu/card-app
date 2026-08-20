import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:flutter/material.dart';

/// Adds visual press feedback without joining the gesture arena. This lets an
/// existing Material button keep its semantics, callback and scroll behavior.
class MotionPressEffect extends StatefulWidget {
  const MotionPressEffect({
    required this.child,
    this.enabled = true,
    this.scale = MotionTokens.compactPressedScale,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<MotionPressEffect> createState() => _MotionPressEffectState();
}

class _MotionPressEffectState extends State<MotionPressEffect> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant MotionPressEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: reduceMotion || !_pressed ? 1 : widget.scale),
        duration: reduceMotion ? Duration.zero : MotionTokens.press,
        curve: MotionTokens.standardEnter,
        child: widget.child,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          transformHitTests: false,
          child: child,
        ),
      ),
    );
  }
}

/// A restrained icon state transition for favorite, add, theme and selection
/// controls. The outer control keeps a stable size.
class MotionStateIcon extends StatelessWidget {
  const MotionStateIcon({
    required this.stateKey,
    required this.child,
    super.key,
  });

  final Object stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : MotionTokens.stateChange,
      reverseDuration: reduceMotion ? Duration.zero : MotionTokens.fast,
      switchInCurve: MotionTokens.standardEnter,
      switchOutCurve: MotionTokens.standardExit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .9, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}

/// Scroll-driven compact title used by detail headers. No delayed animation is
/// added: position and opacity follow the actual scroll progress.
class CollapsingHeaderTitle extends StatelessWidget {
  const CollapsingHeaderTitle({
    required this.title,
    required this.progress,
    super.key,
  });

  final String title;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final value = MediaQuery.disableAnimationsOf(context) ? 1.0 : progress;
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * MotionTokens.smallOffset),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Widget buildMotionPageTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
) {
  final curved = animation.drive(CurveTween(curve: MotionTokens.standardEnter));
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .018),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween(
          begin: MotionTokens.incomingScale,
          end: 1.0,
        ).animate(curved),
        child: child,
      ),
    ),
  );
}
