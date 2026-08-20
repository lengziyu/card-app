import 'dart:ui';

import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A route-level return-to-top control matching the H5 floating affordance.
/// The parent decides when it is shown so this stays reusable across feeds.
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    required this.visible,
    required this.onTap,
    super.key,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: reduceMotion ? Duration.zero : MotionTokens.stateChange,
        curve: MotionTokens.standardEnter,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, .34),
          duration: reduceMotion ? Duration.zero : MotionTokens.contentSwitch,
          curve: MotionTokens.standardEnter,
          child: AnimatedScale(
            scale: visible ? 1 : .86,
            duration: reduceMotion ? Duration.zero : MotionTokens.stateChange,
            curve: MotionTokens.standardEnter,
            child: Semantics(
              button: true,
              label: context.tr('回到顶部'),
              child: GestureDetector(
                onTap: () {
                  AppHaptics.lightImpact();
                  onTap();
                },
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.isDark
                            ? Colors.white.withValues(alpha: .16)
                            : Colors.white.withValues(alpha: .9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.isDark
                              ? Colors.black.withValues(alpha: .30)
                              : const Color(0xFF46507E).withValues(alpha: .18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: ColoredBox(
                          color: AppColors.isDark
                              ? const Color(0xD62A2E40)
                              : const Color(0xE0FFFFFF),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.isDark
                                ? Colors.white.withValues(alpha: .9)
                                : const Color(0xFF10131D),
                            size: 20,
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
