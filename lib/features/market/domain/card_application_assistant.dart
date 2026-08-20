class CardApplicationProfile {
  const CardApplicationProfile({
    required this.cardId,
    required this.residence,
    required this.applicantType,
    required this.document,
    required this.stage,
    required this.language,
    this.residenceCountryCode = '',
    this.question = '',
  });

  final String cardId;
  final String residence;
  final String residenceCountryCode;
  final String applicantType;
  final String document;
  final String stage;
  final String language;
  final String question;

  Map<String, Object?> toJson() => {
    'cardId': cardId,
    'residence': residence,
    if (residenceCountryCode.isNotEmpty)
      'residenceCountryCode': residenceCountryCode,
    'applicantType': applicantType,
    'document': document,
    'stage': stage,
    'language': language,
    'question': question,
  };
}

class CardApplicationChecklistItem {
  const CardApplicationChecklistItem({
    required this.title,
    required this.detail,
    this.sourceIds = const [],
  });

  final String title;
  final String detail;
  final List<String> sourceIds;

  factory CardApplicationChecklistItem.fromJson(Map<String, dynamic> json) =>
      CardApplicationChecklistItem(
        title: json['title']?.toString().trim() ?? '',
        detail: json['detail']?.toString().trim() ?? '',
        sourceIds: _stringList(json['sourceIds']),
      );
}

class CardApplicationSource {
  const CardApplicationSource({
    required this.id,
    required this.type,
    required this.title,
    required this.url,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String title;
  final String url;
  final DateTime? updatedAt;

  bool get isProjectArticle => type == 'project_article';

  String? get articleSlug => isProjectArticle && id.startsWith('article:')
      ? id.substring('article:'.length).trim()
      : null;

  factory CardApplicationSource.fromJson(Map<String, dynamic> json) =>
      CardApplicationSource(
        id: json['id']?.toString().trim() ?? '',
        type: json['type']?.toString().trim() ?? '',
        title: json['title']?.toString().trim() ?? '',
        url: json['url']?.toString().trim() ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}

class CardApplicationAssistantResult {
  const CardApplicationAssistantResult({
    required this.summary,
    required this.sourceMode,
    required this.checklist,
    required this.warnings,
    required this.unknowns,
    required this.nextSteps,
    required this.sources,
    required this.disclaimer,
  });

  final String summary;
  final String sourceMode;
  final List<CardApplicationChecklistItem> checklist;
  final List<String> warnings;
  final List<String> unknowns;
  final List<String> nextSteps;
  final List<CardApplicationSource> sources;
  final String disclaimer;

  factory CardApplicationAssistantResult.fromJson(Map<String, dynamic> json) {
    return CardApplicationAssistantResult(
      summary: json['summary']?.toString().trim() ?? '',
      sourceMode: json['sourceMode']?.toString().trim() ?? 'project_articles',
      checklist: _objectList(json['checklist'])
          .map(CardApplicationChecklistItem.fromJson)
          .where((item) => item.title.isNotEmpty && item.detail.isNotEmpty)
          .take(8)
          .toList(growable: false),
      warnings: _stringList(json['warnings'], limit: 6),
      unknowns: _stringList(json['unknowns'], limit: 6),
      nextSteps: _stringList(json['nextSteps'], limit: 6),
      sources: _objectList(json['sources'])
          .map(CardApplicationSource.fromJson)
          .where((source) => source.id.isNotEmpty && source.title.isNotEmpty)
          .take(8)
          .toList(growable: false),
      disclaimer: json['disclaimer']?.toString().trim() ?? '',
    );
  }
}

List<String> _stringList(Object? value, {int limit = 12}) =>
    (value is List ? value : const <Object?>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(limit)
        .toList(growable: false);

List<Map<String, dynamic>> _objectList(Object? value) =>
    (value is List ? value : const <Object?>[])
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
