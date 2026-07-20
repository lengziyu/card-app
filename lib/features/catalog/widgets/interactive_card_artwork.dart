import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/material.dart';

enum CardVisualEffect { particle, flame, ice, none }

class InteractiveCardArtwork extends StatefulWidget {
  const InteractiveCardArtwork({
    required this.card,
    this.effect = CardVisualEffect.particle,
    super.key,
  });

  final CardSummary card;
  final CardVisualEffect effect;

  @override
  State<InteractiveCardArtwork> createState() => _InteractiveCardArtworkState();
}

class _InteractiveCardArtworkState extends State<InteractiveCardArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _idleController;
  late final AnimationController _glassSweepController;
  final List<_PixelParticle> _pixels = [];

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Object? _loadedImageKey;
  double _rotateX = 0;
  double _rotateY = 0;
  Alignment _shineAlignment = Alignment.topLeft;
  Offset? _pointerDown;
  bool _pressed = false;
  bool _didMove = false;
  bool? _lastReduceMotion;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCardPixels();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_lastReduceMotion != reduceMotion) {
      _lastReduceMotion = reduceMotion;
      _startEffect();
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
    if (oldWidget.effect != widget.effect) _startEffect();
  }

  bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  void _startEffect() {
    final reduceMotion = _lastReduceMotion ?? false;
    _entranceController.stop();
    _idleController.stop();
    if (widget.effect == CardVisualEffect.none) {
      _entranceController.value = 1;
      _idleController.value = 0;
      return;
    }
    if (reduceMotion || _isWidgetTest) {
      _entranceController.value = 1;
      _idleController.value = .24;
      return;
    }
    _entranceController.forward(from: 0);
    if (widget.effect == CardVisualEffect.flame ||
        widget.effect == CardVisualEffect.ice) {
      _idleController
        ..value = 0
        ..repeat();
    } else {
      _idleController.value = .18;
    }
  }

  void _configureGlassSweep() {
    if ((_lastReduceMotion ?? false) || _isWidgetTest) {
      _glassSweepController.value = .42;
      return;
    }
    if (!_glassSweepController.isAnimating) {
      _glassSweepController.repeat();
    }
  }

  void _replayEffect() {
    if (widget.effect == CardVisualEffect.none ||
        (_lastReduceMotion ?? false) ||
        _isWidgetTest) {
      return;
    }
    _entranceController.forward(from: 0);
    if (widget.effect == CardVisualEffect.flame &&
        !_idleController.isAnimating) {
      _idleController
        ..value = 0
        ..repeat();
    }
  }

  ImageProvider<Object>? _imageProvider() {
    final imageUrl = widget.card.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(imageUrl);
    }
    final assetPath = widget.card.assetPath;
    if (assetPath != null && assetPath.isNotEmpty) {
      return AssetImage(assetPath);
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
      _shineAlignment = Alignment.topLeft;
      _pressed = false;
      _pointerDown = null;
    });
    if (replay && !_didMove) _replayEffect();
    _didMove = false;
  }

  @override
  void dispose() {
    _detachImageListener();
    _entranceController.dispose();
    _idleController.dispose();
    _glassSweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = Size(constraints.maxWidth, constraints.maxHeight);
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
                  CardVisualEffect.ice => _interval(entrance, .18, .58),
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
                            maxWidth: cardSize.width * 1.62,
                            maxHeight: cardSize.height * 2.08,
                            child: SizedBox(
                              width: cardSize.width * 1.62,
                              height: cardSize.height * 2.08,
                              child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
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
                                child: CustomPaint(
                                  painter: _effectPainter(
                                    entrance: entrance,
                                    idle: _idleController.value,
                                    cardSize: cardSize,
                                  ),
                                ),
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
                            borderRadius: BorderRadius.circular(22),
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
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CardArtwork(card: widget.card),
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
                                    borderRadius: BorderRadius.circular(22),
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
    CardVisualEffect.ice => _IcePainter(
      entrance: entrance,
      idle: idle,
      cardSize: cardSize,
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

    final environment = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    final glowCenters = <(Offset, Color, double)>[
      (Offset(rect.left, rect.top), const Color(0xD9FF3B00), 54),
      (Offset(rect.right, rect.top), const Color(0xD9FFD729), 62),
      (Offset(rect.left, rect.bottom), const Color(0xD9FF7A00), 68),
      (Offset(rect.right, rect.bottom), const Color(0xD9FFF055), 62),
    ];
    for (final glow in glowCenters) {
      environment.color = glow.$2.withValues(alpha: glow.$2.a * enter);
      canvas.drawCircle(glow.$1, glow.$3, environment);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = const Color(0xCFFF5A0A).withValues(alpha: .78 * enter)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(23)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xE6FFE75A).withValues(alpha: .78 * enter)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final random = math.Random(904);
    final phase = idle * math.pi * 2;
    final core = Paint()..blendMode = BlendMode.screen;
    final aura = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    for (var index = 0; index < 210; index++) {
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
      final rise = math.pow(age, .64).toDouble() * (18 + heat * 34);
      final wobble =
          math.sin(phase * (1.1 + heat * .28) + particlePhase * 18) *
          (2 + heat * 4.2);
      final point = base + normal * rise + tangent * wobble;
      final life = math.sin(age * math.pi).clamp(0.0, 1.0);
      final color = Color.lerp(
        const Color(0xFFF53605),
        const Color(0xFFFFD15A),
        (heat - .45).clamp(0.0, 1.0),
      )!;
      final radius = (1.4 + heat * 2.8) * (1.1 - age * .48);
      aura.color = color.withValues(alpha: life * .38 * enter);
      core.color = color.withValues(alpha: life * .95 * enter);
      if (index % 3 == 0) canvas.drawCircle(point, radius * 2.5, aura);
      canvas.drawCircle(point, radius, core);
    }
  }

  @override
  bool shouldRepaint(covariant _PerimeterFlamePainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.cardSize != cardSize;
}

class _IcePainter extends CustomPainter {
  const _IcePainter({
    required this.entrance,
    required this.idle,
    required this.cardSize,
  });
  final double entrance;
  final double idle;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cardSize.width,
      height: cardSize.height,
    );
    final enter = _easeOutCubic(entrance);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0xFF8CEBFF).withValues(alpha: .52 * enter)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final random = math.Random(63);
    final paint = Paint()..color = const Color(0xA6E8FFFF);
    for (var index = 0; index < 90; index++) {
      final x = rect.left + random.nextDouble() * rect.width;
      final fall =
          (idle * (.7 + random.nextDouble()) + random.nextDouble()) % 1;
      final y = rect.top + fall * rect.height;
      canvas.drawCircle(Offset(x, y), .6 + random.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IcePainter oldDelegate) =>
      oldDelegate.entrance != entrance || oldDelegate.idle != idle;
}

class _EmptyPainter extends CustomPainter {
  const _EmptyPainter();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) => false;
}
