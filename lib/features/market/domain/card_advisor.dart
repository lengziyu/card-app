class CardAdvisorProfile {
  const CardAdvisorProfile({
    required this.residence,
    required this.document,
    required this.useCase,
    required this.kycPreference,
    required this.language,
    this.residenceCountryCode = '',
    this.note = '',
  });

  final String residence;
  final String residenceCountryCode;
  final String document;
  final String useCase;
  final String kycPreference;

  /// BCP-47 locale used only for response copy; it is not persisted.
  final String language;
  final String note;

  Map<String, Object?> toJson() => {
    'residence': residence,
    if (residenceCountryCode.isNotEmpty)
      'residenceCountryCode': residenceCountryCode,
    'document': document,
    'useCase': useCase,
    'kycPreference': kycPreference,
    'language': language,
    'note': note,
  };
}

class CardAdvisorRecommendation {
  const CardAdvisorRecommendation({
    required this.cardId,
    required this.reason,
    required this.cautions,
  });

  final String cardId;
  final String reason;
  final String cautions;

  factory CardAdvisorRecommendation.fromJson(Map<String, dynamic> json) =>
      CardAdvisorRecommendation(
        cardId: json['cardId']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        cautions: json['cautions']?.toString() ?? '',
      );
}

class CardAdvisorResult {
  const CardAdvisorResult({
    required this.summary,
    required this.recommendations,
    required this.nextSteps,
    required this.disclaimer,
  });

  final String summary;
  final List<CardAdvisorRecommendation> recommendations;
  final List<String> nextSteps;
  final String disclaimer;

  factory CardAdvisorResult.fromJson(Map<String, dynamic> json) {
    List<dynamic> listOf(Object? value) => value is List ? value : const [];
    Map<String, dynamic> objectOf(Object? value) =>
        value is Map<String, dynamic>
        ? value
        : value is Map
        ? value.map((key, value) => MapEntry(key.toString(), value))
        : const {};
    return CardAdvisorResult(
      summary: json['summary']?.toString() ?? '',
      recommendations: listOf(json['recommendations'])
          .map((item) => CardAdvisorRecommendation.fromJson(objectOf(item)))
          .where((item) => item.cardId.isNotEmpty && item.reason.isNotEmpty)
          .toList(growable: false),
      nextSteps: listOf(json['nextSteps'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}
