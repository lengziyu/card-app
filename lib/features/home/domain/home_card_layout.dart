export 'card_stack_mode.dart';

const double homeCardPreviewDefault = 392;
const double homeCardPreviewMin = 125;
const double homeCardPreviewMax = 630;
const double homeCardStackDefaultScale = .58;

const double homeCardHeightScaleMin =
    homeCardPreviewMin / homeCardPreviewDefault;
const double homeCardHeightScaleMax =
    homeCardPreviewMax / homeCardPreviewDefault;

double clampHomeCardHeightScale(double value) {
  return value.clamp(homeCardHeightScaleMin, homeCardHeightScaleMax).toDouble();
}

int homeCardHeightPercent(double scale) {
  return (homeCardPreviewDefault * scale / 6.3).round();
}
