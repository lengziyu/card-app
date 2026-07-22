import 'dart:ui';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
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
    this.onTapWithGeometry,
    this.sharedContentHidden = false,
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
  final ValueChanged<CatalogCardSourceGeometry>? onTapWithGeometry;
  final bool sharedContentHidden;

  @override
  State<WalletCardItem> createState() => _WalletCardItemState();
}

class _WalletCardItemState extends State<WalletCardItem> {
  final GlobalKey _surfaceKey = GlobalKey();
  bool _pressed = false;

  void _handleTap() {
    final callback = widget.onTapWithGeometry;
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (callback != null && renderObject is RenderBox) {
      final rect = MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        Offset.zero & renderObject.size,
      );
      callback(
        CatalogCardSourceGeometry(
          artworkRect: rect,
          // Home card artwork already owns its visible title treatment. The
          // shared flight uses only the card surface for this source.
          titleRect: Rect.fromLTWH(rect.left, rect.top, rect.width, 1),
        ),
      );
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tint = Color(widget.card.tint);
    final shadowOpacity = AppColors.isDark ? .22 : .1;
    final cardFilter = _cardColorFilter(
      mode: widget.mode,
      visualDepth: widget.focusDepth,
    );
    final blurSigma = _cardBlurSigma(
      mode: widget.mode,
      visualDepth: widget.focusDepth,
    );
    final veilStrength = _cardVeilStrength(
      mode: widget.mode,
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
        onTap: _handleTap,
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
            key: _surfaceKey,
            aspectRatio: CardLayoutCalculator.cardAspectRatio,
            child: Opacity(
              opacity: widget.sharedContentHidden ? 0 : 1,
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
                        if (widget.mode != CardStackMode.wallet)
                          IgnorePointer(
                            child: Opacity(
                              key: Key('home-card-veil-${widget.card.id}'),
                              opacity: veilStrength,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: AppColors.isDark ? .32 : .72,
                                      ),
                                      Colors.white.withValues(
                                        alpha: AppColors.isDark ? .22 : .5,
                                      ),
                                      Colors.white.withValues(
                                        alpha: AppColors.isDark ? .13 : .28,
                                      ),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0, .25, .82, 1],
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }

  ColorFilter _cardColorFilter({
    required CardStackMode mode,
    required double visualDepth,
  }) {
    if (mode == CardStackMode.wallet || visualDepth <= .01) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.srcOver);
    }
    if (mode == CardStackMode.focus) {
      final depth = visualDepth.clamp(0.0, 4.0);
      final saturation = (1 - depth * .055).clamp(.78, .95).toDouble();
      final lift = (depth * 6.5).clamp(0.0, 26.0).toDouble();
      return ColorFilter.matrix(_saturationMatrix(saturation, lift));
    }
    final depth = visualDepth.clamp(0.0, 4.0);
    final saturation = (1 - depth * .045).clamp(.82, .96).toDouble();
    final lift = (depth * 5.75).clamp(0.0, 23.0).toDouble();
    return ColorFilter.matrix(_saturationMatrix(saturation, lift));
  }

  double _cardBlurSigma({
    required CardStackMode mode,
    required double visualDepth,
  }) {
    if (mode == CardStackMode.wallet || visualDepth <= .01) return 0;
    final depth = visualDepth.clamp(0.0, 4.0);
    if (mode == CardStackMode.focus) {
      // Focus mode uses a visibly stronger depth-of-field ramp: the nearest
      // neighbour is already softened, while distant cards recede into the
      // scene. Stack mode stays lighter so its compact card headers remain
      // easy to identify.
      return .28 + depth * .58;
    }
    return .18 + depth * .36;
  }

  double _cardVeilStrength({
    required CardStackMode mode,
    required double visualDepth,
  }) {
    if (mode == CardStackMode.wallet || visualDepth <= .01) return 0;
    final depth = visualDepth.clamp(0.0, 4.0);
    final base = mode == CardStackMode.focus ? .74 : .68;
    return (depth * base).clamp(0.0, 1.0).toDouble();
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
