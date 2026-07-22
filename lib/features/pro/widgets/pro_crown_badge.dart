import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class ProCrownBadge extends StatelessWidget {
  const ProCrownBadge({this.showLabel = false, super.key});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF4A51C);
    return Semantics(
      label: 'Pro 会员功能',
      child: Container(
        key: const Key('pro-crown-badge'),
        padding: showLabel
            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
            : EdgeInsets.zero,
        decoration: showLabel
            ? BoxDecoration(
                color: gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: gold.withValues(alpha: .28)),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 16,
              child: CustomPaint(painter: _CrownPainter(color: gold)),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              const Text(
                'PRO',
                style: TextStyle(
                  color: gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * .08, size.height * .30)
      ..lineTo(size.width * .32, size.height * .56)
      ..lineTo(size.width * .50, size.height * .14)
      ..lineTo(size.width * .68, size.height * .56)
      ..lineTo(size.width * .92, size.height * .30)
      ..lineTo(size.width * .82, size.height * .78)
      ..lineTo(size.width * .18, size.height * .78)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .17,
          size.height * .82,
          size.width * .66,
          size.height * .12,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.color != color;
}
