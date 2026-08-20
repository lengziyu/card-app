import 'dart:ui';

import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/home/domain/card_stack_mode.dart';
import 'package:flutter/material.dart';

class WalletCardItem extends StatefulWidget {
  const WalletCardItem({
    required this.card,
    required this.mode,
    required this.selected,
    required this.elevation,
    required this.aspectRatio,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onTap,
    this.focusDepth = 0,
    this.onTapWithGeometry,
    this.sharedContentHidden = false,
    super.key,
  });

  final CardSummary card;
  final CardStackMode mode;
  final bool selected;
  final double elevation;
  final double aspectRatio;

  /// 离视觉焦点的层数（0 为选中卡）。聚焦模式据此做逐层的轻微模糊
  /// 与浅蒙层，表达景深；0 时完全不加处理。
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
    final depth = widget.focusDepth.clamp(0.0, 3.5).toDouble();
    // 逐层高斯模糊让焦点卡始终最清晰，远层自然退后。
    final blurSigma = depth <= .04 ? 0.0 : depth * .95;
    final veilStrength = (depth * (AppColors.isDark ? .07 : .12))
        .clamp(0.0, .42)
        .toDouble();
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
            aspectRatio: widget.aspectRatio,
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
                          CardArtwork(
                            card: widget.card,
                            alignment: Alignment.topCenter,
                          )
                        else
                          ImageFiltered(
                            key: Key('home-card-blur-${widget.card.id}'),
                            imageFilter: ImageFilter.blur(
                              sigmaX: blurSigma,
                              sigmaY: blurSigma,
                            ),
                            child: CardArtwork(
                              card: widget.card,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        if (veilStrength > 0)
                          IgnorePointer(
                            child: ColoredBox(
                              key: Key('home-card-veil-${widget.card.id}'),
                              color: Colors.white.withValues(
                                alpha: veilStrength,
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
}
