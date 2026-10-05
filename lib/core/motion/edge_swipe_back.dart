import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Adds a leading-edge back gesture without entering the gesture arena for
/// pointers that start elsewhere on the page.
///
/// This distinction is important for pages containing horizontal carousels,
/// image viewers, canvases, or card gestures: a full-screen horizontal drag
/// recognizer can steal those gestures even if its callback later ignores
/// pointers that did not start near the edge.
class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({
    required this.child,
    required this.onBack,
    this.enabled = true,
    this.followGesture = true,
    this.edgeWidth = 20,
    this.commitFraction = .28,
    this.commitVelocity = 680,
    super.key,
  });

  final Widget child;
  final VoidCallback onBack;
  final bool enabled;

  /// Some pages already own a custom reverse transition. They can keep edge
  /// recognition while disabling the additional translation performed here.
  final bool followGesture;
  final double edgeWidth;
  final double commitFraction;
  final double commitVelocity;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: MotionTokens.fast,
  );
  double _distance = 0;
  bool _completing = false;

  bool get _shouldFollowGesture =>
      widget.followGesture && !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(covariant EdgeSwipeBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _distance = 0;
      _progress.value = 0;
      _completing = false;
    }
  }

  void _handleStart(DragStartDetails _) {
    if (_completing) return;
    _progress.stop();
    _distance = 0;
  }

  void _handleUpdate(DragUpdateDetails details) {
    if (_completing) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    if (width <= 0) return;
    _distance = (_distance + (details.primaryDelta ?? 0)).clamp(0, width);
    if (_shouldFollowGesture) _progress.value = _distance / width;
  }

  void _handleEnd(DragEndDetails details) {
    if (_completing) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    final shouldCommit =
        width > 0 &&
        (_distance >= width * widget.commitFraction ||
            velocity >= widget.commitVelocity);
    if (shouldCommit) {
      _complete();
    } else {
      _cancel();
    }
  }

  void _handleCancel() => _cancel();

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    if (_shouldFollowGesture) {
      final remaining = 1 - _progress.value;
      await _progress.animateTo(
        1,
        duration: Duration(
          milliseconds: (MotionTokens.fast.inMilliseconds * remaining)
              .round()
              .clamp(80, MotionTokens.fast.inMilliseconds),
        ),
        curve: MotionTokens.standardEnter,
      );
    }
    if (!mounted) return;
    widget.onBack();
    if (!mounted) return;
    _distance = 0;
    _progress.value = 0;
    _completing = false;
  }

  Future<void> _cancel() async {
    if (_completing) return;
    _distance = 0;
    if (_progress.value > 0) {
      await _progress.animateBack(
        0,
        duration: MotionTokens.fast,
        curve: MotionTokens.standardEnter,
      );
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{
      _TouchHorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
            _TouchHorizontalDragGestureRecognizer
          >(() => _TouchHorizontalDragGestureRecognizer(debugOwner: this), (
            recognizer,
          ) {
            recognizer
              ..onStart = _handleStart
              ..onUpdate = _handleUpdate
              ..onEnd = _handleEnd
              ..onCancel = _handleCancel;
          }),
    };
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _progress,
            child: widget.child,
            builder: (context, child) {
              final offset = _shouldFollowGesture
                  ? MediaQuery.sizeOf(context).width * _progress.value
                  : 0.0;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
          ),
          if (widget.enabled)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.edgeWidth,
              child: RawGestureDetector(
                key: const Key('edge-swipe-back-hit-region'),
                gestures: gestures,
                behavior: HitTestBehavior.translucent,
                excludeFromSemantics: true,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TouchHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _TouchHorizontalDragGestureRecognizer({super.debugOwner})
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  @override
  String get debugDescription => 'touch horizontal drag';
}
