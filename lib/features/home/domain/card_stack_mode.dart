enum CardStackMode { wallet, stack, focus }

extension CardStackModeAccess on CardStackMode {
  bool get requiresPro => this != CardStackMode.wallet;
}

extension CardStackModeCopy on CardStackMode {
  String get label => switch (this) {
    CardStackMode.stack => '堆叠',
    CardStackMode.focus => '聚焦',
    CardStackMode.wallet => '钱包',
  };
}

/// 兼容首页现有的持久化与调用方命名。
typedef HomeCardDisplayMode = CardStackMode;
