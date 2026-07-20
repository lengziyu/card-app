import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CardTransformState {
  const CardTransformState({
    required this.top,
    required this.left,
    required this.scale,
    required this.opacity,
    required this.rotation,
    required this.elevation,
    required this.zIndex,
  });

  final double top;
  final double left;
  final double scale;
  final double opacity;
  final double rotation;
  final double elevation;
  final int zIndex;

  CardTransformState copyWith({
    double? top,
    double? left,
    double? scale,
    double? opacity,
    double? rotation,
    double? elevation,
    int? zIndex,
  }) {
    return CardTransformState(
      top: top ?? this.top,
      left: left ?? this.left,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      elevation: elevation ?? this.elevation,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  static CardTransformState lerp(
    CardTransformState begin,
    CardTransformState end,
    double progress,
  ) {
    return CardTransformState(
      top: lerpDouble(begin.top, end.top, progress)!,
      left: lerpDouble(begin.left, end.left, progress)!,
      scale: lerpDouble(begin.scale, end.scale, progress)!,
      opacity: lerpDouble(begin.opacity, end.opacity, progress)!,
      rotation: lerpDouble(begin.rotation, end.rotation, progress)!,
      elevation: lerpDouble(begin.elevation, end.elevation, progress)!,
      zIndex: (begin.zIndex + (end.zIndex - begin.zIndex) * progress).round(),
    );
  }
}
