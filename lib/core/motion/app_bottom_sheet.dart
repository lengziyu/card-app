import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:flutter/material.dart';

typedef AppSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

Future<T?> showAppDraggableSheet<T>({
  required BuildContext context,
  required AppSheetBuilder builder,
  double initialSize = .68,
  double minSize = .38,
  double maxSize = .94,
  double barrierAlpha = .36,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: barrierAlpha),
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? Duration.zero : MotionTokens.sheet,
      reverseDuration: reduceMotion ? Duration.zero : MotionTokens.sheetReverse,
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      expand: false,
      snap: !reduceMotion,
      snapSizes: {minSize, initialSize, maxSize}.toList()..sort(),
      builder: builder,
    ),
  );
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double barrierAlpha = .36,
  bool useSafeArea = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: useSafeArea,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: barrierAlpha),
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? Duration.zero : MotionTokens.sheet,
      reverseDuration: reduceMotion ? Duration.zero : MotionTokens.sheetReverse,
    ),
    builder: builder,
  );
}
