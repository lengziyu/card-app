import 'dart:math' as math;

import 'package:flutter/material.dart';

const cardFiLaunchBackground = Color(0xFF051026);

class CardFiStartupPlaceholder extends StatelessWidget {
  const CardFiStartupPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const _StartupVisual(progress: 0);
}

/// A short, one-shot Flutter handoff from the native launch screen.
///
/// The child is mounted immediately but its tickers stay disabled until the
/// cover has faded, preventing hidden home animations from consuming frames.
class CardFiStartupTransition extends StatefulWidget {
  const CardFiStartupTransition({
    required this.child,
    this.onFinished,
    super.key,
  });

  final Widget child;
  final VoidCallback? onFinished;

  @override
  State<CardFiStartupTransition> createState() =>
      _CardFiStartupTransitionState();
}

class _CardFiStartupTransitionState extends State<CardFiStartupTransition>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _started = false;
  bool _complete = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 820),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed || _complete || !mounted) {
            return;
          }
          setState(() => _complete = true);
          widget.onFinished?.call();
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != reduceMotion) {
      _reduceMotion = reduceMotion;
      _controller.duration = reduceMotion
          ? const Duration(milliseconds: 180)
          : const Duration(milliseconds: 820);
    }
    if (_started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_complete) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.forward();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(enabled: false, child: widget.child),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _controller.value;
              if (_reduceMotion) {
                return Opacity(
                  opacity: 1 - Curves.easeOut.transform(value),
                  child: const _StartupVisual(progress: 0),
                );
              }
              final exit = Curves.easeInCubic.transform(
                ((value - .72) / .28).clamp(0.0, 1.0),
              );
              return Opacity(
                opacity: 1 - exit,
                child: _StartupVisual(progress: value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StartupVisual extends StatelessWidget {
  const _StartupVisual({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = math.sin(math.pi * progress.clamp(0, 1));
    return Semantics(
      key: const Key('startup-splash'),
      container: true,
      label: 'CardFi',
      child: RepaintBoundary(
        child: ColoredBox(
          color: cardFiLaunchBackground,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest = constraints.biggest.shortestSide;
              final logoSize = (shortest * .41).clamp(160.0, 176.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _StartupGlowPainter(progress: progress)),
                  Center(
                    child: Transform.scale(
                      scale: 1 + pulse * .025,
                      child: SizedBox.square(
                        dimension: logoSize,
                        child: ExcludeSemantics(
                          child: Image.asset(
                            'assets/branding/cardfi-launch-icon.png',
                            fit: BoxFit.contain,
                            cacheWidth: 384,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StartupGlowPainter extends CustomPainter {
  const _StartupGlowPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = size.shortestSide;
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x244CB6FF), Color(0x0007142D)],
      ).createShader(Rect.fromCircle(center: center, radius: shortest * .72));
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    if (progress <= 0) return;
    final arrival = Curves.easeOutCubic.transform(
      (progress / .72).clamp(0.0, 1.0),
    );
    final radius = (shortest * .205).clamp(78.0, 112.0);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0x005CC8FF),
          Color(0xB85CC8FF),
          Color(0xA993FF9F),
          Color(0x005CC8FF),
        ],
        stops: [0, .36, .68, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * arrival,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StartupGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
