import 'dart:ui';

import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 二级页面共用的顶部毛玻璃渐隐层。
///
/// 模糊和底色只作用于背景，并在底部降到完全透明；前景按钮与标题保持清晰。
class FrostedHeaderFade extends StatelessWidget {
  const FrostedHeaderFade({
    required this.height,
    required this.child,
    super.key,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .32, 1],
              ).createShader(bounds),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.isDark
                            ? const [Color(0xB8070B19), Color(0x52070B19)]
                            : const [Color(0xC7F8FBFF), Color(0x52F8FBFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class StickyPageHeader extends StatelessWidget {
  const StickyPageHeader({
    required this.child,
    this.height = 80,
    this.horizontalPadding = 20,
    super.key,
  });

  final Widget child;
  final double height;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return FrostedHeaderFade(
      // 二级页会延伸到状态栏下方；标题区必须把刘海 / Dynamic Island
      // 一并包进自己的背景，不能依赖外层 SafeArea 产生一条截断带。
      height: topInset + height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topInset + 8,
          horizontalPadding,
          22,
        ),
        child: child,
      ),
    );
  }
}
