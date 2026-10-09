import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 只淡出卡片层，标题、导航和页面背景仍由各自的层绘制。
class HomeCardSceneFade extends StatelessWidget {
  const HomeCardSceneFade({
    required this.child,
    this.navigationVisible = true,
    super.key,
  });

  final Widget child;
  final bool navigationVisible;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // ShaderMask 只混合自身矩形内的内容；先限制整页绘制范围，
    // 才能让越界卡片也在透明的渐变终点消失，而不是漏到系统栏。
    return ClipRect(
      child: ShaderMask(
        key: const Key('home-fan-edge-fade'),
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final height = math.max(1.0, bounds.height);
          final top = math.min(104.0, height * .24) / height;
          final bottom =
              math.min(
                (navigationVisible ? 108.0 : 28.0) + bottomInset,
                height * .28,
              ) /
              height;
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Color(0x1FFFFFFF),
              Colors.white,
              Colors.white,
              Color(0x1FFFFFFF),
              Colors.transparent,
            ],
            stops: [0, top * .55, top, 1 - bottom, 1 - bottom * .35, 1],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}
