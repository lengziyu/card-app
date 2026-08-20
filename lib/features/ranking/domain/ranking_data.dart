import 'package:cardfi/features/ranking/domain/local_article.dart';

class RankingGroup {
  const RankingGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.cardIds,
  });

  final String id;
  final String name;
  final String description;
  final List<String> cardIds;
}

class StablecoinAsset {
  const StablecoinAsset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.marketCap,
    required this.dominance,
    required this.color,
    this.change = 0,
    this.chains = const [],
    this.imageUrl,
  });

  final String id;
  final String symbol;
  final String name;
  final String marketCap;
  final double dominance;
  final int color;
  final double change;
  final List<String> chains;
  final String? imageUrl;
}

class StablecoinDetail {
  const StablecoinDetail({
    required this.id,
    required this.name,
    required this.symbol,
    required this.history,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String symbol;
  final List<double> history;
  final DateTime? updatedAt;
}

class StablecoinChain {
  const StablecoinChain({
    required this.name,
    required this.value,
    required this.share,
    this.imageUrl,
    this.color,
  });

  final String name;
  final String value;
  final double share;
  final String? imageUrl;
  final int? color;
}

class StablecoinDashboard {
  const StablecoinDashboard({
    required this.sourceLabel,
    required this.updatedAt,
    required this.totalMarketCap,
    required this.totalVolume,
    required this.trackedAssets,
    required this.history,
    this.histories = const {},
    required this.assets,
    required this.chains,
  });

  final String sourceLabel;
  final DateTime? updatedAt;
  final String totalMarketCap;
  final String totalVolume;
  final int trackedAssets;
  final List<double> history;
  final Map<String, List<double>> histories;
  final List<StablecoinAsset> assets;
  final List<StablecoinChain> chains;

  double get intervalChange {
    if (history.length < 2 || history.first == 0) return 0;
    return (history.last - history.first) / history.first * 100;
  }

  List<double> historyFor(String range) => histories[range] ?? history;

  double intervalChangeFor(String range) {
    final values = historyFor(range);
    if (values.length < 2 || values.first == 0) return 0;
    return (values.last - values.first) / values.first * 100;
  }
}

class UserRankingEntry {
  const UserRankingEntry({
    required this.id,
    required this.displayName,
    required this.monthlyActivityScore,
    required this.totalContributionScore,
    required this.acceptedContributions,
    required this.activeDays,
    this.avatarUrl,
    this.isPro = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String displayName;
  final int monthlyActivityScore;
  final int totalContributionScore;
  final int acceptedContributions;
  final int activeDays;
  final String? avatarUrl;

  /// Comes from server-verified entitlement data. It never changes the score.
  final bool isPro;
  final bool isCurrentUser;
}

class UserRankingDashboard {
  const UserRankingDashboard({
    required this.periodLabel,
    required this.methodology,
    required this.items,
    this.updatedAt,
    this.isPreview = false,
  });

  final String periodLabel;
  final String methodology;
  final List<UserRankingEntry> items;
  final DateTime? updatedAt;
  final bool isPreview;
}

class CardMetric {
  const CardMetric({
    required this.id,
    required this.name,
    required this.cardId,
    required this.logoText,
    this.logo = '',
    required this.sevenDay,
    required this.thirtyDay,
    required this.total,
    required this.transactions,
    required this.addresses,
  });

  final String id;
  final String name;
  final String? cardId;
  final String logoText;
  final String logo;
  final num sevenDay;
  final num thirtyDay;
  final num total;
  final num transactions;
  final num addresses;
}

class CardMetricsDashboard {
  const CardMetricsDashboard({
    required this.source,
    required this.updatedAt,
    required this.methodology,
    required this.items,
  });

  final String source;
  final DateTime? updatedAt;
  final String methodology;
  final List<CardMetric> items;
}

class ArticleFeedItem {
  const ArticleFeedItem({
    required this.slug,
    required this.article,
    required this.coverImageUrl,
    required this.viewCount,
    required this.likeCount,
    this.category = ArticleFeedCategory.news,
  });

  final String slug;
  final LocalArticle article;
  final String? coverImageUrl;
  final int viewCount;
  final int likeCount;
  final ArticleFeedCategory category;
}

enum ArticleFeedCategory {
  news,
  globalAccount,
  benefit,
  openCard,
  communityTip,
}
