abstract final class AppFeatureConfig {
  /// Kept off for production/review builds until Android and iOS edge-gesture
  /// regression testing is complete.
  static const edgeSwipeBackEnabled = bool.fromEnvironment(
    'ENABLE_EDGE_SWIPE_BACK',
    defaultValue: false,
  );
}
