import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum LocalSubmissionCategory { correction, recommendation, message }

extension LocalSubmissionCategoryLabel on LocalSubmissionCategory {
  String get label => switch (this) {
    LocalSubmissionCategory.correction => '信息纠错',
    LocalSubmissionCategory.recommendation => '卡片推荐',
    LocalSubmissionCategory.message => '反馈',
  };
}

class LocalSubmissionDraft {
  const LocalSubmissionDraft({
    required this.category,
    required this.description,
    this.subject,
    this.link,
    this.cardId,
    this.cardName,
  });

  final LocalSubmissionCategory category;
  final String description;
  final String? subject;
  final String? link;
  final String? cardId;
  final String? cardName;
}

class LocalSubmission {
  const LocalSubmission({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
    this.subject,
    this.link,
    this.cardId,
    this.cardName,
  });

  factory LocalSubmission.fromDraft(
    LocalSubmissionDraft draft, {
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now();
    return LocalSubmission(
      id: '${timestamp.microsecondsSinceEpoch}-${draft.category.name}',
      category: draft.category,
      description: draft.description.trim(),
      createdAt: timestamp,
      subject: _cleanOptional(draft.subject),
      link: _cleanOptional(draft.link),
      cardId: _cleanOptional(draft.cardId),
      cardName: _cleanOptional(draft.cardName),
    );
  }

  factory LocalSubmission.fromJson(Map<String, Object?> json) {
    return LocalSubmission(
      id: json['id']?.toString() ?? '',
      category: LocalSubmissionCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => LocalSubmissionCategory.message,
      ),
      description: json['description']?.toString().trim() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      subject: _cleanOptional(json['subject']?.toString()),
      link: _cleanOptional(json['link']?.toString()),
      cardId: _cleanOptional(json['cardId']?.toString()),
      cardName: _cleanOptional(json['cardName']?.toString()),
    );
  }

  final String id;
  final LocalSubmissionCategory category;
  final String description;
  final DateTime createdAt;
  final String? subject;
  final String? link;
  final String? cardId;
  final String? cardName;

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    if (subject != null) 'subject': subject,
    if (link != null) 'link': link,
    if (cardId != null) 'cardId': cardId,
    if (cardName != null) 'cardName': cardName,
  };
}

class LocalGuestState {
  const LocalGuestState({
    required this.addedCardIds,
    required this.favoriteCardIds,
    required this.favoriteArticleIds,
    required this.recentCardIds,
    required this.submissions,
  });

  factory LocalGuestState.fromJson(Map<String, Object?> json) {
    final rawSubmissions = json['submissions'];
    final submissions = rawSubmissions is List
        ? rawSubmissions
              .whereType<Map>()
              .map(
                (value) => LocalSubmission.fromJson(
                  value.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where(
                (value) => value.id.isNotEmpty && value.description.isNotEmpty,
              )
              .take(100)
              .toList(growable: false)
        : const <LocalSubmission>[];
    return LocalGuestState(
      addedCardIds: _normalizeIds(json['addedCardIds']),
      favoriteCardIds: _normalizeIds(json['favoriteCardIds']),
      favoriteArticleIds: _normalizeIds(json['favoriteArticleIds']),
      recentCardIds: _normalizeIds(json['recentCardIds'], limit: 8),
      submissions: submissions,
    );
  }

  final List<String> addedCardIds;
  final List<String> favoriteCardIds;
  final List<String> favoriteArticleIds;
  final List<String> recentCardIds;
  final List<LocalSubmission> submissions;

  Map<String, Object?> toJson() => {
    'version': 1,
    'addedCardIds': addedCardIds,
    'favoriteCardIds': favoriteCardIds,
    'favoriteArticleIds': favoriteArticleIds,
    'recentCardIds': recentCardIds,
    'submissions': submissions.map((value) => value.toJson()).toList(),
  };
}

class LocalGuestStateRepository {
  static const storageKey = 'card-app-guest-state-v1';

  Future<void> _writeQueue = Future.value();

  Future<LocalGuestState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return LocalGuestState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> save(LocalGuestState state) {
    final payload = jsonEncode(state.toJson());
    final previousWrite = _writeQueue;
    final nextWrite = () async {
      try {
        await previousWrite;
      } catch (_) {
        // A later state should still be allowed to repair a failed write.
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(storageKey, payload);
    }();
    _writeQueue = nextWrite;
    return nextWrite;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}

List<String> _normalizeIds(Object? value, {int limit = 240}) {
  if (value is! List) return const [];
  final result = <String>[];
  final seen = <String>{};
  for (final item in value) {
    final id = item.toString().trim();
    if (id.isEmpty || !seen.add(id)) continue;
    result.add(id);
    if (result.length >= limit) break;
  }
  return result;
}

String? _cleanOptional(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
