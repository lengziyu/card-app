import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

/// Short, native celebratory motion used by the motion lab and real success
/// states. These are intentionally paint-based so they stay lightweight on
/// lower-end devices and do not need a WebView or a particle package.
class CardBurstCelebration extends StatefulWidget {
  const CardBurstCelebration({
    required this.trigger,
    required this.cards,
    this.onFinished,
    super.key,
  });

  final int trigger;
  final List<CardSummary> cards;
  final VoidCallback? onFinished;

  @override
  State<CardBurstCelebration> createState() => _CardBurstCelebrationState();
}

class _CardBurstCelebrationState extends State<CardBurstCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastTrigger = widget.trigger;
    // A real success state can insert this overlay only after the action has
    // completed. Start non-zero initial triggers on the next frame so that
    // path produces the same motion as a trigger update in the motion lab.
    if (widget.trigger != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CardBurstCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == _lastTrigger) return;
    _lastTrigger = widget.trigger;
    _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      widget.onFinished?.call();
      return;
    }
    unawaited(AppHaptics.lightImpact());
    _controller.forward(from: 0).whenComplete(widget.onFinished ?? () {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            if (progress >= 1 || progress == 0) return const SizedBox.expand();
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final cardWidth = math.min(94.0, size.width * .22);
                final cardHeight = cardWidth / 1.586;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConfettiPainter(
                          progress: progress,
                          palette: _cardConfettiPalette,
                          burstAt: .08,
                          gravity: .66,
                          particleCount: 28,
                          spreadScale: .64,
                          originY: .3,
                        ),
                      ),
                    ),
                    for (var index = 0; index < widget.cards.length; index++)
                      _FallingCard(
                        index: index,
                        card: widget.cards[index],
                        progress: progress,
                        size: size,
                        width: cardWidth,
                        height: cardHeight,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FallingCard extends StatelessWidget {
  const _FallingCard({
    required this.index,
    required this.card,
    required this.progress,
    required this.size,
    required this.width,
    required this.height,
  });

  final int index;
  final CardSummary card;
  final double progress;
  final Size size;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final delay = _noise(index, 7) * .42;
    final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (local == 0) return const SizedBox.shrink();
    // Continuous gravitational fall: no collection point or pause in the
    // middle of the screen. Deterministic noise keeps the effect testable.
    final scale = .46 + _noise(index, 8) * .38;
    final scaledWidth = width * scale;
    final scaledHeight = height * scale;
    final startX = _noise(index, 9) * (size.width + scaledWidth) - scaledWidth;
    final horizontalDrift = (_noise(index, 10) - .5) * size.width * .72;
    final x = startX + horizontalDrift * local;
    final startY = -scaledHeight * (1.2 + _noise(index, 11) * 5.2);
    final y = startY + (size.height + scaledHeight * 3) * local * local;
    final angle =
        (_noise(index, 12) - .5) * 1.15 +
        (_noise(index, 13) - .5) * math.pi * 3.8 * local;
    final opacity =
        ((local * 9).clamp(0.0, 1.0) * ((1 - local) * 4.8).clamp(0.0, 1.0))
            .clamp(0.0, 1.0);
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: _CelebrationCard(
            card: card,
            width: scaledWidth,
            height: scaledHeight,
          ),
        ),
      ),
    );
  }
}

/// A compact full-screen confetti bloom for a completed AI result. Unlike the
/// purchase celebration it does not introduce a gift prop, so the result card
/// remains the focus and the feedback finishes before the user starts reading.
class AiResultCelebration extends StatefulWidget {
  const AiResultCelebration({required this.trigger, super.key});

  final int trigger;

  @override
  State<AiResultCelebration> createState() => _AiResultCelebrationState();
}

class _AiResultCelebrationState extends State<AiResultCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastTrigger = widget.trigger;
  }

  @override
  void didUpdateWidget(covariant AiResultCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == _lastTrigger) return;
    _lastTrigger = widget.trigger;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    unawaited(AppHaptics.lightImpact());
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          if (progress == 0 || progress >= 1) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            painter: _ConfettiPainter(
              progress: progress,
              palette: _giftConfettiPalette,
              burstAt: .06,
              gravity: .5,
              particleCount: 92,
              spreadScale: .96,
              originY: .17,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    ),
  );
}

class ProGiftCelebration extends StatefulWidget {
  const ProGiftCelebration({
    required this.trigger,
    this.showCopy = true,
    this.onFinished,
    super.key,
  });

  final int trigger;
  final bool showCopy;
  final VoidCallback? onFinished;

  @override
  State<ProGiftCelebration> createState() => _ProGiftCelebrationState();
}

class _ProGiftCelebrationState extends State<ProGiftCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  );
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastTrigger = widget.trigger;
  }

  @override
  void didUpdateWidget(covariant ProGiftCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == _lastTrigger) return;
    _lastTrigger = widget.trigger;
    _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      widget.onFinished?.call();
      return;
    }
    unawaited(AppHaptics.mediumImpact());
    _controller.forward(from: 0).whenComplete(widget.onFinished ?? () {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            if (progress >= 1 || progress == 0) return const SizedBox.expand();
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final rise = Curves.easeOutBack.transform(
                  (progress / .34).clamp(0.0, 1.0),
                );
                final fall = Curves.easeInOutCubic.transform(
                  ((progress - .58) / .42).clamp(0.0, 1.0),
                );
                final opening = Curves.easeOut.transform(
                  ((progress - .3) / .24).clamp(0.0, 1.0),
                );
                final top =
                    lerpDouble(size.height + 96, size.height * .36, rise)! +
                    fall * size.height * .32;
                final visible =
                    ((progress * 8).clamp(0.0, 1.0) *
                            ((1 - progress) * 7).clamp(0.0, 1.0))
                        .clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: ((progress - .27) / .68).clamp(0.0, 1.0),
                        child: CustomPaint(
                          painter: _ConfettiPainter(
                            progress: progress,
                            palette: _giftConfettiPalette,
                            burstAt: .34,
                            gravity: .28,
                            particleCount: 156,
                            spreadScale: 1.08,
                            originY: .4,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: top,
                      child: Opacity(
                        opacity: visible,
                        child: Center(
                          child: Transform.scale(
                            scale: .52 + opening * .1,
                            child: _ProGiftBox(opening: opening),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showCopy)
                      Positioned(
                        left: 24,
                        right: 24,
                        top: size.height * .25,
                        child: Opacity(
                          opacity:
                              ((progress - .35) / .2).clamp(0.0, 1.0) *
                              ((.96 - progress) / .16).clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              Text(
                                context.tr('Pro 已开通'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFFFD985),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x9909172B),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                context.tr('高级卡包体验现已解锁'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFE5E6FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.card,
    required this.width,
    required this.height,
  });

  final CardSummary card;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: RepaintBoundary(
      child: CardArtwork(
        card: card,
        alignment: Alignment.center,
        showGeneratedLabels: false,
      ),
    ),
  );
}

class _ProGiftBox extends StatelessWidget {
  const _ProGiftBox({required this.opening});

  final double opening;

  @override
  Widget build(BuildContext context) {
    final lidOffset = 22.0 + opening * 30;
    return SizedBox(
      width: 184,
      height: 168,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 170,
            height: 118,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8169FF), Color(0xFF4734B8)],
              ),
              border: Border.all(color: const Color(0xFFFFE3A3), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x7A1B0E5D),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(width: 29, color: const Color(0xFFF8C75C)),
            ),
          ),
          Positioned(
            top: 11 - lidOffset,
            child: Transform.rotate(
              angle: -opening * .15,
              child: Container(
                width: 184,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA38EFF), Color(0xFF5E48D2)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFE3A3),
                    width: 1.4,
                  ),
                ),
                child: Center(
                  child: Container(width: 31, color: const Color(0xFFFFD668)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.progress,
    required this.palette,
    required this.burstAt,
    required this.gravity,
    this.particleCount = 42,
    this.spreadScale = .58,
    this.originY = .45,
  });

  final double progress;
  final List<Color> palette;
  final double burstAt;
  final double gravity;
  final int particleCount;
  final double spreadScale;
  final double originY;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = ((progress - burstAt) / (1 - burstAt)).clamp(0.0, 1.0);
    if (elapsed == 0) return;
    final center = Offset(size.width * .5, size.height * originY);
    for (var index = 0; index < particleCount; index++) {
      final angle = _noise(index, 1) * math.pi * 2;
      final distance =
          size.longestSide * (.15 + _noise(index, 2) * .85) * spreadScale;
      final start = Offset(
        center.dx + (_noise(index, 3) - .5) * size.width * .54,
        center.dy + (_noise(index, 4) - .5) * size.height * .16,
      );
      final point = Offset(
        start.dx + math.cos(angle) * distance * elapsed,
        start.dy +
            math.sin(angle) * distance * elapsed +
            size.height * gravity * elapsed * elapsed,
      );
      final opacity = ((1 - elapsed) * 1.35).clamp(0.0, 1.0);
      final length = 5 + _noise(index, 5) * 8;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + elapsed * (2 + _noise(index, 6) * 3));
      final paint = Paint()
        ..color = palette[index % palette.length].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      if (index.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: length, height: 4),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, length * .32, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette ||
      oldDelegate.burstAt != burstAt ||
      oldDelegate.gravity != gravity ||
      oldDelegate.particleCount != particleCount ||
      oldDelegate.spreadScale != spreadScale ||
      oldDelegate.originY != originY;
}

double _noise(int index, int salt) {
  final value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
  return value - value.floorToDouble();
}

const _cardConfettiPalette = [
  Color(0xFF58DDFC),
  Color(0xFF9C83FF),
  Color(0xFFFFAE55),
  Color(0xFFFF85AA),
];

const _giftConfettiPalette = [
  Color(0xFFFFD400),
  Color(0xFF00E5FF),
  Color(0xFFFF2474),
  Color(0xFFA855F7),
  Color(0xFF3DFA73),
  Color(0xFFFF6B00),
];
