import 'dart:ui';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/home/domain/card_layout_calculator.dart';
import 'package:card_app/features/home/domain/card_stack_mode.dart';
import 'package:flutter/material.dart';

class WalletCardItem extends StatefulWidget {
  const WalletCardItem({
    required this.card,
    required this.mode,
    required this.selected,
    required this.elevation,
    required this.focusDepth,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onTap,
    super.key,
  });

  final CardSummary card;
  final CardStackMode mode;
  final bool selected;
  final double elevation;
  final double focusDepth;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;
  final VoidCallback onTap;

  @override
  State<WalletCardItem> createState() => _WalletCardItemState();
}

class _WalletCardItemState extends State<WalletCardItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tint = Color(widget.card.tint);
    final shadowOpacity = AppColors.isDark ? .22 : .1;
    final cardFilter = _cardColorFilter(
      mode: widget.mode,
      selected: widget.selected,
      visualDepth: widget.focusDepth,
    );
    final blurSigma = _cardBlurSigma(
      mode: widget.mode,
      selected: widget.selected,
      visualDepth: widget.focusDepth,
    );
    final artwork = ColorFiltered(
      colorFilter: cardFilter,
      child: CardArtwork(card: widget.card, alignment: Alignment.topCenter),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      label:
          '${widget.card.name}，${widget.card.label}，${widget.selected ? '当前卡片' : '轻触聚焦'}',
      child: GestureDetector(
        key: Key('home-card-${widget.card.id}'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPressStart,
        onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
        onLongPressEnd: widget.onLongPressEnd,
        onLongPressCancel: widget.onLongPressCancel,
        child: AnimatedScale(
          scale: _pressed ? .982 : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: AspectRatio(
            aspectRatio: CardLayoutCalculator.cardAspectRatio,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(
                        alpha:
                            shadowOpacity +
                            (widget.elevation / 32) *
                                (AppColors.isDark ? .08 : .06),
                      ),
                      blurRadius: widget.elevation * 1.2,
                      spreadRadius: -widget.elevation * .22,
                      offset: Offset(0, widget.elevation * .48),
                    ),
                    BoxShadow(
                      color: AppColors.isDark
                          ? const Color(0x220E1838)
                          : const Color(0x146A78A8),
                      blurRadius: widget.elevation * .7,
                      offset: Offset(0, widget.elevation * .24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (blurSigma == 0)
                        artwork
                      else
                        ImageFiltered(
                          key: Key('home-card-blur-${widget.card.id}'),
                          imageFilter: ImageFilter.blur(
                            sigmaX: blurSigma,
                            sigmaY: blurSigma,
                          ),
                          child: artwork,
                        ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: AppColors.isDark ? .14 : .34,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.mode == CardStackMode.focus)
                        IgnorePointer(
                          child: SizedBox.expand(
                            key: Key('home-focus-card-${widget.card.id}'),
                          ),
                        ),
                      if (widget.mode == CardStackMode.wallet)
                        IgnorePointer(
                          child: SizedBox.expand(
                            key: Key('home-wallet-card-${widget.card.id}'),
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

  ColorFilter _cardColorFilter({
    required CardStackMode mode,
    required bool selected,
    required double visualDepth,
  }) {
    if (selected || mode == CardStackMode.wallet) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.srcOver);
    }
    if (mode == CardStackMode.focus) {
      final depth = visualDepth.clamp(1.0, 4.0);
      final saturation = (1 - depth * .055).clamp(.78, .95).toDouble();
      final lift = (8 + depth * 4.5).clamp(12.0, 26.0).toDouble();
      return ColorFilter.matrix(_saturationMatrix(saturation, lift));
    }
    final depth = visualDepth.clamp(1.0, 4.0);
    final saturation = (1 - depth * .045).clamp(.82, .96).toDouble();
    final lift = (7 + depth * 4).clamp(11.0, 23.0).toDouble();
    return ColorFilter.matrix(_saturationMatrix(saturation, lift));
  }

  double _cardBlurSigma({
    required CardStackMode mode,
    required bool selected,
    required double visualDepth,
  }) {
    if (selected || mode == CardStackMode.wallet) return 0;
    final depth = visualDepth.clamp(1.0, 4.0);
    if (mode == CardStackMode.focus) {
      // Focus mode uses a visibly stronger depth-of-field ramp: the nearest
      // neighbour is already softened, while distant cards recede into the
      // scene. Stack mode stays lighter so its compact card headers remain
      // easy to identify.
      return 1.4 + (depth - 1) * .9;
    }
    return .55 + (depth - 1) * .35;
  }

  List<double> _saturationMatrix(double saturation, double lift) {
    final inverse = 1 - saturation;
    const red = .213;
    const green = .715;
    const blue = .072;
    return [
      red * inverse + saturation,
      green * inverse,
      blue * inverse,
      0,
      lift,
      red * inverse,
      green * inverse + saturation,
      blue * inverse,
      0,
      lift,
      red * inverse,
      green * inverse,
      blue * inverse + saturation,
      0,
      lift,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
