import 'package:flutter/material.dart';

/// Reveals an already-laid-out child without changing its size or position in
/// the surrounding layout.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    required this.child,
    this.animation,
    this.begin = .5,
    this.end = .82,
    this.offset = 10,
    super.key,
  });

  final Widget child;
  final Animation<double>? animation;
  final double begin;
  final double end;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final parent = animation;
    if (parent == null || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: parent,
      child: child,
      builder: (context, child) {
        final curve = parent.status == AnimationStatus.reverse
            ? Curves.easeInCubic
            : Curves.easeOutCubic;
        final value = Interval(
          begin,
          end,
          curve: curve,
        ).transform(parent.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offset),
            child: child,
          ),
        );
      },
    );
  }
}
