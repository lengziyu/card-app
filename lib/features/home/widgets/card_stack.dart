import 'dart:math' as math;

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/home/presentation/mock_card.dart';
import 'package:flutter/material.dart';

class CardStack extends StatefulWidget {
  const CardStack({required this.cards, super.key});

  final List<MockCard> cards;

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) {
      return;
    }
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ordered = <int>[
      _selected,
      ...List<int>.generate(
        widget.cards.length,
        (i) => i,
      ).where((i) => i != _selected),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth, 420.0);
        final cardHeight = cardWidth / 1.586;
        return SizedBox(
          height: cardHeight + 250,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var position = ordered.length - 1; position >= 0; position--)
                _StackedCard(
                  card: widget.cards[ordered[position]],
                  position: position,
                  width: cardWidth,
                  height: cardHeight,
                  isTop: position == 0,
                  reduceMotion: reduceMotion,
                  entry: _entryController,
                  onTap: () => _select(ordered[position]),
                ),
              Positioned(
                left: 4,
                right: 4,
                top: cardHeight + 208,
                child: Row(
                  children: const [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '轻触卡片，将它置于最前',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StackedCard extends StatefulWidget {
  const _StackedCard({
    required this.card,
    required this.position,
    required this.width,
    required this.height,
    required this.isTop,
    required this.reduceMotion,
    required this.entry,
    required this.onTap,
  });

  final MockCard card;
  final int position;
  final double width;
  final double height;
  final bool isTop;
  final bool reduceMotion;
  final Animation<double> entry;
  final VoidCallback onTap;

  @override
  State<_StackedCard> createState() => _StackedCardState();
}

class _StackedCardState extends State<_StackedCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final targetTop = widget.position * 58.0;
    return AnimatedPositioned(
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: widget.position * 3.0,
      right: widget.position * 3.0,
      top: targetTop,
      height: widget.height,
      child: AnimatedBuilder(
        animation: widget.entry,
        builder: (context, child) {
          final progress = widget.reduceMotion ? 1.0 : widget.entry.value;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 26),
              child: child,
            ),
          );
        },
        child: Semantics(
          button: true,
          label:
              '${widget.card.name}，${widget.card.label}，'
              '${widget.isTop ? '当前置顶' : '轻触置顶'}',
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              duration: widget.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 130),
              scale: _pressed ? 0.975 : 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                        widget.card.tint,
                      ).withValues(alpha: widget.isTop ? 0.22 : 0.10),
                      blurRadius: widget.isTop ? 30 : 18,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.card.assetPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: AppColors.surfaceRaised,
                          child: Icon(
                            Icons.credit_card_rounded,
                            color: Color(widget.card.tint),
                            size: 48,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: widget.isTop ? 0.36 : 0.18,
                            ),
                            width: 1.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x99020810)],
                            stops: [0.48, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 15,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    widget.card.label,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Color(0xD9FFFFFF),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
