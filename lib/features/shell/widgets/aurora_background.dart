import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    required this.child,
    this.authBackground = false,
    super.key,
  });

  final Widget child;
  final bool authBackground;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (AppColors.isDark || authBackground)
                  Image.asset(
                    AppColors.isDark
                        ? 'assets/backgrounds/register-bg.webp'
                        : 'assets/backgrounds/login-bg.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                  ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _AuroraPainter(
                      dark: AppColors.isDark,
                      authBackground: authBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.dark, required this.authBackground});

  final bool dark;
  final bool authBackground;

  void _radial(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: [0, 1],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? authBackground
                  ? [Color(0x6106091C), Color(0x800A0E28)]
                  : [Color(0x8A080C22), Color(0xA30A0E26)]
            : authBackground
            ? [Color(0x6BF6F9FF), Color(0x8FF4F7FF)]
            : [Color(0xFFF8FBFF), Color(0xFFF4F7FF), Color(0xFFFBFCFF)],
        stops: dark || authBackground ? [0, 1] : [0, 0.48, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    if (dark) {
      _radial(
        canvas,
        size,
        center: Offset(size.width * .76, size.height * .13),
        radius: size.width * .72,
        color: Color(0x1F5CB0FF),
      );
      _radial(
        canvas,
        size,
        center: Offset(size.width * .24, size.height * .78),
        radius: size.width * .76,
        color: Color(0x186A4EC4),
      );
      return;
    }

    if (authBackground) {
      _radial(
        canvas,
        size,
        center: Offset(size.width * .16, size.height * .14),
        radius: size.width * .58,
        color: Color(0x70CBE9FF),
      );
      _radial(
        canvas,
        size,
        center: Offset(size.width * .82, size.height * .10),
        radius: size.width * .62,
        color: Color(0x5EE2DCFF),
      );
      return;
    }

    _radial(
      canvas,
      size,
      center: Offset(size.width * .15, size.height * .08),
      radius: size.width * .62,
      color: Color(0xD6CCEBFF),
    );
    _radial(
      canvas,
      size,
      center: Offset(size.width * .87, size.height * .04),
      radius: size.width * .58,
      color: Color(0xB8E6E0FF),
    );
    _radial(
      canvas,
      size,
      center: Offset(size.width * .20, size.height * .72),
      radius: size.width * .68,
      color: Color(0x9ED8EEFF),
    );
    _radial(
      canvas,
      size,
      center: Offset(size.width * .76, size.height * .68),
      radius: size.width * .60,
      color: Color(0x5CC69FFF),
    );
    _radial(
      canvas,
      size,
      center: Offset(size.width * .60, size.height * .91),
      radius: size.width * .72,
      color: Color(0x52FFB5D2),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.authBackground != authBackground;
}
