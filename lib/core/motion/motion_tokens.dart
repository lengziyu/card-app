import 'package:flutter/animation.dart';

/// Shared motion values for transitions that express app hierarchy changes.
abstract final class MotionTokens {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration press = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration stateChange = Duration(milliseconds: 220);
  static const Duration contentSwitch = Duration(milliseconds: 280);
  static const Duration tabSwitch = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 340);
  static const Duration pageReverse = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration sheetReverse = Duration(milliseconds: 260);
  static const Duration sharedCard = Duration(milliseconds: 360);
  static const Duration sharedCardReverse = Duration(milliseconds: 320);

  static const double pressedScale = .985;
  static const double compactPressedScale = .97;
  static const double incomingScale = .985;
  static const double outgoingScale = .992;
  static const double smallOffset = 8;
  static const double pageOffset = 12;

  static const Curve standardEnter = Cubic(.2, .78, .2, 1);
  static const Curve standardExit = Cubic(.4, 0, .6, 1);
}
