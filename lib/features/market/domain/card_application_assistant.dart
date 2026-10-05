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
        title: _resultText(json['title']),
        detail: _resultText(json['detail']),
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
      summary: _resultText(json['summary']),
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
      disclaimer: _resultText(json['disclaimer']),
    );
  }
}

List<String> _stringList(Object? value, {int limit = 12}) =>
    (value is List ? value : const <Object?>[])
        .map(_resultText)
        .where((item) => item.isNotEmpty)
        .take(limit)
        .toList(growable: false);

String _resultText(Object? value) {
  if (value == null) return '';
  if (value is String || value is num || value is bool) {
    return _sanitizeResultText(value.toString());
  }
  if (value is List) {
    return value.map(_resultText).where((item) => item.isNotEmpty).join('；');
  }
  if (value is Map) {
    final normalized = value.map((key, item) => MapEntry(key.toString(), item));
    final title = _resultText(
      normalized['title'] ??
          normalized['label'] ??
          normalized['name'] ??
          normalized['item'] ??
          normalized['question'],
    );
    final detail = _resultText(
      normalized['detail'] ??
          normalized['description'] ??
          normalized['message'] ??
          normalized['text'] ??
          normalized['content'] ??
          normalized['reason'] ??
          normalized['action'] ??
          normalized['answer'] ??
          normalized['note'] ??
          normalized['value'],
    );
    if (title.isNotEmpty && detail.isNotEmpty && title != detail) {
      return _sanitizeResultText('$title：$detail');
    }
    return detail.isNotEmpty ? detail : title;
  }
  return '';
}

String _sanitizeResultText(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty || text.toLowerCase() == '[object object]') return '';
  return text
      .replaceAll(
        RegExp(
          r'\s*[（(][^（）()]*(?:mainlandAvailability|requiresOverseasAddress|requiresOverseasPhone|chinaIpBlocked|kycLevel)[^（）()]*[）)]',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'(?:mainlandAvailability|requiresOverseasAddress|requiresOverseasPhone|chinaIpBlocked|kycLevel)\s*[:=]\s*[a-z0-9_-]+\s*[,，;；]?',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+([，。；：,.!?])'), r'$1')
      .replaceAll(RegExp(r'^[,，;；:：\s]+|[,，;；:：\s]+$'), '')
      .trim();
}

List<Map<String, dynamic>> _objectList(Object? value) =>
    (value is List ? value : const <Object?>[])
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
