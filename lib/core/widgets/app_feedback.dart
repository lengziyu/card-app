import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppNoticeTone { info, success, warning, error }

/// 品牌化的全局轻提示。
///
/// 使用根 [Overlay] 展示，不依赖 ScaffoldMessenger 或系统 SnackBar。
abstract final class AppNotice {
  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _activeEntry?.remove();
    _activeEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppNoticeOverlay(
        message: message,
        title: title,
        tone: tone,
        duration: duration,
        onRemoved: () {
          if (entry.mounted) entry.remove();
          if (identical(_activeEntry, entry)) _activeEntry = null;
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);

    final feedback = switch (tone) {
      AppNoticeTone.success => HapticFeedback.lightImpact,
      AppNoticeTone.warning ||
      AppNoticeTone.error => HapticFeedback.mediumImpact,
      AppNoticeTone.info => HapticFeedback.selectionClick,
    };
    feedback();
  }

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title);

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message, tone: AppNoticeTone.success, title: title);

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message, tone: AppNoticeTone.warning, title: title);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message, tone: AppNoticeTone.error, title: title);
}

class _AppNoticeOverlay extends StatefulWidget {
  const _AppNoticeOverlay({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onRemoved,
    this.title,
  });

  final String message;
  final String? title;
  final AppNoticeTone tone;
  final Duration duration;
  final VoidCallback onRemoved;

  @override
  State<_AppNoticeOverlay> createState() => _AppNoticeOverlayState();
}

class _AppNoticeOverlayState extends State<_AppNoticeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) {
        _entranceController.value = 1;
      } else {
        _entranceController.forward();
        _pulseController.repeat(reverse: true);
      }
      _dismissTimer = Timer(widget.duration, _dismiss);
    });
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _pulseController.stop();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _entranceController.reverse();
    }
    if (mounted) widget.onRemoved();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = _noticeVisual(widget.tone);
    final curved = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      key: const Key('app-notice'),
      top: MediaQuery.paddingOf(context).top + 10,
      left: 14,
      right: 14,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: FadeTransition(
              opacity: _entranceController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.32),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                  child: Semantics(
                    liveRegion: true,
                    label: '${widget.title ?? tone.label}，${widget.message}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) < -120) _dismiss();
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tone.color.withValues(alpha: .76),
                              AppColors.violet.withValues(alpha: .42),
                              AppColors.line,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(21),
                          boxShadow: [
                            BoxShadow(
                              color: tone.color.withValues(alpha: .18),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                            const BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: ColoredBox(
                                color: AppColors.isDark
                                    ? const Color(0xE61A1E30)
                                    : const Color(0xE8FFFFFF),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    13,
                                    12,
                                    11,
                                    12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) =>
                                            Transform.scale(
                                              scale:
                                                  1 +
                                                  _pulseController.value * .055,
                                              child: child,
                                            ),
                                        child: _NoticeIcon(visual: tone),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.title ?? tone.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.text,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w900,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              widget.message,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: _dismiss,
                                        tooltip: '关闭提示',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.textMuted,
                                          size: 18,
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

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({required this.visual});

  final _NoticeVisual visual;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          visual.color.withValues(alpha: .96),
          visual.color.withValues(alpha: .62),
        ],
      ),
      borderRadius: BorderRadius.circular(13),
      boxShadow: [
        BoxShadow(
          color: visual.color.withValues(alpha: .28),
          blurRadius: 14,
          spreadRadius: -2,
        ),
      ],
    ),
    child: Icon(visual.icon, color: Colors.white, size: 21),
  );
}

class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({this.size = 42, this.progress, super.key});

  final double size;

  /// 非空时显示手势驱动的静态进度；为空时循环播放。
  final double? progress;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate =
        widget.progress == null && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AppLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate =
        widget.progress == null && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载',
    child: SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _AppLoadingPainter(
            progress:
                widget.progress?.clamp(0, 1) ??
                (MediaQuery.disableAnimationsOf(context)
                    ? .72
                    : _controller.value),
          ),
        ),
      ),
    ),
  );
}

class AppLoadingPanel extends StatelessWidget {
  const AppLoadingPanel({
    this.label = '正在整理卡片数据',
    this.height = 112,
    super.key,
  });

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: AppColors.violet.withValues(alpha: .08),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLoadingIndicator(size: 38),
        const SizedBox(width: 13),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.color,
    this.height = 5,
    super.key,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0, 1).toDouble();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      value: '${(target * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _AppProgressPainter(
              value: animatedValue,
              color: color ?? AppColors.violet,
            ),
          ),
        ),
      ),
    );
  }
}

class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1.8 + _controller.value * 3.6, 0),
        end: Alignment(-.8 + _controller.value * 3.6, 0),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: AppColors.isDark ? .12 : .58),
          AppColors.cyan.withValues(alpha: .11),
          Colors.transparent,
        ],
        stops: const [0, .42, .58, 1],
      ).createShader(bounds),
      child: child,
    ),
  );
}

/// 自定义的下拉刷新反馈，不使用平台 RefreshIndicator。
class AppPullToRefresh extends StatefulWidget {
  const AppPullToRefresh({
    required this.onRefresh,
    required this.child,
    this.indicatorTop = 8,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// 刷新提示相对组件顶部的位置；带有悬浮页头的页面可下移提示。
  final double indicatorTop;

  @override
  State<AppPullToRefresh> createState() => _AppPullToRefreshState();
}

class _AppPullToRefreshState extends State<AppPullToRefresh> {
  static const _triggerDistance = 76.0;
  double _progress = 0;
  bool _refreshing = false;
  bool _armed = false;
  bool _completed = false;
  bool _failed = false;

  bool _onScroll(ScrollNotification notification) {
    // 只处理最外层列表，避免横向列表或嵌套滚动误触发刷新。
    if (notification.depth != 0 || _refreshing || _completed || _failed) {
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < 0) {
      _updateProgress(
        (-notification.metrics.pixels / _triggerDistance).clamp(0, 1.25),
      );
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= 0) {
      _updateProgress(
        (_progress + (-notification.overscroll / _triggerDistance)).clamp(
          0,
          1.25,
        ),
      );
    } else if (notification is ScrollEndNotification) {
      if (_progress >= 1) {
        _refresh();
      } else if (_progress != 0) {
        setState(() => _progress = 0);
      }
    }
    return false;
  }

  void _updateProgress(double value) {
    final nextArmed = value >= 1;
    if (nextArmed && !_armed) HapticFeedback.selectionClick();
    if (value == _progress && nextArmed == _armed) return;
    setState(() {
      _progress = value;
      _armed = nextArmed;
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _progress = 1;
      _armed = false;
    });
    HapticFeedback.lightImpact();
    var succeeded = true;
    try {
      await widget.onRefresh();
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _completed = succeeded;
      _failed = !succeeded;
    });
    if (succeeded) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
    );
    if (!mounted) return;
    setState(() {
      _progress = 0;
      _armed = false;
      _completed = false;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _refreshing || _completed || _failed || _progress > .02;
    final label = switch ((_refreshing, _completed, _failed, _progress >= 1)) {
      (_, true, _, _) => '已更新',
      (_, _, true, _) => '更新失败',
      (true, _, _, _) => '正在更新',
      (_, _, _, true) => '松开刷新',
      _ => '下拉刷新',
    };
    final feedbackColor = _failed
        ? const Color(0xFFFF7188)
        : _completed
        ? AppColors.mint
        : AppColors.cyan;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: widget.indicatorTop,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, -.55),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: label,
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      padding: const EdgeInsets.fromLTRB(9, 7, 13, 7),
                      decoration: BoxDecoration(
                        color: AppColors.glassStrong,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: (_completed || _failed)
                              ? feedbackColor.withValues(alpha: .55)
                              : AppColors.line,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                          if (_completed || _failed)
                            BoxShadow(
                              color: feedbackColor.withValues(alpha: .18),
                              blurRadius: 18,
                              spreadRadius: -3,
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_completed || _failed)
                            Icon(
                              _completed
                                  ? Icons.check_rounded
                                  : Icons.priority_high_rounded,
                              color: feedbackColor,
                              size: 23,
                            )
                          else
                            AppLoadingIndicator(
                              size: 25,
                              progress: _refreshing ? null : _progress,
                            ),
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: TextStyle(
                              color: _completed || _failed
                                  ? feedbackColor
                                  : AppColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
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
      ],
    );
  }
}

class _AppLoadingPainter extends CustomPainter {
  const _AppLoadingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = size.shortestSide;
    final orbitRadius = shortest * .37;
    final trackPaint = Paint()
      ..color = AppColors.violet.withValues(alpha: .11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * .055;
    canvas.drawCircle(center, orbitRadius, trackPaint);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: shortest * .27,
        height: shortest * .36,
      ),
      Radius.circular(shortest * .055),
    );
    final cardPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.violet, AppColors.cyan],
      ).createShader(cardRect.outerRect);
    canvas.drawRRect(cardRect, cardPaint);
    canvas.drawLine(
      Offset(center.dx - shortest * .08, center.dy - shortest * .035),
      Offset(center.dx + shortest * .07, center.dy - shortest * .035),
      Paint()
        ..color = Colors.white.withValues(alpha: .78)
        ..strokeWidth = shortest * .025
        ..strokeCap = StrokeCap.round,
    );

    final colors = [AppColors.cyan, AppColors.mint, AppColors.pink];
    for (var index = 0; index < colors.length; index++) {
      final phase = progress * 6.283185307 + index * 2.094395102;
      final point = Offset(
        center.dx + orbitRadius * math.cos(phase),
        center.dy + orbitRadius * math.sin(phase),
      );
      final radius = shortest * (.065 + index * .008);
      canvas.drawCircle(
        point,
        radius * 1.9,
        Paint()
          ..color = colors[index].withValues(alpha: .16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius),
      );
      canvas.drawCircle(point, radius, Paint()..color = colors[index]);
    }
  }

  @override
  bool shouldRepaint(covariant _AppLoadingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AppProgressPainter extends CustomPainter {
  const _AppProgressPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(
      track,
      Paint()..color = AppColors.textMuted.withValues(alpha: .12),
    );
    if (value <= 0) return;
    final width = (size.width * value)
        .clamp(size.height, size.width)
        .toDouble();
    final fillRect = Rect.fromLTWH(0, 0, width, size.height);
    final fill = RRect.fromRectAndRadius(fillRect, radius);
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .76), color],
        ).createShader(fillRect),
    );
    canvas.drawCircle(
      Offset(width - size.height / 2, size.height / 2),
      size.height * .8,
      Paint()
        ..color = color.withValues(alpha: .24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height),
    );
  }

  @override
  bool shouldRepaint(covariant _AppProgressPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _NoticeVisual {
  const _NoticeVisual(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

_NoticeVisual _noticeVisual(AppNoticeTone tone) => switch (tone) {
  AppNoticeTone.info => _NoticeVisual(
    '温馨提示',
    Icons.auto_awesome_rounded,
    AppColors.cyan,
  ),
  AppNoticeTone.success => _NoticeVisual(
    '操作完成',
    Icons.check_rounded,
    AppColors.mint,
  ),
  AppNoticeTone.warning => const _NoticeVisual(
    '请留意',
    Icons.priority_high_rounded,
    Color(0xFFFFB85C),
  ),
  AppNoticeTone.error => const _NoticeVisual(
    '出了点状况',
    Icons.close_rounded,
    Color(0xFFFF7188),
  ),
};
