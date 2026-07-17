import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(child: CustomPaint(painter: _AuroraPainter())),
          child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;
    paint.shader =
        RadialGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.26),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.10),
            radius: size.width * 0.78,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.10),
      size.width * 0.78,
      paint,
    );

    paint.shader =
        RadialGradient(
          colors: [AppColors.cyan.withValues(alpha: 0.15), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.10, size.height * 0.56),
            radius: size.width * 0.92,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.56),
      size.width * 0.92,
      paint,
    );

    paint.shader =
        RadialGradient(
          colors: [AppColors.pink.withValues(alpha: 0.11), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.92),
            radius: size.width * 0.64,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.92),
      size.width * 0.64,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;
}
