import 'dart:math' as math;
import 'dart:ui';

import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/app_bottom_sheet.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/card_artwork.dart';
import 'package:flutter/gestures.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum _CanvasLayout { compact, gallery }

class CardCanvasPage extends StatefulWidget {
  const CardCanvasPage({
    required this.cards,
    required this.onBack,
    required this.onOpenCard,
    super.key,
  });

  final List<CardSummary> cards;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  State<CardCanvasPage> createState() => _CardCanvasPageState();
}

class _CardCanvasPageState extends State<CardCanvasPage>
    with TickerProviderStateMixin {
  static const _green = Color(0xFF169C65);
  static const _backgroundColors = <Color>[
    Color(0xFF050505),
    Color(0xFFF5F4F1),
    Color(0xFF112240),
    Color(0xFF202124),
    Color(0xFF145734),
    Color(0xFF3D2C5C),
    Color(0xFF5A3030),
  ];

  final TransformationController _transformationController =
      TransformationController();
  late final Ticker _autoPlayTicker;
  late final AnimationController _transformAnimation;
  _CanvasTransform _animationStart = const _CanvasTransform.identity();
  _CanvasTransform _animationTarget = const _CanvasTransform.identity();
  final Map<int, Offset> _pointers = <int, Offset>{};
  Offset? _lastPointer;
  _PinchStart? _pinchStart;
  double _dragDistance = 0;
  DateTime _suppressCardTapUntil = DateTime.fromMillisecondsSinceEpoch(0);

  _CanvasLayout _layout = _CanvasLayout.compact;
  Color _backgroundColor = const Color(0xFFF5F4F1);
  bool _staggered = true;
  bool _autoPlaying = false;
  bool _immersive = false;
  bool _showDotGrid = false;
  double _rotationDegrees = 2.2;
  double _autoPlaySpeed = 48;
  int? _columnsPerRow;
  int _shuffleSeed = 0;
  Offset _autoPlayDirection = const Offset(-1, -1);
  Duration? _lastTick;
  Size _viewportSize = Size.zero;
  Size _canvasSize = Size.zero;
  Rect _cardContentBounds = Rect.zero;
  bool _didPositionCanvas = false;

  @override
  void initState() {
    super.initState();
    _autoPlayTicker = createTicker(_onAutoPlayTick);
    _transformAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(_onTransformAnimationTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _autoPlaying) {
      _stopAutoPlay();
    }
  }

  @override
  void didUpdateWidget(covariant CardCanvasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length) {
      _didPositionCanvas = false;
    }
  }

  @override
  void dispose() {
    _autoPlayTicker.dispose();
    _transformAnimation.dispose();
    _transformationController.dispose();
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  List<CardSummary> get _canvasCards => widget.cards;

  _CanvasMetrics _metricsFor(Size viewport) {
    final cards = _canvasCards;
    final isCompact = _layout == _CanvasLayout.compact;
    final cardWidth = isCompact ? 132.0 : 164.0;
    final cardHeight = cardWidth / 1.586;
    final horizontalGap = isCompact ? 30.0 : 64.0;
    final verticalGap = isCompact ? 34.0 : 80.0;
    final columns =
        _columnsPerRow ??
        _squareColumnsFor(
          cards.length,
          cardWidth + horizontalGap,
          cardHeight + verticalGap,
        );
    final rows = math.max(1, (cards.length / columns).ceil());
    final horizontalMargin = isCompact ? 96.0 : 128.0;
    final verticalMargin = isCompact ? 112.0 : 148.0;
    final width =
        horizontalMargin * 2 +
        columns * cardWidth +
        math.max(0, columns - 1) * horizontalGap;
    final height =
        verticalMargin * 2 +
        rows * cardHeight +
        math.max(0, rows - 1) * verticalGap;
    return _CanvasMetrics(
      canvasSize: Size(width, height),
      cardSize: Size(cardWidth, cardHeight),
      columns: columns,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      horizontalMargin: horizontalMargin,
      verticalMargin: verticalMargin,
    );
  }

  int _squareColumnsFor(int count, double columnExtent, double rowExtent) {
    if (count <= 1) return 1;
    final value = math.sqrt(count * rowExtent / columnExtent).ceil();
    return value.clamp(2, 12);
  }

  void _scheduleInitialPosition(Size viewport, _CanvasMetrics metrics) {
    final canvas = metrics.canvasSize;
    final viewportChanged =
        (_viewportSize.width - viewport.width).abs() > 1 ||
        (_viewportSize.height - viewport.height).abs() > 1;
    final canvasChanged =
        (_canvasSize.width - canvas.width).abs() > 1 ||
        (_canvasSize.height - canvas.height).abs() > 1;
    _viewportSize = viewport;
    _canvasSize = canvas;
    _cardContentBounds = _contentBoundsFor(metrics);
    if (_didPositionCanvas && !viewportChanged && !canvasChanged) return;
    _didPositionCanvas = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetView(stopPlayback: false, haptic: false, animate: false);
    });
  }

  Rect _contentBoundsFor(_CanvasMetrics metrics) {
    if (_canvasCards.isEmpty) return Rect.zero;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (var index = 0; index < _canvasCards.length; index++) {
      final geometry = _cardGeometry(
        index: index,
        metrics: metrics,
        staggered: _staggered,
        rotationDegrees: _rotationDegrees,
        shuffleSeed: _shuffleSeed,
      );
      final cosine = math.cos(geometry.angle).abs();
      final sine = math.sin(geometry.angle).abs();
      final halfWidth =
          (metrics.cardSize.width * cosine + metrics.cardSize.height * sine) /
          2;
      final halfHeight =
          (metrics.cardSize.width * sine + metrics.cardSize.height * cosine) /
          2;
      final center = geometry.offset + metrics.cardSize.center(Offset.zero);
      left = math.min(left, center.dx - halfWidth);
      top = math.min(top, center.dy - halfHeight);
      right = math.max(right, center.dx + halfWidth);
      bottom = math.max(bottom, center.dy + halfHeight);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  _CanvasTransform get _currentTransform =>
      _CanvasTransform.fromMatrix(_transformationController.value);

  _CanvasTransform _clampTransform(_CanvasTransform value) {
    if (_viewportSize.isEmpty || _cardContentBounds.isEmpty) return value;
    final maximumHorizontalBlank = _viewportSize.width * .5 - 2;
    final maximumVerticalBlank = _viewportSize.height * .5 - 2;
    final minimumX =
        _viewportSize.width -
        maximumHorizontalBlank -
        _cardContentBounds.right * value.scale;
    final maximumX =
        maximumHorizontalBlank - _cardContentBounds.left * value.scale;
    final minimumY =
        _viewportSize.height -
        maximumVerticalBlank -
        _cardContentBounds.bottom * value.scale;
    final maximumY =
        maximumVerticalBlank - _cardContentBounds.top * value.scale;
    return value.copyWith(
      x: value.x.clamp(minimumX, maximumX),
      y: value.y.clamp(minimumY, maximumY),
    );
  }

  void _setTransform(_CanvasTransform value, {bool clamp = true}) {
    final next = clamp ? _clampTransform(value) : value;
    _transformationController.value = next.matrix;
  }

  void _animateTransformTo(_CanvasTransform target) {
    final clampedTarget = _clampTransform(target);
    if (MediaQuery.disableAnimationsOf(context)) {
      _transformAnimation.stop();
      _setTransform(clampedTarget, clamp: false);
      return;
    }
    _animationStart = _currentTransform;
    _animationTarget = clampedTarget;
    _transformAnimation.forward(from: 0);
  }

  void _onTransformAnimationTick() {
    final progress = Curves.easeOutCubic.transform(_transformAnimation.value);
    _setTransform(
      _CanvasTransform.lerp(_animationStart, _animationTarget, progress),
      clamp: false,
    );
  }

  void _stopTransformAnimation() => _transformAnimation.stop();

  void _resetView({
    bool stopPlayback = true,
    bool haptic = true,
    bool animate = true,
  }) {
    if (_viewportSize.isEmpty || _canvasSize.isEmpty) return;
    if (stopPlayback) _stopAutoPlay();
    final targetScale = _layout == _CanvasLayout.compact ? 0.88 : 0.82;
    final x = _viewportSize.width / 2 - _canvasSize.width * targetScale / 2;
    final y = _viewportSize.height / 2 - _canvasSize.height * targetScale / 2;
    final target = _CanvasTransform(x: x, y: y, scale: targetScale);
    if (animate) {
      _animateTransformTo(target);
    } else {
      _stopTransformAnimation();
      _setTransform(target);
    }
    if (haptic) AppHaptics.selection();
  }

  void _zoomBy(
    double factor, {
    Offset? center,
    bool animate = true,
    bool haptic = true,
  }) {
    if (_viewportSize.isEmpty || _canvasSize.isEmpty) return;
    _stopAutoPlay();
    final current = _currentTransform;
    final focalPoint = center ?? _viewportSize.center(Offset.zero);
    final nextScale = (current.scale * factor).clamp(0.42, 2.4);
    final sceneX = (focalPoint.dx - current.x) / current.scale;
    final sceneY = (focalPoint.dy - current.y) / current.scale;
    final target = _CanvasTransform(
      x: focalPoint.dx - sceneX * nextScale,
      y: focalPoint.dy - sceneY * nextScale,
      scale: nextScale,
    );
    if (animate) {
      _animateTransformTo(target);
    } else {
      _stopTransformAnimation();
      _setTransform(target);
    }
    if (haptic) AppHaptics.selection();
  }

  void _onAutoPlayTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || !_autoPlaying) return;
    final seconds = (elapsed - previous).inMicroseconds / 1000000;
    if (seconds <= 0 || seconds > .1) return;
    final direction = _autoPlayDirection.distance == 0
        ? const Offset(0, -1)
        : _autoPlayDirection / _autoPlayDirection.distance;
    final current = _currentTransform;
    final next = _clampTransform(
      current.copyWith(
        x: current.x + direction.dx * _autoPlaySpeed * seconds,
        y: current.y + direction.dy * _autoPlaySpeed * seconds,
      ),
    );
    _setTransform(next, clamp: false);
    if ((next.x - current.x).abs() < .01 && (next.y - current.y).abs() < .01) {
      _stopAutoPlay();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_autoPlaying) return;
    _stopTransformAnimation();
    _pointers[event.pointer] = event.localPosition;
    _dragDistance = 0;
    if (_pointers.length == 1) {
      _lastPointer = event.localPosition;
    } else if (_pointers.length == 2) {
      final midpoint = _pointerMidpoint;
      final current = _currentTransform;
      _pinchStart = _PinchStart(
        distance: _pointerDistance,
        scale: current.scale,
        sceneX: (midpoint.dx - current.x) / current.scale,
        sceneY: (midpoint.dy - current.y) / current.scale,
      );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null || _autoPlaying) return;
    _pointers[event.pointer] = event.localPosition;
    _dragDistance += (event.localPosition - previous).distance;
    final pinch = _pinchStart;
    if (_pointers.length == 2 && pinch != null) {
      final midpoint = _pointerMidpoint;
      final nextScale = (pinch.scale * (_pointerDistance / pinch.distance))
          .clamp(.42, 2.4);
      _setTransform(
        _CanvasTransform(
          x: midpoint.dx - pinch.sceneX * nextScale,
          y: midpoint.dy - pinch.sceneY * nextScale,
          scale: nextScale,
        ),
      );
      return;
    }
    if (_pointers.length == 1 && _lastPointer != null) {
      final delta = event.localPosition - _lastPointer!;
      final current = _currentTransform;
      _setTransform(
        current.copyWith(x: current.x + delta.dx, y: current.y + delta.dy),
      );
      _lastPointer = event.localPosition;
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_dragDistance > 6) {
      _suppressCardTapUntil = DateTime.now().add(
        const Duration(milliseconds: 260),
      );
    }
    _pinchStart = null;
    _lastPointer = _pointers.values.firstOrNull;
  }

  double get _pointerDistance {
    final points = _pointers.values.take(2).toList();
    return (points[1] - points[0]).distance;
  }

  Offset get _pointerMidpoint {
    final points = _pointers.values.take(2).toList();
    return Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _autoPlaying) return;
    _zoomBy(
      math.exp(-event.scrollDelta.dy * .0015),
      center: event.localPosition,
      animate: false,
      haptic: false,
    );
  }

  void _openCard(CardSummary card) {
    if (DateTime.now().isBefore(_suppressCardTapUntil)) return;
    widget.onOpenCard(card);
  }

  void _startAutoPlay() {
    if (MediaQuery.disableAnimationsOf(context)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已按系统“减少动态效果”设置停用自动播放')));
      return;
    }
    setState(() => _autoPlaying = true);
    _lastTick = null;
    if (!_autoPlayTicker.isActive) _autoPlayTicker.start();
  }

  void _stopAutoPlay() {
    if (!_autoPlaying && !_autoPlayTicker.isActive) return;
    _autoPlayTicker.stop();
    _lastTick = null;
    if (mounted) setState(() => _autoPlaying = false);
  }

  Future<void> _toggleImmersive() async {
    final next = !_immersive;
    setState(() => _immersive = next);
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _exitCanvas() async {
    if (_immersive) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final isDarkBackground = _backgroundColor.computeLuminance() < .32;
    final controlsTop = safePadding.top + 14;
    final controlsBottom = safePadding.bottom + 22;

    return Material(
      key: const Key('card-canvas-page'),
      color: _backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          final metrics = _metricsFor(viewport);
          _scheduleInitialPosition(viewport, metrics);
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                key: const Key('card-canvas-background'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                color: _backgroundColor,
              ),
              if (_showDotGrid)
                IgnorePointer(
                  child: CustomPaint(
                    key: const Key('card-canvas-dot-grid'),
                    painter: _DotGridPainter(dark: isDarkBackground),
                    size: Size.infinite,
                  ),
                ),
              if (_canvasCards.isEmpty)
                Center(
                  child: Text(
                    '暂无可展示的卡片',
                    style: TextStyle(
                      color: isDarkBackground ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Listener(
                  key: const Key('card-canvas-interactive-viewer'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerUp,
                  onPointerSignal: _onPointerSignal,
                  child: ClipRect(
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _transformationController,
                      builder: (context, transform, child) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Transform(
                              key: const Key('card-canvas-transform'),
                              transform: transform,
                              alignment: Alignment.topLeft,
                              child: child,
                            ),
                          ),
                        ],
                      ),
                      child: _CardField(
                        cards: _canvasCards,
                        metrics: metrics,
                        staggered: _staggered,
                        rotationDegrees: _rotationDegrees,
                        shuffleSeed: _shuffleSeed,
                        darkBackground: isDarkBackground,
                        onOpenCard: _openCard,
                      ),
                    ),
                  ),
                ),
              if (_immersive)
                Positioned(
                  top: controlsTop,
                  right: 16,
                  child: _RoundControlButton(
                    key: const Key('card-canvas-immersive-button'),
                    icon: Icons.fullscreen_exit_rounded,
                    label: '退出全屏',
                    selected: true,
                    onTap: _toggleImmersive,
                  ),
                )
              else ...[
                Positioned(
                  top: safePadding.top + 14,
                  right: 16,
                  child: _RoundControlButton(
                    key: const Key('card-canvas-close'),
                    icon: Icons.close_rounded,
                    label: '关闭卡片画布',
                    size: 48,
                    onTap: _exitCanvas,
                  ),
                ),
                Positioned(
                  left: 16,
                  top: controlsTop,
                  child: _CanvasToolbar(
                    layout: _layout,
                    staggered: _staggered,
                    autoPlaying: _autoPlaying,
                    immersive: _immersive,
                    onBackground: _showBackgroundPanel,
                    onLayout: _showLayoutPanel,
                    onAngle: _showAnglePanel,
                    onShuffle: () {
                      setState(() => _shuffleSeed++);
                      AppHaptics.selection();
                    },
                    onAutoPlay: _autoPlaying
                        ? _stopAutoPlay
                        : _showAutoPlayPanel,
                    onImmersive: _toggleImmersive,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: controlsBottom,
                  child: Column(
                    children: [
                      _RoundControlButton(
                        key: const Key('card-canvas-zoom-in'),
                        icon: Icons.add_rounded,
                        label: '放大画布',
                        onTap: () => _zoomBy(1.18),
                      ),
                      const SizedBox(height: 8),
                      _RoundControlButton(
                        key: const Key('card-canvas-zoom-out'),
                        icon: Icons.remove_rounded,
                        label: '缩小画布',
                        onTap: () => _zoomBy(1 / 1.18),
                      ),
                      const SizedBox(height: 8),
                      _RoundControlButton(
                        key: const Key('card-canvas-reset'),
                        icon: Icons.restart_alt_rounded,
                        label: '复位画布',
                        onTap: _resetView,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBackgroundPanel() async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .62,
      minSize: .38,
      maxSize: .9,
      barrierAlpha: .26,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (context, setSheetState) => _GlassSheet(
          title: '背景',
          onDone: () => Navigator.pop(sheetContext),
          scrollController: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetLabel('背景颜色'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    for (final color in _backgroundColors)
                      _ColorChoice(
                        color: color,
                        selected:
                            color.toARGB32() == _backgroundColor.toARGB32(),
                        onTap: () {
                          setState(() => _backgroundColor = color);
                          setSheetState(() {});
                        },
                      ),
                    _DotGridChoice(
                      selected: _showDotGrid,
                      onTap: () {
                        setState(() => _showDotGrid = !_showDotGrid);
                        setSheetState(() {});
                      },
                    ),
                    _CustomColorChoice(
                      onTap: () async {
                        final result = await showDialog<Color>(
                          context: sheetContext,
                          builder: (_) => _CustomColorDialog(
                            initialColor: _backgroundColor,
                          ),
                        );
                        if (result == null || !mounted) return;
                        setState(() => _backgroundColor = result);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SheetLabel('背景图'),
              const SizedBox(height: 12),
              Container(
                height: 54,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.collections_outlined, color: _green),
                    SizedBox(width: 10),
                    Text(
                      '上传背景图',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLayoutPanel() async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .58,
      minSize: .38,
      maxSize: .9,
      barrierAlpha: .26,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (context, setSheetState) => _GlassSheet(
          title: '排列',
          onDone: () => Navigator.pop(sheetContext),
          scrollController: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _LayoutChoice(
                      key: const Key('card-canvas-layout-compact'),
                      icon: Icons.grid_view_rounded,
                      title: '紧密网格',
                      description: '一次看到更多卡片',
                      selected: _layout == _CanvasLayout.compact,
                      onTap: () {
                        setState(() {
                          _layout = _CanvasLayout.compact;
                          _didPositionCanvas = false;
                        });
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LayoutChoice(
                      key: const Key('card-canvas-layout-gallery'),
                      icon: Icons.space_dashboard_outlined,
                      title: '松散画廊',
                      description: '留白更宽，更有层次',
                      selected: _layout == _CanvasLayout.gallery,
                      onTap: () {
                        setState(() {
                          _layout = _CanvasLayout.gallery;
                          _didPositionCanvas = false;
                        });
                        setSheetState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const _SheetLabel('每行显示'),
                  const Spacer(),
                  Text(
                    '${(_columnsPerRow ?? _metricsFor(_viewportSize).columns)} 张',
                    style: const TextStyle(
                      color: _CardCanvasPageState._green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _columnsPerRow = null;
                        _didPositionCanvas = false;
                      });
                      setSheetState(() {});
                    },
                    child: const Text('自动'),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _green,
                  inactiveTrackColor: _green.withValues(alpha: .16),
                  thumbColor: _green,
                  overlayColor: _green.withValues(alpha: .12),
                  trackHeight: 5,
                ),
                child: Slider(
                  key: const Key('card-canvas-columns-slider'),
                  value: (_columnsPerRow ?? _metricsFor(_viewportSize).columns)
                      .toDouble()
                      .clamp(2, 12),
                  min: 2,
                  max: 12,
                  divisions: 10,
                  label:
                      '${(_columnsPerRow ?? _metricsFor(_viewportSize).columns)} 张',
                  onChanged: (value) {
                    setState(() {
                      _columnsPerRow = value.round();
                      _didPositionCanvas = false;
                    });
                    setSheetState(() {});
                  },
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '拖动滑杆调整卡片密度，画布会保持居中。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAnglePanel() async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .5,
      minSize: .36,
      maxSize: .82,
      barrierAlpha: .26,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (context, setSheetState) => _GlassSheet(
          title: '卡片错位',
          onDone: () => Navigator.pop(sheetContext),
          scrollController: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                key: const Key('card-canvas-stagger-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '轻微旋转与错位',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('让画布更像铺开的实体卡片'),
                activeTrackColor: _green,
                value: _staggered,
                onChanged: (value) {
                  setState(() => _staggered = value);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    '旋转角度',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_rotationDegrees.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                key: const Key('card-canvas-angle-slider'),
                value: _rotationDegrees,
                min: 0,
                max: 6,
                divisions: 24,
                activeColor: _green,
                onChanged: _staggered
                    ? (value) {
                        setState(() => _rotationDegrees = value);
                        setSheetState(() {});
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAutoPlayPanel() async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .62,
      minSize: .4,
      maxSize: .9,
      barrierAlpha: .32,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (context, setSheetState) => _GlassSheet(
          title: '自动播放',
          onDone: () => Navigator.pop(sheetContext),
          scrollController: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetLabel('方向'),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 146,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _DirectionOption.values)
                        if (option == _DirectionOption.center)
                          const SizedBox(width: 42, height: 42)
                        else
                          _DirectionButton(
                            option: option,
                            selected: option.offset == _autoPlayDirection,
                            onTap: () {
                              setState(
                                () => _autoPlayDirection = option.offset,
                              );
                              setSheetState(() {});
                            },
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SheetLabel('速度'),
              Row(
                children: [
                  const Icon(Icons.directions_walk_rounded, size: 20),
                  Expanded(
                    child: Slider(
                      key: const Key('card-canvas-speed-slider'),
                      min: 20,
                      max: 110,
                      value: _autoPlaySpeed,
                      activeColor: _green,
                      onChanged: (value) {
                        setState(() => _autoPlaySpeed = value);
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const Icon(Icons.directions_run_rounded, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  key: const Key('card-canvas-autoplay-toggle'),
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: () {
                    if (_autoPlaying) {
                      _stopAutoPlay();
                    } else {
                      _startAutoPlay();
                    }
                    Navigator.pop(sheetContext);
                  },
                  icon: Icon(
                    _autoPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(_autoPlaying ? '停止播放' : '开始播放'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasMetrics {
  const _CanvasMetrics({
    required this.canvasSize,
    required this.cardSize,
    required this.columns,
    required this.horizontalGap,
    required this.verticalGap,
    required this.horizontalMargin,
    required this.verticalMargin,
  });

  final Size canvasSize;
  final Size cardSize;
  final int columns;
  final double horizontalGap;
  final double verticalGap;
  final double horizontalMargin;
  final double verticalMargin;
}

class _CanvasTransform {
  const _CanvasTransform({
    required this.x,
    required this.y,
    required this.scale,
  });

  const _CanvasTransform.identity() : x = 0, y = 0, scale = 1;

  factory _CanvasTransform.fromMatrix(Matrix4 matrix) => _CanvasTransform(
    x: matrix.storage[12],
    y: matrix.storage[13],
    scale: matrix.getMaxScaleOnAxis(),
  );

  final double x;
  final double y;
  final double scale;

  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(x, y, 0, 1)
    ..scaleByDouble(scale, scale, scale, 1);

  _CanvasTransform copyWith({double? x, double? y, double? scale}) =>
      _CanvasTransform(
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
      );

  static _CanvasTransform lerp(
    _CanvasTransform begin,
    _CanvasTransform end,
    double t,
  ) => _CanvasTransform(
    x: lerpDouble(begin.x, end.x, t)!,
    y: lerpDouble(begin.y, end.y, t)!,
    scale: lerpDouble(begin.scale, end.scale, t)!,
  );
}

class _PinchStart {
  const _PinchStart({
    required this.distance,
    required this.scale,
    required this.sceneX,
    required this.sceneY,
  });

  final double distance;
  final double scale;
  final double sceneX;
  final double sceneY;
}

class _CardGeometry {
  const _CardGeometry({required this.offset, required this.angle});

  final Offset offset;
  final double angle;
}

_CardGeometry _cardGeometry({
  required int index,
  required _CanvasMetrics metrics,
  required bool staggered,
  required double rotationDegrees,
  required int shuffleSeed,
}) {
  final row = index ~/ metrics.columns;
  final column = index % metrics.columns;
  final phase = index * 1.913 + shuffleSeed * .73;
  final xJitter = staggered ? math.sin(phase * .71) * 8 : 0.0;
  final yJitter = staggered ? math.cos(phase * .83) * 7 : 0.0;
  final x =
      metrics.horizontalMargin +
      column * (metrics.cardSize.width + metrics.horizontalGap) +
      xJitter;
  final y =
      metrics.verticalMargin +
      row * (metrics.cardSize.height + metrics.verticalGap) +
      yJitter;
  final angle = staggered
      ? math.sin(phase) * rotationDegrees * math.pi / 180
      : 0.0;
  return _CardGeometry(offset: Offset(x, y), angle: angle);
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.cards,
    required this.metrics,
    required this.staggered,
    required this.rotationDegrees,
    required this.shuffleSeed,
    required this.darkBackground,
    required this.onOpenCard,
  });

  final List<CardSummary> cards;
  final _CanvasMetrics metrics;
  final bool staggered;
  final double rotationDegrees;
  final int shuffleSeed;
  final bool darkBackground;
  final ValueChanged<CardSummary> onOpenCard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('card-canvas-field'),
      width: metrics.canvasSize.width,
      height: metrics.canvasSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < cards.length; index++)
            _positionedCard(context, index),
        ],
      ),
    );
  }

  Widget _positionedCard(BuildContext context, int index) {
    final geometry = _cardGeometry(
      index: index,
      metrics: metrics,
      staggered: staggered,
      rotationDegrees: rotationDegrees,
      shuffleSeed: shuffleSeed,
    );
    final card = cards[index];

    return Positioned(
      left: geometry.offset.dx,
      top: geometry.offset.dy,
      width: metrics.cardSize.width,
      height: metrics.cardSize.height,
      child: Transform.rotate(
        angle: geometry.angle,
        child: Semantics(
          button: true,
          label: '查看${card.name}',
          child: GestureDetector(
            key: Key('card-canvas-card-$index-${card.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpenCard(card),
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: darkBackground
                          ? Colors.black.withValues(alpha: .22)
                          : const Color(0xFF59637B).withValues(alpha: .16),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CardArtwork(card: card, showGeneratedLabels: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({
    required this.layout,
    required this.staggered,
    required this.autoPlaying,
    required this.immersive,
    required this.onBackground,
    required this.onLayout,
    required this.onAngle,
    required this.onShuffle,
    required this.onAutoPlay,
    required this.onImmersive,
  });

  final _CanvasLayout layout;
  final bool staggered;
  final bool autoPlaying;
  final bool immersive;
  final VoidCallback onBackground;
  final VoidCallback onLayout;
  final VoidCallback onAngle;
  final VoidCallback onShuffle;
  final VoidCallback onAutoPlay;
  final VoidCallback onImmersive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoundControlButton(
          key: const Key('card-canvas-background-button'),
          icon: Icons.contrast_rounded,
          label: '设置画布背景',
          onTap: onBackground,
        ),
        const SizedBox(height: 7),
        _RoundControlButton(
          key: const Key('card-canvas-layout-button'),
          icon: layout == _CanvasLayout.compact
              ? Icons.grid_view_rounded
              : Icons.space_dashboard_outlined,
          label: '设置卡片排列',
          selected: layout == _CanvasLayout.gallery,
          onTap: onLayout,
        ),
        const SizedBox(height: 7),
        _RoundControlButton(
          key: const Key('card-canvas-angle-button'),
          icon: Icons.credit_card_rounded,
          label: '设置卡片错位角度',
          selected: staggered,
          onTap: onAngle,
        ),
        const SizedBox(height: 7),
        _RoundControlButton(
          key: const Key('card-canvas-shuffle-button'),
          icon: Icons.layers_outlined,
          label: '重新错位排列',
          onTap: onShuffle,
        ),
        const SizedBox(height: 7),
        _RoundControlButton(
          key: const Key('card-canvas-autoplay-button'),
          icon: autoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: autoPlaying ? '设置或停止自动播放' : '设置自动播放',
          selected: autoPlaying,
          onTap: onAutoPlay,
        ),
        const SizedBox(height: 7),
        _RoundControlButton(
          key: const Key('card-canvas-immersive-button'),
          icon: immersive
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: immersive ? '退出沉浸模式' : '进入沉浸模式',
          selected: immersive,
          onTap: onImmersive,
        ),
      ],
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        key: const Key('card-canvas-control-shadow'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 18,
              spreadRadius: -2,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: selected
                  ? _CardCanvasPageState._green.withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .42),
              blurRadius: 8,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: selected
                  ? const Color(0xFFE2F7EF).withValues(alpha: .88)
                  : Colors.white.withValues(alpha: .82),
              shape: CircleBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: .60)),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(
                    icon,
                    size: size >= 58 ? 31 : 23,
                    color: selected
                        ? _CardCanvasPageState._green
                        : const Color(0xFF111315),
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

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({
    required this.title,
    required this.onDone,
    required this.child,
    required this.scrollController,
  });

  final String title;
  final VoidCallback onDone;
  final Widget child;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: const Color(0xFFF0F7F3).withValues(alpha: .88),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .20),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF101714),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onDone,
                          child: const Text(
                            '完成',
                            style: TextStyle(
                              color: _CardCanvasPageState._green,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black.withValues(alpha: .56),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = color.computeLuminance() < .42;
    return Semantics(
      button: true,
      selected: selected,
      label: '选择背景颜色',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? _CardCanvasPageState._green
                  : Colors.black.withValues(alpha: .18),
              width: selected ? 4 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _CardCanvasPageState._green.withValues(alpha: .24),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  color: dark ? Colors.white : Colors.black87,
                  size: 25,
                )
              : null,
        ),
      ),
    );
  }
}

class _DotGridChoice extends StatelessWidget {
  const _DotGridChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '切换点阵网格背景',
      child: GestureDetector(
        key: const Key('card-canvas-dot-grid-choice'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE6ECE9),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? _CardCanvasPageState._green
                  : Colors.black.withValues(alpha: .18),
              width: selected ? 4 : 1.5,
            ),
          ),
          child: CustomPaint(
            painter: _DotGridSwatchPainter(
              color: selected
                  ? _CardCanvasPageState._green
                  : const Color(0xFF6F7D76),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: .13)
          : const Color(0xFF18231E).withValues(alpha: .10);
    const spacing = 20.0;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), .85, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _DotGridSwatchPainter extends CustomPainter {
  const _DotGridSwatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 12.0; x < size.width - 6; x += 10) {
      for (var y = 12.0; y < size.height - 6; y += 10) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridSwatchPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CustomColorChoice extends StatelessWidget {
  const _CustomColorChoice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '自定义背景颜色',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: .24),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.black54),
        ),
      ),
    );
  }
}

class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _CardCanvasPageState._green.withValues(alpha: .12)
          : Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? _CardCanvasPageState._green
                  : Colors.black.withValues(alpha: .07),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? _CardCanvasPageState._green : Colors.black87,
                size: 28,
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DirectionOption {
  northWest(Offset(-1, -1), Icons.north_west_rounded),
  north(Offset(0, -1), Icons.north_rounded),
  northEast(Offset(1, -1), Icons.north_east_rounded),
  west(Offset(-1, 0), Icons.west_rounded),
  center(Offset.zero, Icons.circle_outlined),
  east(Offset(1, 0), Icons.east_rounded),
  southWest(Offset(-1, 1), Icons.south_west_rounded),
  south(Offset(0, 1), Icons.south_rounded),
  southEast(Offset(1, 1), Icons.south_east_rounded);

  const _DirectionOption(this.offset, this.icon);

  final Offset offset;
  final IconData icon;
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _DirectionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '自动播放方向 ${option.name}',
      child: Material(
        color: selected
            ? _CardCanvasPageState._green
            : _CardCanvasPageState._green.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            key: Key('card-canvas-direction-${option.name}'),
            width: 42,
            height: 42,
            child: Icon(
              option.icon,
              size: 20,
              color: selected ? Colors.white : const Color(0xFF183629),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late double _red = widget.initialColor.r * 255;
  late double _green = widget.initialColor.g * 255;
  late double _blue = widget.initialColor.b * 255;

  Color get _color =>
      Color.fromARGB(255, _red.round(), _green.round(), _blue.round());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义颜色'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            _ColorChannelSlider(
              label: 'R',
              value: _red,
              color: Colors.red,
              onChanged: (value) => setState(() => _red = value),
            ),
            _ColorChannelSlider(
              label: 'G',
              value: _green,
              color: Colors.green,
              onChanged: (value) => setState(() => _green = value),
            ),
            _ColorChannelSlider(
              label: 'B',
              value: _blue,
              color: Colors.blue,
              onChanged: (value) => setState(() => _blue = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('使用'),
        ),
      ],
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text(value.round().toString())),
      ],
    );
  }
}
