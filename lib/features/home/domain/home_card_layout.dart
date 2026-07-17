const double homeCardPreviewDefault = 392;
const double homeCardPreviewMin = 125;
const double homeCardPreviewMax = 630;

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
