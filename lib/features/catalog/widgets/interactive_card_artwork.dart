import 'dart:math' as math;

import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

class InteractiveCardArtwork extends StatefulWidget {
  const InteractiveCardArtwork({required this.card, super.key});

  final CardSummary card;

  @override
  State<InteractiveCardArtwork> createState() => _InteractiveCardArtworkState();
}

class _InteractiveCardArtworkState extends State<InteractiveCardArtwork> {
  double _rotateX = 0;
  double _rotateY = 0;
  Alignment _shineAlignment = Alignment.topLeft;
  bool _pressed = false;

  void _update(PointerEvent event, Size size, bool reduceMotion) {
    if (reduceMotion || size.isEmpty) return;
    final dx = (event.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (event.localPosition.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _rotateX = (0.5 - dy) * 0.13;
      _rotateY = (dx - 0.5) * 0.13;
      _shineAlignment = Alignment(dx * 2 - 1, dy * 2 - 1);
    });
  }

  void _reset() {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
      _shineAlignment = Alignment.topLeft;
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          key: const Key('interactive-card-artwork'),
          image: true,
          label: '${widget.card.name} 卡面预览',
          child: Listener(
            onPointerDown: (event) {
              setState(() => _pressed = true);
              _update(event, size, reduceMotion);
            },
            onPointerMove: (event) => _update(event, size, reduceMotion),
            onPointerUp: (_) => _reset(),
            onPointerCancel: (_) => _reset(),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_rotateX)
                ..rotateY(_rotateY)
                ..scaleByDouble(
                  _pressed && !reduceMotion ? 0.99 : 1,
                  _pressed && !reduceMotion ? 0.99 : 1,
                  1,
                  1,
                ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Color(widget.card.tint).withValues(alpha: 0.25),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CardArtwork(card: widget.card),
                    AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: _shineAlignment,
                          radius: math.sqrt2,
                          colors: [
                            Colors.white.withValues(
                              alpha: _pressed && !reduceMotion ? 0.22 : 0.08,
                            ),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
