import 'dart:math' as math;

import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Native Flutter counterparts to the visual references supplied for AI
/// processing, search focus, and Pro plan selection. They deliberately avoid
/// WebView and JavaScript packages so the primary product UI remains native.
class ThinkingOrbs extends StatefulWidget {
  const ThinkingOrbs({this.size = 30, this.label = 'Working…', super.key});

  final double size;
  final String label;

  @override
  State<ThinkingOrbs> createState() => _ThinkingOrbsState();
}

class _ThinkingOrbsState extends State<ThinkingOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbs = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) =>
            CustomPaint(painter: _ThinkingOrbsPainter(_controller.value)),
      ),
    );
    if (widget.label.isEmpty) return orbs;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        orbs,
        const SizedBox(width: 8),
        Text(
          widget.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ThinkingOrbsPainter extends CustomPainter {
  const _ThinkingOrbsPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .17;
    for (var index = 0; index < 3; index++) {
      final phase = progress * math.pi * 2 + index * math.pi * 2 / 3;
      final orbit = size.shortestSide * (.23 + .045 * math.sin(phase * 1.7));
      final position =
          center + Offset(math.cos(phase) * orbit, math.sin(phase) * orbit);
      final color = [
        AppColors.cyan,
        AppColors.violet,
        const Color(0xFFE2B6FF),
      ][index];
      canvas.drawCircle(
        position,
        radius * 2.1,
        Paint()
          ..color = color.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, color],
            stops: const [.05, 1],
          ).createShader(Rect.fromCircle(center: position, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class BeamBorder extends StatefulWidget {
  const BeamBorder({
    required this.child,
    this.active = false,
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final bool active;
  final double radius;

  @override
  State<BeamBorder> createState() => _BeamBorderState();
}

class _BeamBorderState extends State<BeamBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_controller.isAnimating) _controller.forward(from: 0);
    if (!enabled && _controller.isAnimating) _controller.stop();
  }

  @override
  void didUpdateWidget(covariant BeamBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enabled = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_controller.isAnimating) _controller.forward(from: 0);
    if (!enabled && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) => CustomPaint(
      foregroundPainter: _BeamBorderPainter(
        progress: _controller.value,
        active: widget.active,
        radius: widget.radius,
      ),
      child: child,
    ),
    child: widget.child,
  );
}

class _BeamBorderPainter extends CustomPainter {
  const _BeamBorderPainter({
    required this.progress,
    required this.active,
    required this.radius,
  });
  final double progress;
  final bool active;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active || size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x0058DDFC),
          Color(0xFF58DDFC),
          Color(0xFF947BFF),
          Color(0x0058DDFC),
        ],
        stops: const [0, .17, .42, .65],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BeamBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.radius != radius;
}

class LiquidMetalSurface extends StatefulWidget {
  const LiquidMetalSurface({
    required this.child,
    required this.selected,
    this.radius = 16,
    this.colors = _defaultMetalColors,
    super.key,
  });

  static const _defaultMetalColors = <Color>[
    Color(0xFFE5B14F),
    Color(0xFFFFF6D5),
    Color(0xFF956120),
    Color(0xFFE5B14F),
  ];

  final Widget child;
  final bool selected;
  final double radius;
  final List<Color> colors;

  @override
  State<LiquidMetalSurface> createState() => _LiquidMetalSurfaceState();
}

class _LiquidMetalSurfaceState extends State<LiquidMetalSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.stop();
  }

  @override
  void didUpdateWidget(covariant LiquidMetalSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: widget.selected
            ? SweepGradient(
                transform: GradientRotation(_controller.value * math.pi * 2),
                colors: widget.colors,
              )
            : null,
      ),
      child: Padding(padding: const EdgeInsets.all(1.2), child: child),
    ),
    child: widget.child,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
