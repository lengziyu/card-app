import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

enum CardVisualEffect {
  particle,
  flame,
  fireworks,
  prism,
  supernova,
  magnetic,
  liquidMetal,
  spaceFold,
  shards,
  scanReveal,
  foldReveal,
  photoEtch,
  liquidCast,
  bandAlign,
  none,
}

bool _isReconstructionEffect(CardVisualEffect effect) => switch (effect) {
  CardVisualEffect.shards ||
  CardVisualEffect.scanReveal ||
  CardVisualEffect.foldReveal ||
  CardVisualEffect.photoEtch ||
  CardVisualEffect.liquidCast ||
  CardVisualEffect.bandAlign => true,
  _ => false,
};

// These fields deliberately paint beyond the card while they arrive. Keeping
// them out of ShaderMask avoids an expensive full-stage saveLayer on Android.
bool _usesUnmaskedEffectStage(CardVisualEffect effect) =>
    _isReconstructionEffect(effect) ||
    switch (effect) {
      CardVisualEffect.fireworks ||
      CardVisualEffect.magnetic ||
      CardVisualEffect.liquidMetal ||
      CardVisualEffect.spaceFold => true,
      _ => false,
    };

/// The full pixel cloud is retained for image fidelity, but the cinematic
/// render pass deliberately samples it. This keeps a 60 FPS-sized draw budget
/// on phones while the final card fades in at full resolution.
int cardReconstructionParticleBudget(CardVisualEffect effect) =>
    switch (effect) {
      CardVisualEffect.shards => 520,
      CardVisualEffect.foldReveal || CardVisualEffect.liquidCast => 600,
      CardVisualEffect.photoEtch => 640,
      CardVisualEffect.scanReveal || CardVisualEffect.bandAlign => 720,
      _ => 0,
    };

class _EffectStage extends StatelessWidget {
  const _EffectStage({
    required this.effect,
    required this.painter,
    required this.willChange,
  });

  final CardVisualEffect effect;
  final CustomPainter painter;
  final bool willChange;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      painter: painter,
      isComplex: true,
      willChange: willChange,
    );
    // A ShaderMask introduces a full-size offscreen saveLayer. These fields
    // already fade themselves and can safely paint unmasked on Android.
    if (_usesUnmaskedEffectStage(effect)) return paint;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
          Colors.transparent,
        ],
        stops: [0, .16, .28, .72, .84, 1],
      ).createShader(bounds),
      child: paint,
    );
  }
}

class InteractiveCardArtwork extends StatefulWidget {
  const InteractiveCardArtwork({
    required this.card,
    this.effect = CardVisualEffect.particle,
    this.artwork,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.animateInitialEffect = true,
    this.animateEffectChanges = true,
    super.key,
  });

  final CardSummary card;
  final CardVisualEffect effect;
  final Widget? artwork;
  final BorderRadius borderRadius;
  final bool animateInitialEffect;
  final bool animateEffectChanges;

  @override
  State<InteractiveCardArtwork> createState() => _InteractiveCardArtworkState();
}

class _InteractiveCardArtworkState extends State<InteractiveCardArtwork>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  late final AnimationController _entranceController;
  late final AnimationController _idleController;
  late final AnimationController _glassSweepController;
  final List<_PixelParticle> _pixels = [];

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Object? _loadedImageKey;
  double _rotateX = 0;
  double _rotateY = 0;
  Alignment _shineAlignment = Alignment.center;
  Offset? _pointerDown;
  bool _pressed = false;
  bool _didMove = false;
  bool? _lastReduceMotion;
  bool _waitingForPixels = false;
  int? _activeReconstructionParticleBudget;
  bool _reconstructionBudgetReduced = false;
  bool _didStartEffect = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _glassSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    // A card effect is decorative. Settling it when the app loses focus
    // avoids keeping a large custom-paint scene active behind another app or
    // the lock screen, and avoids a burst of catch-up work on resume.
    _entranceController.stop();
    _idleController.stop();
    _glassSweepController.stop();
    _entranceController.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCardPixels();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_lastReduceMotion != reduceMotion) {
      _lastReduceMotion = reduceMotion;
      final animate = _didStartEffect || widget.animateInitialEffect;
      _didStartEffect = true;
      _startEffect(animate: animate);
      _configureGlassSweep();
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveCardArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.imageUrl != widget.card.imageUrl ||
        oldWidget.card.assetPath != widget.card.assetPath) {
      _loadedImageKey = null;
      _pixels.clear();
      _loadCardPixels();
    }
    if (oldWidget.effect != widget.effect) {
      _startEffect(animate: widget.animateEffectChanges);
    } else if (!oldWidget.animateInitialEffect && widget.animateInitialEffect) {
      // 非重建入口的共享卡片转场先完成主要位移，再由详情卡接力播放用户
      // 选择的效果。重建入口从首帧直接启动，不走这里。
      _startEffect();
    }
  }

  bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  void _startEffect({bool animate = true}) {
    final reduceMotion = _lastReduceMotion ?? false;
    _configureEffectDurations();
    _activeReconstructionParticleBudget = _isReconstructionEffect(widget.effect)
        ? cardReconstructionParticleBudget(widget.effect)
        : null;
    _reconstructionBudgetReduced = false;
    _entranceController.stop();
    _idleController.stop();
    if (widget.effect == CardVisualEffect.none) {
      _entranceController.value = 1;
      _idleController.value = 0;
      return;
    }
    // A shared-card flight already expresses the entrance. Starting another
    // reconstruction here leaves the final card transparent after the flight
    // has disappeared. Settle directly on the fully rendered card instead;
    // tapping it or selecting another effect can still replay the animation.
    if (!animate) {
      _waitingForPixels = false;
      _entranceController.value = 1;
      _idleController.value = .18;
      return;
    }
    // The reconstruction effects need the actual card colours before the
    // opening begins. Starting early made a slow network image skip the most
    // interesting part of the animation.
    if (_requiresImageParticles && _pixels.isEmpty && _loadedImageKey != null) {
      _waitingForPixels = true;
      _entranceController.value = 0;
      _idleController.value = 0;
      return;
    }
    _waitingForPixels = false;
    if (reduceMotion || _isWidgetTest) {
      _entranceController.value = 1;
      _idleController.value = .24;
      return;
    }
    _entranceController.forward(from: 0);
    if (_usesIdleMotion) {
      _idleController
        ..value = 0
        ..forward();
    } else {
      _idleController.value = .18;
    }
  }

  bool get _usesIdleMotion => switch (widget.effect) {
    // Supernova keeps its original moving nebula treatment. Other heavy
    // scenes resolve during entry and then become static card treatments.
    CardVisualEffect.flame ||
    CardVisualEffect.prism ||
    CardVisualEffect.supernova => true,
    _ => false,
  };

  bool get _requiresImageParticles => switch (widget.effect) {
    CardVisualEffect.particle ||
    CardVisualEffect.shards ||
    CardVisualEffect.scanReveal ||
    CardVisualEffect.foldReveal ||
    CardVisualEffect.photoEtch ||
    CardVisualEffect.liquidCast ||
    CardVisualEffect.bandAlign => true,
    _ => false,
  };

  void _onFrameTimings(List<ui.FrameTiming> timings) {
    if (!mounted ||
        !_entranceController.isAnimating ||
        !_isReconstructionEffect(widget.effect) ||
        _reconstructionBudgetReduced) {
      return;
    }
    final worstFrameMicros = timings.fold<int>(0, (worst, timing) {
      final elapsed =
          timing.buildDuration.inMicroseconds +
          timing.rasterDuration.inMicroseconds;
      return math.max(worst, elapsed);
    });
    // At 60 Hz a frame has 16.7 ms. Leave room for scrolling and platform
    // work; one costly shader/paint frame triggers a single safe fallback.
    if (worstFrameMicros < 24000) return;
    final current =
        _activeReconstructionParticleBudget ??
        cardReconstructionParticleBudget(widget.effect);
    final lowerBudget = math.max(320, (current * .68).round());
    if (lowerBudget >= current) return;
    setState(() {
      _activeReconstructionParticleBudget = lowerBudget;
      _reconstructionBudgetReduced = true;
    });
  }

  void _configureEffectDurations() {
    _entranceController.duration = switch (widget.effect) {
      // 烟花从全场开幕到卡面落点需要更长的舞台时间。
      CardVisualEffect.fireworks => const Duration(milliseconds: 3000),
      CardVisualEffect.magnetic => const Duration(milliseconds: 1600),
      CardVisualEffect.spaceFold => const Duration(milliseconds: 1300),
      // These are deliberately cinematic. The scene needs enough time for
      // the field to establish, the card to reconstruct, and the final image
      // to lock instead of reading as a brief transition.
      CardVisualEffect.shards => const Duration(milliseconds: 2500),
      CardVisualEffect.scanReveal => const Duration(milliseconds: 2100),
      CardVisualEffect.foldReveal => const Duration(milliseconds: 2300),
      CardVisualEffect.photoEtch => const Duration(milliseconds: 2400),
      CardVisualEffect.liquidCast => const Duration(milliseconds: 2600),
      CardVisualEffect.bandAlign => const Duration(milliseconds: 2200),
      _ => const Duration(milliseconds: 920),
    };
    _idleController.duration = switch (widget.effect) {
      // Idle motion now runs once and settles. Long-running full-card custom
      // painting was the main sustained GPU load reported by beta devices.
      CardVisualEffect.supernova => const Duration(milliseconds: 3400),
      _ => const Duration(milliseconds: 2800),
    };
  }

  void _configureGlassSweep() {
    if ((_lastReduceMotion ?? false) || _isWidgetTest) {
      _glassSweepController.value = .42;
      return;
    }
    if (!_glassSweepController.isAnimating) {
      _glassSweepController.forward(from: 0);
    }
  }

  void _replayEffect() {
    if (widget.effect == CardVisualEffect.none ||
        (_lastReduceMotion ?? false) ||
        _isWidgetTest) {
      return;
    }
    _entranceController.forward(from: 0);
    _glassSweepController.forward(from: 0);
    if (_usesIdleMotion && !_idleController.isAnimating) {
      _idleController
        ..value = 0
        ..forward();
    }
  }

  ImageProvider<Object>? _imageProvider() {
    final imageUrl = widget.card.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ResizeImage.resizeIfNeeded(
        480,
        null,
        CachedNetworkImageProvider(imageUrl),
      );
    }
    final assetPath = widget.card.assetPath;
    if (assetPath != null && assetPath.isNotEmpty) {
      return ResizeImage.resizeIfNeeded(480, null, AssetImage(assetPath));
    }
    return null;
  }

  void _loadCardPixels() {
    final provider = _imageProvider();
    final key =
        '${widget.card.id}|${widget.card.imageUrl}|${widget.card.assetPath}';
    if (_loadedImageKey == key) return;
    _loadedImageKey = key;
    _detachImageListener();
    if (provider == null) {
      _buildFallbackParticles();
      return;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) async {
      final data = await info.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted || data == null || _loadedImageKey != key) return;
      _buildImageParticles(
        data,
        width: info.image.width,
        height: info.image.height,
      );
    }, onError: (_, _) => _buildFallbackParticles());
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _detachImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
  }

  void _buildImageParticles(
    ByteData data, {
    required int width,
    required int height,
  }) {
    final bytes = data.buffer.asUint8List();
    const targetCount = 2300;
    final step = math.max(3, math.sqrt(width * height / targetCount).ceil());
    final random = math.Random(widget.card.id.hashCode);
    final next = <_PixelParticle>[];
    for (var y = step ~/ 2; y < height; y += step) {
      for (var x = step ~/ 2; x < width; x += step) {
        final offset = (y * width + x) * 4;
        if (offset + 3 >= bytes.length || bytes[offset + 3] < 18) continue;
        next.add(
          _PixelParticle(
            x: x / width,
            y: y / height,
            color: Color.fromARGB(
              bytes[offset + 3],
              bytes[offset],
              bytes[offset + 1],
              bytes[offset + 2],
            ),
            angle: random.nextDouble() * math.pi * 2,
            distance: .70 + random.nextDouble() * .78,
            depth: random.nextDouble(),
            phase: random.nextDouble() * math.pi * 2,
            size: .7 + random.nextDouble() * 1.25,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _pixels
        ..clear()
        ..addAll(next);
    });
    if (_waitingForPixels) _startEffect();
  }

  void _buildFallbackParticles() {
    final random = math.Random(widget.card.id.hashCode);
    final tint = Color(widget.card.tint);
    final next = <_PixelParticle>[];
    for (var row = 0; row < 34; row++) {
      for (var column = 0; column < 54; column++) {
        final brightness = .18 + random.nextDouble() * .82;
        next.add(
          _PixelParticle(
            x: (column + .5) / 54,
            y: (row + .5) / 34,
            color: Color.lerp(const Color(0xFF11162B), tint, brightness)!,
            angle: random.nextDouble() * math.pi * 2,
            distance: .70 + random.nextDouble() * .78,
            depth: random.nextDouble(),
            phase: random.nextDouble() * math.pi * 2,
            size: .7 + random.nextDouble() * 1.25,
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _pixels
          ..clear()
          ..addAll(next);
      });
      if (_waitingForPixels) _startEffect();
    }
  }

  void _updateTilt(PointerEvent event, Size size, bool reduceMotion) {
    if (reduceMotion || size.isEmpty) return;
    if (_pointerDown case final start?) {
      if ((event.localPosition - start).distance > 7) _didMove = true;
    }
    final dx = (event.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (event.localPosition.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _rotateX = (0.5 - dy) * 0.13;
      _rotateY = (dx - 0.5) * 0.13;
      _shineAlignment = Alignment(dx * 2 - 1, dy * 2 - 1);
    });
  }

  void _resetTilt({required bool replay}) {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
      _shineAlignment = Alignment.center;
      _pressed = false;
      _pointerDown = null;
    });
    if (replay && !_didMove) _replayEffect();
    _didMove = false;
  }

  @override
  void dispose() {
    _detachImageListener();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _entranceController.dispose();
    _idleController.dispose();
    _glassSweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = Size(constraints.maxWidth, constraints.maxHeight);
        final effectWidthFactor = switch (widget.effect) {
          CardVisualEffect.fireworks => 2.05,
          CardVisualEffect.supernova => 2.28,
          CardVisualEffect.magnetic => 1.86,
          CardVisualEffect.spaceFold => 1.76,
          CardVisualEffect.shards ||
          CardVisualEffect.scanReveal ||
          CardVisualEffect.foldReveal ||
          CardVisualEffect.photoEtch ||
          CardVisualEffect.liquidCast ||
          CardVisualEffect.bandAlign => 2.04,
          _ => 1.62,
        };
        final effectHeightFactor = switch (widget.effect) {
          CardVisualEffect.fireworks => 2.25,
          CardVisualEffect.supernova => 2.48,
          CardVisualEffect.magnetic => 2.02,
          CardVisualEffect.spaceFold => 1.90,
          CardVisualEffect.shards ||
          CardVisualEffect.scanReveal ||
          CardVisualEffect.foldReveal ||
          CardVisualEffect.photoEtch ||
          CardVisualEffect.liquidCast ||
          CardVisualEffect.bandAlign => 2.18,
          _ => 2.08,
        };
        return Semantics(
          key: const Key('interactive-card-artwork'),
          image: true,
          button: true,
          label: '${widget.card.name} 卡面预览，轻触重播特效',
          child: Listener(
            onPointerDown: (event) {
              _pointerDown = event.localPosition;
              _didMove = false;
              setState(() => _pressed = true);
              _updateTilt(event, cardSize, reduceMotion);
            },
            onPointerMove: (event) =>
                _updateTilt(event, cardSize, reduceMotion),
            onPointerUp: (_) => _resetTilt(replay: true),
            onPointerCancel: (_) => _resetTilt(replay: false),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _entranceController,
                _idleController,
                _glassSweepController,
              ]),
              builder: (context, _) {
                final entrance = _entranceController.value;
                final reveal = switch (widget.effect) {
                  CardVisualEffect.particle => _interval(entrance, .78, 1),
                  CardVisualEffect.flame => _interval(entrance, .10, .48),
                  CardVisualEffect.fireworks => _interval(entrance, .16, .56),
                  CardVisualEffect.prism => _interval(entrance, .12, .44),
                  CardVisualEffect.supernova => _interval(entrance, .10, .46),
                  CardVisualEffect.magnetic => _interval(entrance, .34, .84),
                  CardVisualEffect.liquidMetal => _interval(entrance, .12, .52),
                  CardVisualEffect.spaceFold => _interval(entrance, .18, .64),
                  CardVisualEffect.shards => _interval(entrance, .66, .9),
                  CardVisualEffect.scanReveal => _interval(entrance, .7, .92),
                  CardVisualEffect.foldReveal => _interval(entrance, .68, .9),
                  CardVisualEffect.photoEtch => _interval(entrance, .7, .92),
                  CardVisualEffect.liquidCast => _interval(entrance, .67, .91),
                  CardVisualEffect.bandAlign => _interval(entrance, .7, .91),
                  CardVisualEffect.none => 1.0,
                };
                final blur = widget.effect == CardVisualEffect.flame
                    ? (1 - reveal) * 11
                    : 0.0;
                final glassProgress = Curves.easeOut.transform(
                  _glassSweepController.value,
                );
                final glassOpacity = _glassSweepOpacity(
                  _glassSweepController.value,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (widget.effect != CardVisualEffect.none)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: OverflowBox(
                            maxWidth: cardSize.width * effectWidthFactor,
                            maxHeight: cardSize.height * effectHeightFactor,
                            child: SizedBox(
                              width: cardSize.width * effectWidthFactor,
                              height: cardSize.height * effectHeightFactor,
                              child: _EffectStage(
                                effect: widget.effect,
                                painter: _effectPainter(
                                  entrance: entrance,
                                  idle: _idleController.value,
                                  cardSize: cardSize,
                                ),
                                willChange: entrance < .97,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: reveal,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: blur,
                          sigmaY: blur,
                        ),
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
                            borderRadius: widget.borderRadius,
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  widget.card.tint,
                                ).withValues(alpha: 0.25),
                                blurRadius: 34,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: widget.borderRadius,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RepaintBoundary(
                                  child: _CardArtworkEntrance(
                                    card: widget.card,
                                    effect: widget.effect,
                                    progress: entrance,
                                    artwork: () =>
                                        widget.artwork ??
                                        CardArtwork(card: widget.card),
                                  ),
                                ),
                                if (widget.effect == CardVisualEffect.fireworks)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CardSurfaceFireworkPainter(
                                          entrance: entrance,
                                          idle: _idleController.value,
                                          tint: Color(widget.card.tint),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.effect == CardVisualEffect.supernova)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CardSurfaceSupernovaPainter(
                                          entrance: entrance,
                                          idle: _idleController.value,
                                          tint: Color(widget.card.tint),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.effect == CardVisualEffect.magnetic)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _MagneticSurfacePainter(
                                          entrance: entrance,
                                          idle: _idleController.value,
                                          tint: Color(widget.card.tint),
                                          pointer: _shineAlignment,
                                          active: _pressed,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.effect ==
                                    CardVisualEffect.liquidMetal)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _LiquidMetalSurfacePainter(
                                          entrance: entrance,
                                          tint: Color(widget.card.tint),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.effect == CardVisualEffect.spaceFold)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _SpaceFoldSurfacePainter(
                                          entrance: entrance,
                                          tint: Color(widget.card.tint),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: -cardSize.height * .1,
                                  bottom: -cardSize.height * .1,
                                  left:
                                      -cardSize.width * .3 +
                                      glassProgress * cardSize.width * 1.104,
                                  width: cardSize.width * .24,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: glassOpacity,
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: 2,
                                          sigmaY: 2,
                                        ),
                                        child: Transform(
                                          transform: Matrix4.skewX(-.31),
                                          alignment: Alignment.center,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withValues(
                                                    alpha: .03,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: .38,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: .14,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                                stops: const [
                                                  0,
                                                  .24,
                                                  .46,
                                                  .58,
                                                  1,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
                                          alpha: _pressed && !reduceMotion
                                              ? 0.22
                                              : 0.08,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                    borderRadius: widget.borderRadius,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  CustomPainter _effectPainter({
    required double entrance,
    required double idle,
    required Size cardSize,
  }) => switch (widget.effect) {
    CardVisualEffect.particle => _PixelAssemblePainter(
      particles: _pixels,
      progress: entrance,
      cardSize: cardSize,
    ),
    CardVisualEffect.flame => _PerimeterFlamePainter(
      entrance: entrance,
      idle: idle,
      cardSize: cardSize,
    ),
    CardVisualEffect.fireworks => _FireworkPainter(
      entrance: entrance,
      idle: idle,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
    ),
    CardVisualEffect.prism => _PrismPainter(
      entrance: entrance,
      idle: idle,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
    ),
    CardVisualEffect.supernova => _SupernovaPainter(
      entrance: entrance,
      idle: idle,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
    ),
    CardVisualEffect.magnetic => _MagneticFluxPainter(
      entrance: entrance,
      idle: idle,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
      pointer: _shineAlignment,
      active: _pressed,
    ),
    CardVisualEffect.liquidMetal => _LiquidMetalAuraPainter(
      entrance: entrance,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
    ),
    CardVisualEffect.spaceFold => _SpaceFoldFieldPainter(
      entrance: entrance,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
    ),
    CardVisualEffect.shards ||
    CardVisualEffect.scanReveal ||
    CardVisualEffect.foldReveal ||
    CardVisualEffect.photoEtch ||
    CardVisualEffect.liquidCast ||
    CardVisualEffect.bandAlign => _CardReconstructionPainter(
      particles: _pixels,
      effect: widget.effect,
      entrance: entrance,
      tint: Color(widget.card.tint),
      cardSize: cardSize,
      maxParticles:
          _activeReconstructionParticleBudget ??
          cardReconstructionParticleBudget(widget.effect),
    ),
    CardVisualEffect.none => const _EmptyPainter(),
  };
}

double _interval(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  final normalized = (value - start) / (end - start);
  return 1 - math.pow(1 - normalized, 3).toDouble();
}

double _easeOutCubic(double value) =>
    1 - math.pow(1 - value.clamp(0.0, 1.0), 3).toDouble();

double _glassSweepOpacity(double progress) {
  if (progress <= .18) return progress / .18 * .55;
  if (progress <= .32) {
    return .55 + (progress - .18) / .14 * (.36 - .55);
  }
  return (.36 * (1 - (progress - .32) / .68)).clamp(0.0, 1.0);
}

/// Entrance treatments that move, clip, or assemble the real card artwork.
/// They intentionally finish without an idle loop so the details remain easy
/// to read after the opening beat.
class _CardArtworkEntrance extends StatelessWidget {
  const _CardArtworkEntrance({
    required this.card,
    required this.effect,
    required this.progress,
    required this.artwork,
  });

  final CardSummary card;
  final CardVisualEffect effect;
  final double progress;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => switch (effect) {
    // These modes are rendered by the expanded reconstruction scene outside
    // the rounded card. The final artwork only fades in once it locks.
    CardVisualEffect.shards ||
    CardVisualEffect.scanReveal ||
    CardVisualEffect.foldReveal ||
    CardVisualEffect.photoEtch ||
    CardVisualEffect.liquidCast ||
    CardVisualEffect.bandAlign => artwork(),
    _ => artwork(),
  };
}

typedef _ArtworkBuilder = Widget Function();

// Kept temporarily as a reference implementation while the expanded painter
// replaces the old clipped versions above.
// ignore: unused_element
class _ShardsArtwork extends StatelessWidget {
  const _ShardsArtwork({required this.progress, required this.artwork});

  final double progress;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reveal = Curves.easeOutCubic.transform(progress);
      const columns = 4;
      const rows = 3;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (var row = 0; row < rows; row++)
            for (var column = 0; column < columns; column++)
              Builder(
                builder: (context) {
                  final index = row * columns + column;
                  final centerX = column - (columns - 1) / 2;
                  final centerY = row - (rows - 1) / 2;
                  final settle = 1 - reveal;
                  final offset = Offset(
                    centerX * constraints.maxWidth * .22 * settle,
                    centerY * constraints.maxHeight * .34 * settle,
                  );
                  final turn = ((index * 17) % 7 - 3) * .09 * settle;
                  return Transform.translate(
                    offset: offset,
                    child: Transform.rotate(
                      angle: turn,
                      child: ClipRect(
                        clipper: _FractionalRectClipper(
                          left: column / columns,
                          top: row / rows,
                          width: 1 / columns,
                          height: 1 / rows,
                        ),
                        child: artwork(),
                      ),
                    ),
                  );
                },
              ),
        ],
      );
    },
  );
}

// ignore: unused_element
class _ScanRevealArtwork extends StatelessWidget {
  const _ScanRevealArtwork({
    required this.progress,
    required this.tint,
    required this.artwork,
  });

  final double progress;
  final Color tint;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reveal = Curves.easeOutCubic.transform(progress);
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            clipper: _FractionalRectClipper(
              left: 0,
              top: 0,
              width: 1,
              height: (reveal * 1.12).clamp(0.0, 1.0),
            ),
            child: artwork(),
          ),
          CustomPaint(
            painter: _ScanLinePainter(progress: reveal, tint: tint),
          ),
        ],
      );
    },
  );
}

// ignore: unused_element
class _FoldRevealArtwork extends StatelessWidget {
  const _FoldRevealArtwork({required this.progress, required this.artwork});

  final double progress;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reveal = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
      const columns = 3;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var column = 0; column < columns; column++)
            Builder(
              builder: (context) {
                final direction = column == 1
                    ? 0.0
                    : (column == 0 ? -1.0 : 1.0);
                final offset = Offset(
                  direction * constraints.maxWidth * .34 * (1 - reveal),
                  0,
                );
                final scaleX = .34 + .66 * reveal;
                return Transform.translate(
                  offset: offset,
                  child: Transform.scale(
                    alignment: Alignment(column - 1, 0),
                    scaleX: scaleX,
                    child: ClipRect(
                      clipper: _FractionalRectClipper(
                        left: column / columns,
                        top: 0,
                        width: 1 / columns,
                        height: 1,
                      ),
                      child: artwork(),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

// ignore: unused_element
class _PhotoEtchArtwork extends StatelessWidget {
  const _PhotoEtchArtwork({
    required this.progress,
    required this.tint,
    required this.artwork,
  });

  final double progress;
  final Color tint;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipPath(clipper: _CenterEtchClipper(progress), child: artwork()),
      CustomPaint(
        painter: _EtchOutlinePainter(progress: progress, tint: tint),
      ),
    ],
  );
}

// ignore: unused_element
class _LiquidCastArtwork extends StatelessWidget {
  const _LiquidCastArtwork({
    required this.progress,
    required this.tint,
    required this.artwork,
  });

  final double progress;
  final Color tint;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipPath(clipper: _LiquidRevealClipper(progress), child: artwork()),
      CustomPaint(
        painter: _LiquidEdgePainter(progress: progress, tint: tint),
      ),
    ],
  );
}

// ignore: unused_element
class _BandAlignArtwork extends StatelessWidget {
  const _BandAlignArtwork({required this.progress, required this.artwork});

  final double progress;
  final _ArtworkBuilder artwork;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reveal = Curves.easeOutCubic.transform(progress);
      const bands = 5;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var band = 0; band < bands; band++)
            Builder(
              builder: (context) {
                final direction = band.isEven ? -1.0 : 1.0;
                return Transform.translate(
                  offset: Offset(
                    direction *
                        constraints.maxWidth *
                        (.34 + band % 3 * .08) *
                        (1 - reveal),
                    0,
                  ),
                  child: ClipRect(
                    clipper: _FractionalRectClipper(
                      left: 0,
                      top: band / bands,
                      width: 1,
                      height: 1 / bands,
                    ),
                    child: artwork(),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class _FractionalRectClipper extends CustomClipper<Rect> {
  const _FractionalRectClipper({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    size.width * left,
    size.height * top,
    size.width * width,
    size.height * height,
  );

  @override
  bool shouldReclip(covariant _FractionalRectClipper oldClipper) =>
      oldClipper.left != left ||
      oldClipper.top != top ||
      oldClipper.width != width ||
      oldClipper.height != height;
}

class _CenterEtchClipper extends CustomClipper<Path> {
  const _CenterEtchClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * (.04 + .96 * reveal),
      height: size.height * (.07 + .93 * reveal),
    );
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(22 * reveal)));
  }

  @override
  bool shouldReclip(covariant _CenterEtchClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _LiquidRevealClipper extends CustomClipper<Path> {
  const _LiquidRevealClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final y = size.height * (1 - reveal);
    final wave = (1 - reveal) * 13 + 3;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, y)
      ..cubicTo(
        size.width * .24,
        y - wave,
        size.width * .68,
        y + wave,
        size.width,
        y,
      )
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _LiquidRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final y = size.height * progress;
    final glow = Paint()
      ..strokeWidth = 13
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = tint.withValues(alpha: .42 * math.sin(progress * math.pi));
    final line = Paint()
      ..strokeWidth = 1.35
      ..color = Colors.white.withValues(
        alpha: .88 * math.sin(progress * math.pi),
      );
    canvas.drawLine(Offset(0, y), Offset(size.width, y), glow);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tint != tint;
}

class _EtchOutlinePainter extends CustomPainter {
  const _EtchOutlinePainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final reveal = Curves.easeOutCubic.transform(progress);
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * (.04 + .96 * reveal),
      height: size.height * (.07 + .93 * reveal),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..color = Color.lerp(
        tint,
        Colors.white,
        .62,
      )!.withValues(alpha: (1 - progress) * .75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(22 * reveal)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EtchOutlinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tint != tint;
}

class _LiquidEdgePainter extends CustomPainter {
  const _LiquidEdgePainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final reveal = Curves.easeOutCubic.transform(progress);
    final y = size.height * (1 - reveal);
    final wave = (1 - reveal) * 13 + 3;
    final path = Path()
      ..moveTo(0, y)
      ..cubicTo(
        size.width * .24,
        y - wave,
        size.width * .68,
        y + wave,
        size.width,
        y,
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..color = Colors.white.withValues(
        alpha: .72 * math.sin(progress * math.pi),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidEdgePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tint != tint;
}

class _PixelParticle {
  const _PixelParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.angle,
    required this.distance,
    required this.depth,
    required this.phase,
    required this.size,
  });

  final double x;
  final double y;
  final Color color;
  final double angle;
  final double distance;
  final double depth;
  final double phase;
  final double size;
}

class _PixelAssemblePainter extends CustomPainter {
  const _PixelAssemblePainter({
    required this.particles,
    required this.progress,
    required this.cardSize,
  });

  final List<_PixelParticle> particles;
  final double progress;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final assemble = _easeOutCubic(progress);
    final fade = progress < .82 ? 1.0 : (1 - _interval(progress, .82, 1));
    if (fade <= 0) return;
    final cardRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    final center = size.center(Offset.zero);
    final paint = Paint()..blendMode = BlendMode.srcOver;
    final glowPaint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    for (var index = 0; index < particles.length; index++) {
      final particle = particles[index];
      final target = Offset(
        cardRect.left + particle.x * cardRect.width,
        cardRect.top + particle.y * cardRect.height,
      );
      final spread = size.width * particle.distance;
      final start =
          center +
          Offset(
            math.cos(particle.angle) * spread,
            math.sin(particle.angle) * spread * .72,
          );
      final depthDelay = particle.depth * .16;
      final localProgress = _easeOutCubic(
        ((progress - depthDelay) / (1 - depthDelay)).clamp(0.0, 1.0),
      );
      final drift = Offset(
        math.sin(progress * 9 + particle.phase) * (1 - assemble) * 11,
        math.cos(progress * 7 + particle.phase) * (1 - assemble) * 8,
      );
      final point = Offset.lerp(start, target, localProgress)! + drift;
      final alpha = fade * (.58 + particle.depth * .42);
      paint.color = particle.color.withValues(alpha: alpha);
      final radius = particle.size * (.78 + localProgress * .34);
      if (index % 18 == 0) {
        glowPaint.color = particle.color.withValues(alpha: alpha * .38);
        canvas.drawCircle(point, radius * 3.2, glowPaint);
      }
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: radius * 1.7,
          height: radius * 1.7,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelAssemblePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.particles != particles ||
      oldDelegate.cardSize != cardSize;
}

/// A full-stage, data-driven reconstruction scene. Unlike a clipped wipe, all
/// of its points are sampled from the real card artwork and can travel well
/// beyond the card before resolving back to their exact source position.
class _CardReconstructionPainter extends CustomPainter {
  const _CardReconstructionPainter({
    required this.particles,
    required this.effect,
    required this.entrance,
    required this.tint,
    required this.cardSize,
    required this.maxParticles,
  });

  final List<_PixelParticle> particles;
  final CardVisualEffect effect;
  final double entrance;
  final Color tint;
  final Size cardSize;
  final int maxParticles;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty || entrance <= 0) return;
    final progress = Curves.easeInOutCubic.transform(entrance);
    final fade = 1 - _interval(entrance, .72, .96);
    if (fade <= 0) return;
    final stageCenter = size.center(Offset.zero);
    final cardRect = Rect.fromCenter(
      center: stageCenter,
      width: cardSize.width,
      height: cardSize.height,
    );
    _paintField(canvas, size, cardRect, progress, fade);

    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final core = Paint()..blendMode = BlendMode.screen;
    final trail = Paint()
      ..blendMode = BlendMode.screen
      ..strokeCap = StrokeCap.round;

    final step = math.max(1, (particles.length / maxParticles).ceil());
    for (var index = 0; index < particles.length; index += step) {
      final particle = particles[index];
      final target = Offset(
        cardRect.left + particle.x * cardRect.width,
        cardRect.top + particle.y * cardRect.height,
      );
      final sample = _sampleFor(
        particle: particle,
        index: index,
        target: target,
        center: stageCenter,
        size: size,
        progress: progress,
      );
      if (sample.local <= 0) continue;
      final wobble = Offset(
        math.sin(index * 1.71 + progress * 18 + particle.phase) *
            (1 - sample.local) *
            10,
        math.cos(index * 1.19 + progress * 16 + particle.phase) *
            (1 - sample.local) *
            8,
      );
      final point = Offset.lerp(sample.origin, target, sample.local)! + wobble;
      final alpha = fade * sample.visibility * (.38 + particle.depth * .62);
      if (alpha <= .01) continue;
      final radius = particle.size * (1.0 + (1 - sample.local) * 1.42);
      final color = _particleColor(particle, index);

      if (index % 21 == 0 && sample.local < .96) {
        final tail = Offset.lerp(sample.origin, point, .72)!;
        trail
          ..strokeWidth = radius * (1.15 + particle.depth)
          ..color = color.withValues(alpha: alpha * .28);
        canvas.drawLine(tail, point, trail);
      }
      if (index % 48 == 0) {
        glow.color = color.withValues(alpha: alpha * .42);
        canvas.drawCircle(point, radius * (3.2 + particle.depth * 2), glow);
      }
      core.color = color.withValues(alpha: alpha);
      if (effect == CardVisualEffect.shards && index % 61 == 0) {
        final shardRadius = radius * (5.5 + particle.depth * 5.5);
        final angle = particle.angle + progress * (1 - sample.local) * 3.4;
        final shard = Path()
          ..moveTo(
            point.dx + math.cos(angle) * shardRadius,
            point.dy + math.sin(angle) * shardRadius,
          )
          ..lineTo(
            point.dx + math.cos(angle + 2.2) * shardRadius * .74,
            point.dy + math.sin(angle + 2.2) * shardRadius * .74,
          )
          ..lineTo(
            point.dx + math.cos(angle + 4.2) * shardRadius * .9,
            point.dy + math.sin(angle + 4.2) * shardRadius * .9,
          )
          ..close();
        canvas.drawPath(
          shard,
          core..color = color.withValues(alpha: alpha * .58),
        );
        continue;
      }
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: radius * 1.85,
          height: radius * 1.85,
        ),
        core,
      );
    }

    _paintLock(canvas, cardRect, progress, fade);
  }

  _ReconstructionSample _sampleFor({
    required _PixelParticle particle,
    required int index,
    required Offset target,
    required Offset center,
    required Size size,
    required double progress,
  }) {
    final vector = target - center;
    final angle = math.atan2(vector.dy, vector.dx);
    final distance = vector.distance;
    late final Offset origin;
    late final double cue;
    late final double duration;
    switch (effect) {
      case CardVisualEffect.shards:
        cue = particle.depth * .25;
        duration = .72;
        final explosion = size.width * (.42 + particle.depth * .92) + distance;
        final burstAngle =
            angle +
            math.sin(particle.phase * 3 + index * .09) * .62 +
            math.pi * .12;
        origin =
            center +
            Offset(math.cos(burstAngle), math.sin(burstAngle) * .72) *
                explosion;
      case CardVisualEffect.scanReveal:
        cue = particle.y * .44 + particle.x * .12;
        duration = .48;
        final scanY = center.dy - size.height * .5 + cue * size.height * 1.08;
        origin = Offset(
          target.dx + math.sin(particle.phase * 2 + index) * size.width * .26,
          scanY + math.cos(particle.phase + index) * 34,
        );
      case CardVisualEffect.foldReveal:
        cue = particle.depth * .18;
        duration = .68;
        final fold = ((particle.x * 3).floor() - 1).toDouble();
        final crease = center.dx + fold * cardSize.width * .22;
        origin = Offset(
          crease + (target.dx - crease) * .08,
          center.dy +
              (target.dy - center.dy) * .16 -
              math.sin(particle.phase + index) * size.height * .28,
        );
      case CardVisualEffect.photoEtch:
        cue =
            (distance / (cardSize.width * .62)).clamp(0.0, 1.0) * .34 +
            particle.depth * .1;
        duration = .58;
        final radius = size.width * (.38 + particle.depth * .5);
        final beamAngle = angle + math.sin(index * .13 + particle.phase) * .28;
        origin =
            center +
            Offset(math.cos(beamAngle), math.sin(beamAngle) * .62) * radius;
      case CardVisualEffect.liquidCast:
        cue = particle.depth * .18;
        duration = .72;
        final spiralAngle =
            particle.angle - progress * math.pi * 2.8 + particle.phase * .7;
        final radius = size.width * (.34 + particle.depth * .8);
        origin =
            center +
            Offset(math.cos(spiralAngle), math.sin(spiralAngle) * .58) * radius;
      case CardVisualEffect.bandAlign:
        cue = particle.depth * .22 + (particle.y * 5).floor() % 2 * .07;
        duration = .63;
        final direction = ((particle.y * 5).floor().isEven) ? -1.0 : 1.0;
        origin = Offset(
          center.dx + direction * size.width * (.42 + particle.depth * .3),
          target.dy +
              math.sin(particle.phase * 2 + progress * 7) *
                  cardSize.height *
                  .4,
        );
      default:
        cue = 0;
        duration = 1;
        origin = target;
    }
    final local = _easeOutCubic(((progress - cue) / duration).clamp(0.0, 1.0));
    final visibility = ((progress - cue + .12) / .22).clamp(0.0, 1.0);
    return _ReconstructionSample(
      origin: origin,
      local: local,
      visibility: visibility,
    );
  }

  Color _particleColor(_PixelParticle particle, int index) {
    if (index % 17 != 0) return particle.color;
    return Color.lerp(particle.color, switch (effect) {
      CardVisualEffect.scanReveal => const Color(0xFF90F8FF),
      CardVisualEffect.photoEtch => const Color(0xFFFFD66D),
      CardVisualEffect.liquidCast => const Color(0xFFFFA4E9),
      CardVisualEffect.bandAlign => const Color(0xFF9CBAFF),
      _ => Colors.white,
    }, .58)!;
  }

  void _paintField(
    Canvas canvas,
    Size size,
    Rect cardRect,
    double progress,
    double fade,
  ) {
    final center = cardRect.center;
    final energy = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    energy.color = tint.withValues(alpha: .18 * fade);
    canvas.drawCircle(center, cardSize.width * (.18 + progress * .62), energy);
    final line = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (effect) {
      case CardVisualEffect.shards:
        for (var ring = 0; ring < 3; ring++) {
          final phase = (progress + ring * .17) % 1;
          line
            ..strokeWidth = 1.1 + (1 - phase) * 2.2
            ..color = Color.lerp(
              tint,
              Colors.white,
              ring / 3,
            )!.withValues(alpha: (1 - phase) * .44 * fade);
          canvas.drawCircle(
            center,
            cardSize.width * (.12 + phase * 1.32),
            line,
          );
        }
      case CardVisualEffect.scanReveal:
        final y = center.dy - size.height * .52 + progress * size.height * 1.04;
        final scanGlow = Paint()
          ..blendMode = BlendMode.screen
          ..strokeWidth = 18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
          ..color = tint.withValues(alpha: .42 * fade);
        line
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: .9 * fade);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanGlow);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        for (var index = 0; index < 4; index++) {
          final offset = (index - 1.5) * 12;
          canvas.drawLine(
            Offset(size.width * .12, y + offset),
            Offset(size.width * .88, y + offset),
            line..color = tint.withValues(alpha: .18 * fade),
          );
        }
      case CardVisualEffect.foldReveal:
        for (var fold = -1; fold <= 1; fold++) {
          final x = center.dx + fold * cardSize.width * .24;
          final path = Path()
            ..moveTo(x, center.dy)
            ..lineTo(x - size.width * .4, -size.height * .08)
            ..lineTo(x + size.width * .4, size.height * 1.08)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.screen
              ..color = tint.withValues(alpha: .055 * fade),
          );
          canvas.drawLine(
            Offset(x, center.dy - cardSize.height * .72),
            Offset(x, center.dy + cardSize.height * .72),
            line
              ..strokeWidth = 2.2
              ..color = Colors.white.withValues(alpha: .46 * fade),
          );
        }
      case CardVisualEffect.photoEtch:
        for (var ring = 0; ring < 5; ring++) {
          final phase = (progress * 1.25 + ring * .19) % 1;
          line
            ..strokeWidth = 1.2
            ..color = Color.lerp(
              tint,
              const Color(0xFFFFD66D),
              ring / 5,
            )!.withValues(alpha: (1 - phase) * .38 * fade);
          canvas.drawOval(
            Rect.fromCenter(
              center: center,
              width: cardSize.width * (.12 + phase * 1.72),
              height: cardSize.height * (.12 + phase * 1.72),
            ),
            line,
          );
        }
      case CardVisualEffect.liquidCast:
        canvas.save();
        canvas.translate(center.dx, center.dy);
        for (var swirl = 0; swirl < 13; swirl++) {
          final angle = progress * math.pi * 4 + swirl * math.pi / 6.5;
          final radius = cardSize.width * (.18 + swirl * .075);
          final arc = Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2,
            height: radius * 1.08,
          );
          line
            ..strokeWidth = 1.2 + swirl % 3
            ..color = Color.lerp(
              tint,
              const Color(0xFFFFB0E8),
              swirl / 13,
            )!.withValues(alpha: .31 * fade);
          canvas.drawArc(arc, angle, 1.55, false, line);
        }
        canvas.restore();
      case CardVisualEffect.bandAlign:
        for (var band = 0; band < 7; band++) {
          final y = cardRect.top + cardRect.height * (band + .5) / 7;
          final wave = Path()..moveTo(-size.width * .12, y);
          for (var segment = 1; segment <= 5; segment++) {
            final x = size.width * segment / 5;
            wave.quadraticBezierTo(
              x - size.width * .1,
              y +
                  math.sin(progress * 9 + band + segment) *
                      cardSize.height *
                      .24,
              x,
              y,
            );
          }
          line
            ..strokeWidth = 1.05 + band % 2
            ..color = Color.lerp(
              tint,
              const Color(0xFF9AFAFF),
              band / 7,
            )!.withValues(alpha: .36 * fade);
          canvas.drawPath(wave, line);
        }
      default:
        break;
    }
  }

  void _paintLock(Canvas canvas, Rect cardRect, double progress, double fade) {
    if (progress < .62) return;
    final lock = _interval(progress, .62, .9);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 + (1 - lock) * 3.2
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          tint.withValues(alpha: .76 * fade * (1 - lock * .4)),
          Colors.white.withValues(alpha: .9 * fade * (1 - lock * .4)),
          Colors.transparent,
        ],
      ).createShader(cardRect.inflate(12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.inflate(3), const Radius.circular(24)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _CardReconstructionPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.effect != effect ||
      oldDelegate.entrance != entrance ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize ||
      oldDelegate.maxParticles != maxParticles;
}

class _ReconstructionSample {
  const _ReconstructionSample({
    required this.origin,
    required this.local,
    required this.visibility,
  });

  final Offset origin;
  final double local;
  final double visibility;
}

class _PerimeterFlamePainter extends CustomPainter {
  const _PerimeterFlamePainter({
    required this.entrance,
    required this.idle,
    required this.cardSize,
  });

  final double entrance;
  final double idle;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final enter = _easeOutCubic(entrance);
    if (enter <= 0) return;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    // The old halo circles made the fire read like four orange spotlights.
    // Keep only a thin heat line and let the irregular flame tongues define
    // the silhouette of the card.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFFFF7A19).withValues(alpha: .42 * enter)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final random = math.Random(904);
    final phase = idle * math.pi * 2;
    final outerFlame = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final innerFlame = Paint()..blendMode = BlendMode.screen;
    final ember = Paint()..blendMode = BlendMode.screen;
    final emberGlow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var index = 0; index < 70; index++) {
      final seed = random.nextDouble();
      final along = random.nextDouble();
      final particlePhase = random.nextDouble();
      final speed = .55 + random.nextDouble() * .95;
      final age = (idle * speed + particlePhase) % 1;
      late Offset base;
      late Offset normal;
      late Offset tangent;
      if (seed < .34) {
        base = Offset(rect.left + along * rect.width, rect.top);
        normal = const Offset(0, -1);
        tangent = const Offset(1, 0);
      } else if (seed < .62) {
        base = Offset(rect.left + along * rect.width, rect.bottom);
        normal = const Offset(0, 1);
        tangent = const Offset(1, 0);
      } else if (seed < .81) {
        base = Offset(rect.left, rect.top + along * rect.height);
        normal = const Offset(-1, 0);
        tangent = const Offset(0, 1);
      } else {
        base = Offset(rect.right, rect.top + along * rect.height);
        normal = const Offset(1, 0);
        tangent = const Offset(0, 1);
      }
      final heat = .45 + random.nextDouble() * .85;
      final rise = math.pow(age, .60).toDouble() * (14 + heat * 42);
      final wobble =
          math.sin(phase * (1.4 + heat * .34) + particlePhase * 18) *
          (3 + heat * 5.6);
      final life = math.sin(age * math.pi).clamp(0.0, 1.0);
      if (life <= 0) continue;
      final outerColor = Color.lerp(
        const Color(0xFFF53605),
        const Color(0xFFFF9C1A),
        (heat - .45).clamp(0.0, 1.0),
      )!;
      final width = 3.6 + heat * 5.8;
      final tip = base + normal * rise + tangent * wobble;
      final left = base - tangent * width;
      final right = base + tangent * width;
      final flame = Path()
        ..moveTo(left.dx, left.dy)
        ..cubicTo(
          (base + normal * (rise * .35) - tangent * width * .88).dx,
          (base + normal * (rise * .35) - tangent * width * .88).dy,
          (tip - normal * (rise * .36) - tangent * width * .22).dx,
          (tip - normal * (rise * .36) - tangent * width * .22).dy,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          (tip - normal * (rise * .24) + tangent * width * .78).dx,
          (tip - normal * (rise * .24) + tangent * width * .78).dy,
          (base + normal * (rise * .22) + tangent * width * .70).dx,
          (base + normal * (rise * .22) + tangent * width * .70).dy,
          right.dx,
          right.dy,
        )
        ..close();
      outerFlame.color = outerColor.withValues(alpha: life * .42 * enter);
      canvas.drawPath(flame, outerFlame);
      innerFlame.color = const Color(
        0xFFFFE36A,
      ).withValues(alpha: life * (.42 + heat * .22) * enter);
      final innerTip = Offset.lerp(base, tip, .68)!;
      canvas.drawPath(
        Path()
          ..moveTo(
            (base - tangent * width * .42).dx,
            (base - tangent * width * .42).dy,
          )
          ..quadraticBezierTo(
            innerTip.dx,
            innerTip.dy,
            (base + tangent * width * .42).dx,
            (base + tangent * width * .42).dy,
          )
          ..close(),
        innerFlame,
      );

      if (index % 3 == 0) {
        final emberPoint = tip + normal * (4 + heat * 14);
        final emberRadius = .6 + heat * 1.25;
        emberGlow.color = outerColor.withValues(alpha: life * .34 * enter);
        ember.color = const Color(
          0xFFFFD762,
        ).withValues(alpha: life * .88 * enter);
        canvas.drawCircle(emberPoint, emberRadius * 2.8, emberGlow);
        canvas.drawCircle(emberPoint, emberRadius, ember);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerimeterFlamePainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.cardSize != cardSize;
}

class _FireworkPainter extends CustomPainter {
  const _FireworkPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
    required this.cardSize,
  });

  final double entrance;
  final double idle;
  final Color tint;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (entrance <= 0) return;
    final stage = Rect.fromLTWH(0, 0, size.width, size.height);
    const openingBursts = <_BurstCue>[
      _BurstCue(.12, .31, .02, 1.18),
      _BurstCue(.35, .12, .10, 1.00),
      _BurstCue(.61, .23, .18, 1.30),
      _BurstCue(.85, .12, .26, 1.06),
      _BurstCue(.91, .46, .34, 1.24),
      _BurstCue(.18, .69, .42, 1.12),
      _BurstCue(.48, .79, .50, 1.38),
      _BurstCue(.74, .67, .58, 1.08),
      _BurstCue(.37, .43, .66, .96),
    ];
    for (var index = 0; index < openingBursts.length; index++) {
      final cue = openingBursts[index];
      final age = ((entrance - cue.start) / .40).clamp(0.0, 1.0);
      if (age <= 0 || age >= 1) continue;
      _paintBurst(
        canvas,
        center: Offset(
          stage.left + stage.width * cue.x,
          stage.top + stage.height * cue.y,
        ),
        age: age,
        scale: cue.scale,
        seed: 700 + index * 97,
        opacity: 1,
      );
    }

    // 开场结束后仍保留低频大烟花，避免效果在卡面出现瞬间戛然而止。
    if (entrance < .58) return;
    const ambientBursts = <_BurstCue>[
      _BurstCue(.18, .22, .08, .72),
      _BurstCue(.79, .32, .28, .84),
      _BurstCue(.53, .74, .48, .70),
      _BurstCue(.30, .56, .68, .64),
      _BurstCue(.88, .72, .82, .78),
    ];
    for (var index = 0; index < ambientBursts.length; index++) {
      final cue = ambientBursts[index];
      final age = ((idle - cue.start) / .26).clamp(0.0, 1.0);
      if (age <= 0 || age >= 1) continue;
      _paintBurst(
        canvas,
        center: Offset(
          stage.left + stage.width * cue.x,
          stage.top + stage.height * cue.y,
        ),
        age: age,
        scale: cue.scale,
        seed: 1700 + index * 71,
        opacity: .76,
      );
    }
  }

  void _paintBurst(
    Canvas canvas, {
    required Offset center,
    required double age,
    required double scale,
    required int seed,
    required double opacity,
  }) {
    final random = math.Random(seed);
    final explode = _easeOutCubic((age / .48).clamp(0.0, 1.0));
    final life = math.sin(age * math.pi).clamp(0.0, 1.0) * opacity;
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final core = Paint()..blendMode = BlendMode.screen;
    for (var index = 0; index < 42; index++) {
      final angle = random.nextDouble() * math.pi * 2;
      final velocity = 34 + random.nextDouble() * 86;
      final distance = velocity * explode * scale;
      final gravity = age * age * 32 * scale;
      final point =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance + gravity,
          );
      final color = Color.lerp(tint, switch (index % 4) {
        0 => const Color(0xFFFFD46A),
        1 => const Color(0xFF7CF8E0),
        2 => const Color(0xFFFF8FE6),
        _ => Colors.white,
      }, .52 + random.nextDouble() * .48)!;
      final alpha = life * (.44 + random.nextDouble() * .56);
      final radius = (.8 + random.nextDouble() * 1.9) * (1.18 - age * .36);
      glow.color = color.withValues(alpha: alpha * .40);
      core.color = color.withValues(alpha: alpha);
      if (index % 5 == 0) canvas.drawCircle(point, radius * 3.4, glow);
      canvas.drawCircle(point, radius, core);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworkPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize;
}

class _BurstCue {
  const _BurstCue(this.x, this.y, this.start, this.scale);

  final double x;
  final double y;
  final double start;
  final double scale;
}

class _PrismPainter extends CustomPainter {
  const _PrismPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
    required this.cardSize,
  });

  final double entrance;
  final double idle;
  final Color tint;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    final alpha = _easeOutCubic(entrance);
    final phase = idle * math.pi * 2;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = LinearGradient(
        colors: [
          tint.withValues(alpha: .05),
          const Color(0xFF92F6FF).withValues(alpha: .82 * alpha),
          const Color(0xFFFF9AE2).withValues(alpha: .72 * alpha),
          tint.withValues(alpha: .05),
        ],
        transform: GradientRotation(phase * .24),
      ).createShader(rect.inflate(12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(5), const Radius.circular(26)),
      outline,
    );
    final streak = Paint()
      ..blendMode = BlendMode.screen
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: .34 * alpha);
    for (var index = -3; index <= 4; index++) {
      final offset = (index * 46.0 + idle * 112) % (rect.width + 92) - 46;
      canvas.drawLine(
        Offset(rect.left + offset, rect.bottom),
        Offset(rect.left + offset + 58, rect.top),
        streak,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PrismPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint;
}

class _CardSurfaceFireworkPainter extends CustomPainter {
  const _CardSurfaceFireworkPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
  });

  final double entrance;
  final double idle;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (entrance <= .26) return;
    const openingBursts = <_BurstCue>[
      _BurstCue(.23, .28, .34, .62),
      _BurstCue(.70, .35, .49, .72),
      _BurstCue(.48, .66, .64, .58),
      _BurstCue(.82, .20, .76, .45),
    ];
    for (var index = 0; index < openingBursts.length; index++) {
      final cue = openingBursts[index];
      final age = ((entrance - cue.start) / .23).clamp(0.0, 1.0);
      if (age <= 0 || age >= 1) continue;
      _paintBurst(
        canvas,
        center: Offset(size.width * cue.x, size.height * cue.y),
        age: age,
        scale: cue.scale,
        seed: 3400 + index * 41,
        opacity: 1,
      );
    }
    if (entrance < .58) return;
    const ambientBursts = <_BurstCue>[
      _BurstCue(.19, .61, .12, .42),
      _BurstCue(.72, .22, .37, .48),
      _BurstCue(.49, .49, .62, .38),
      _BurstCue(.84, .74, .84, .44),
    ];
    for (var index = 0; index < ambientBursts.length; index++) {
      final cue = ambientBursts[index];
      final age = ((idle - cue.start) / .18).clamp(0.0, 1.0);
      if (age <= 0 || age >= 1) continue;
      _paintBurst(
        canvas,
        center: Offset(size.width * cue.x, size.height * cue.y),
        age: age,
        scale: cue.scale,
        seed: 3900 + index * 61,
        opacity: .80,
      );
    }
  }

  void _paintBurst(
    Canvas canvas, {
    required Offset center,
    required double age,
    required double scale,
    required int seed,
    required double opacity,
  }) {
    final random = math.Random(seed);
    final explode = _easeOutCubic((age / .42).clamp(0.0, 1.0));
    final life = math.sin(age * math.pi).clamp(0.0, 1.0) * opacity;
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    final core = Paint()..blendMode = BlendMode.screen;
    for (var index = 0; index < 22; index++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = (14 + random.nextDouble() * 35) * explode * scale;
      final point =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance + age * age * 8,
          );
      final color = Color.lerp(
        tint,
        index.isEven ? const Color(0xFFFFD46A) : Colors.white,
        .64 + random.nextDouble() * .36,
      )!;
      final alpha = life * (.48 + random.nextDouble() * .52);
      final radius = (.55 + random.nextDouble() * 1.28) * (1.12 - age * .28);
      glow.color = color.withValues(alpha: alpha * .44);
      core.color = color.withValues(alpha: alpha);
      if (index % 5 == 0) canvas.drawCircle(point, radius * 3, glow);
      canvas.drawCircle(point, radius, core);
    }
  }

  @override
  bool shouldRepaint(covariant _CardSurfaceFireworkPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint;
}

class _SupernovaPainter extends CustomPainter {
  const _SupernovaPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
    required this.cardSize,
  });

  final double entrance;
  final double idle;
  final Color tint;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    if (reveal <= 0) return;
    final center = size.center(Offset.zero);
    final fieldRadius = math.max(cardSize.width, cardSize.height) * .92;
    final pulse = .82 + math.sin(idle * math.pi * 4) * .18;
    final shock = Paint()
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (var ring = 0; ring < 3; ring++) {
      final phase = (idle + ring * .27) % 1;
      final radius = fieldRadius * (.36 + phase * .92) * reveal;
      shock
        ..strokeWidth = 1.1 + (1 - phase) * 2.4
        ..color = Color.lerp(
          tint,
          const Color(0xFF9EF7FF),
          ring / 2,
        )!.withValues(alpha: (1 - phase) * .26 * reveal);
      canvas.drawCircle(center, radius, shock);
    }

    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()
      ..blendMode = BlendMode.screen
      ..strokeCap = StrokeCap.round;
    final random = math.Random(8821);
    for (var index = 0; index < 176; index++) {
      final arm = index % 4;
      final depth = random.nextDouble();
      final speed = .42 + random.nextDouble() * .88;
      final phase = (idle * speed + random.nextDouble()) % 1;
      final radius = (34 + depth * fieldRadius * 1.18) * (1.04 - phase * .16);
      final angle =
          arm * math.pi / 2 +
          phase * math.pi * (1.45 + depth * .95) +
          depth * 3.7;
      final stretch = .62 + depth * .28;
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * stretch);
      final tail =
          center +
          Offset(
            math.cos(angle - .11) * (radius - 13 * pulse),
            math.sin(angle - .11) * (radius - 13 * pulse) * stretch,
          );
      final color = Color.lerp(tint, switch (index % 5) {
        0 => const Color(0xFF96F8FF),
        1 => const Color(0xFFFF8FE7),
        2 => const Color(0xFFFFD66D),
        _ => Colors.white,
      }, .46 + depth * .54)!;
      final alpha = reveal * (.24 + depth * .66) * (1 - phase * .22);
      core
        ..strokeWidth = .65 + depth * 1.65
        ..color = color.withValues(alpha: alpha * .76);
      if (index % 2 == 0) canvas.drawLine(tail, point, core);
      glow.color = color.withValues(alpha: alpha * .32);
      if (index % 4 == 0) canvas.drawCircle(point, 2.5 + depth * 3.4, glow);
      core.color = color.withValues(alpha: alpha);
      canvas.drawCircle(point, .7 + depth * 1.6, core);
    }
  }

  @override
  bool shouldRepaint(covariant _SupernovaPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize;
}

class _CardSurfaceSupernovaPainter extends CustomPainter {
  const _CardSurfaceSupernovaPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
  });

  final double entrance;
  final double idle;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    if (reveal <= 0) return;
    final center = size.center(Offset.zero);
    final random = math.Random(941);
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..blendMode = BlendMode.screen
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 92; index++) {
      final depth = random.nextDouble();
      final phase =
          (idle * (.72 + random.nextDouble() * .82) + random.nextDouble()) % 1;
      final angle = phase * math.pi * 2 + depth * 8.8;
      final radius =
          (size.shortestSide * (.06 + depth * .66)) * (1 - phase * .12);
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .56);
      final tail =
          point -
          Offset(
            math.cos(angle) * (4 + depth * 12),
            math.sin(angle) * (4 + depth * 12) * .56,
          );
      final color = Color.lerp(
        tint,
        index.isEven ? const Color(0xFFB6FAFF) : const Color(0xFFFFB4EA),
        .56 + depth * .44,
      )!;
      final alpha = reveal * (.12 + depth * .34) * (1 - phase * .28);
      core
        ..strokeWidth = .45 + depth
        ..color = color.withValues(alpha: alpha);
      canvas.drawLine(tail, point, core);
      if (index % 3 == 0) {
        glow.color = color.withValues(alpha: alpha * .46);
        canvas.drawCircle(point, 2 + depth * 2.4, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardSurfaceSupernovaPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint;
}

class _MagneticFluxPainter extends CustomPainter {
  const _MagneticFluxPainter({
    required this.entrance,
    required this.idle,
    required this.tint,
    required this.cardSize,
    required this.pointer,
    required this.active,
  });

  final double entrance;
  final double idle;
  final Color tint;
  final Size cardSize;
  final Alignment pointer;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    if (reveal <= 0) return;
    final cardRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    final magnet = Offset(
      cardRect.center.dx + pointer.x * cardRect.width * .42,
      cardRect.center.dy + pointer.y * cardRect.height * .42,
    );
    final random = math.Random(5728);
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..blendMode = BlendMode.screen
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 56; index++) {
      final seed = random.nextDouble();
      final phase = (idle * (.48 + random.nextDouble() * .95) + seed) % 1;
      final angle = seed * math.pi * 2 + phase * math.pi * 2.25;
      final radius =
          cardSize.width *
          (.26 + random.nextDouble() * .74) *
          (active ? .76 : 1);
      final orbit =
          magnet +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .64);
      final burst =
          size.center(Offset.zero) +
          Offset(
            math.cos(seed * 31) *
                size.width *
                (.42 + random.nextDouble() * .46),
            math.sin(seed * 19) *
                size.height *
                (.32 + random.nextDouble() * .48),
          );
      final point = Offset.lerp(burst, orbit, reveal)!;
      final tail = Offset.lerp(point, magnet, active ? .18 : .09)!;
      final color = Color.lerp(
        tint,
        index.isEven ? const Color(0xFF8FFAFF) : const Color(0xFFFFB0EA),
        .52 + random.nextDouble() * .48,
      )!;
      final alpha = reveal * (.26 + random.nextDouble() * .58);
      core
        ..strokeWidth = .55 + random.nextDouble() * 1.35
        ..color = color.withValues(alpha: alpha * .72);
      if (index.isEven) canvas.drawLine(tail, point, core);
      if (index % 8 == 0) {
        glow.color = color.withValues(alpha: alpha * .34);
        canvas.drawCircle(point, 3.2, glow);
      }
      core.color = color.withValues(alpha: alpha);
      canvas.drawCircle(point, .7 + random.nextDouble() * 1.35, core);
    }
  }

  @override
  bool shouldRepaint(covariant _MagneticFluxPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize ||
      oldDelegate.pointer != pointer ||
      oldDelegate.active != active;
}

class _MagneticSurfacePainter extends CustomPainter {
  const _MagneticSurfacePainter({
    required this.entrance,
    required this.idle,
    required this.tint,
    required this.pointer,
    required this.active,
  });

  final double entrance;
  final double idle;
  final Color tint;
  final Alignment pointer;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    final magnet = Offset(
      size.width * (.5 + pointer.x * .34),
      size.height * (.5 + pointer.y * .34),
    );
    final random = math.Random(814);
    final core = Paint()..blendMode = BlendMode.screen;
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var index = 0; index < 26; index++) {
      final seed = random.nextDouble();
      final phase = (idle * (.7 + random.nextDouble()) + seed) % 1;
      final angle = seed * math.pi * 2 + phase * math.pi * 1.8;
      final radius = size.shortestSide * (.12 + random.nextDouble() * .52);
      final point =
          magnet +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .62);
      final color = Color.lerp(
        tint,
        Colors.white,
        .48 + random.nextDouble() * .42,
      )!;
      final alpha = reveal * (active ? .66 : .34) * (1 - phase * .28);
      core
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = .6 + random.nextDouble();
      canvas.drawLine(Offset.lerp(point, magnet, .12)!, point, core);
      if (index % 8 == 0) {
        glow.color = color.withValues(alpha: alpha * .44);
        canvas.drawCircle(point, 3, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MagneticSurfacePainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.tint != tint ||
      oldDelegate.pointer != pointer ||
      oldDelegate.active != active;
}

class _LiquidMetalAuraPainter extends CustomPainter {
  const _LiquidMetalAuraPainter({
    required this.entrance,
    required this.tint,
    required this.cardSize,
  });

  final double entrance;
  final Color tint;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    // Sweep the metallic seam in during the entry animation, then lock it.
    // This is intentionally not driven by pointer movement.
    final wave = math.sin(entrance * math.pi * 2.4) * 18 * (1 - reveal);
    final sweep = (1 - reveal) * cardSize.width * .72;
    final path = Path()
      ..moveTo(rect.left - 18 - sweep, rect.top + cardSize.height * .25)
      ..cubicTo(
        rect.left + cardSize.width * .22 - sweep * .32,
        rect.top - 24 + wave,
        rect.right - cardSize.width * .18,
        rect.bottom + 20 - wave,
        rect.right + 18,
        rect.bottom - cardSize.height * .22,
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFEAF7FF).withValues(alpha: .72 * reveal),
          tint.withValues(alpha: .64 * reveal),
          Colors.transparent,
        ],
      ).createShader(rect.inflate(28));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidMetalAuraPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize;
}

class _LiquidMetalSurfacePainter extends CustomPainter {
  const _LiquidMetalSurfacePainter({
    required this.entrance,
    required this.tint,
  });

  final double entrance;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    // The liquid mass pours in from the upper-right and settles at centre.
    // Both the position and pulse are entrance-only, so the effect does not
    // ask the user to drag across the card.
    final center = Offset.lerp(
      Offset(size.width * 1.18, size.height * .18),
      size.center(Offset.zero),
      reveal,
    )!;
    final pulse = .78 + math.sin(entrance * math.pi * 2.2) * .20 * (1 - reveal);
    final radius = size.shortestSide * (.28 + pulse * .18);
    final sheen = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .38 * reveal),
          tint.withValues(alpha: .16 * reveal),
          Colors.transparent,
        ],
        stops: const [0, .36, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2.5,
        height: radius * .74,
      ),
      sheen,
    );
    final waveY =
        center.dy +
        math.sin(entrance * math.pi * 2.1) * size.height * .11 * (1 - reveal);
    final ribbon = Path()
      ..moveTo(0, waveY - 10)
      ..cubicTo(
        size.width * .26,
        waveY - 35,
        size.width * .62,
        waveY + 32,
        size.width,
        waveY - 6,
      )
      ..lineTo(size.width, waveY + 8)
      ..cubicTo(
        size.width * .62,
        waveY + 48,
        size.width * .26,
        waveY - 18,
        0,
        waveY + 16,
      )
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: .18 * reveal),
            tint.withValues(alpha: .16 * reveal),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidMetalSurfacePainter oldDelegate) =>
      oldDelegate.entrance != entrance || oldDelegate.tint != tint;
}

class _SpaceFoldFieldPainter extends CustomPainter {
  const _SpaceFoldFieldPainter({
    required this.entrance,
    required this.tint,
    required this.cardSize,
  });

  final double entrance;
  final Color tint;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    // The fold collapses from outside the frame to the card centre during
    // entry; no pointer tracking is involved.
    final fold = Offset.lerp(
      Offset(rect.right + rect.width * .30, rect.top - rect.height * .18),
      rect.center,
      reveal,
    )!;
    final glow = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = tint.withValues(alpha: .34 * reveal);
    for (var index = 0; index < 5; index++) {
      final offset = 38 + (1 - reveal) * 104 + index * 8;
      final shard = Path()
        ..moveTo(fold.dx, fold.dy)
        ..lineTo(rect.left - offset, rect.top + index * rect.height * .22)
        ..lineTo(rect.left + rect.width * .22, rect.bottom + offset * .18)
        ..close();
      canvas.drawPath(shard, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceFoldFieldPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.tint != tint ||
      oldDelegate.cardSize != cardSize;
}

class _SpaceFoldSurfacePainter extends CustomPainter {
  const _SpaceFoldSurfacePainter({required this.entrance, required this.tint});

  final double entrance;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = _easeOutCubic(entrance);
    final fold = Offset.lerp(
      Offset(size.width * 1.12, -size.height * .10),
      size.center(Offset.zero),
      reveal,
    )!;
    final foldX = fold.dx;
    final leftFold = Path()
      ..moveTo(0, 0)
      ..lineTo(fold.dx, fold.dy)
      ..lineTo(0, size.height)
      ..close();
    final rightFold = Path()
      ..moveTo(size.width, 0)
      ..lineTo(fold.dx, fold.dy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      leftFold,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: .10 * reveal),
            tint.withValues(alpha: .02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      rightFold,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: .14 * reveal),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
    final crease = Paint()
      ..blendMode = BlendMode.screen
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: .78 * reveal),
          tint.withValues(alpha: .72 * reveal),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawLine(Offset(foldX, 0), fold, crease);
    canvas.drawLine(fold, Offset(foldX, size.height), crease);
  }

  @override
  bool shouldRepaint(covariant _SpaceFoldSurfacePainter oldDelegate) =>
      oldDelegate.entrance != entrance || oldDelegate.tint != tint;
}

class _EmptyPainter extends CustomPainter {
  const _EmptyPainter();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) => false;
}
