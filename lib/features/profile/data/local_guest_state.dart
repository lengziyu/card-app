import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

const maxLocalSubmissionImages = 3;
const maxLocalSubmissionImageBytes = 4 * 1024 * 1024;
const maxLocalSubmissionImageTotalBytes = 10 * 1024 * 1024;

enum LocalSubmissionCategory { correction, recommendation, tip, message }

extension LocalSubmissionCategoryLabel on LocalSubmissionCategory {
  String get label => switch (this) {
    LocalSubmissionCategory.correction => '信息纠错',
    LocalSubmissionCategory.recommendation => '卡片推荐',
    LocalSubmissionCategory.tip => '技巧投稿',
    LocalSubmissionCategory.message => '反馈',
  };
}

enum LocalSubmissionStatus { received, reviewing, accepted, resolved, declined }

extension LocalSubmissionStatusInfo on LocalSubmissionStatus {
  String get label => switch (this) {
    LocalSubmissionStatus.received => '已收到',
    LocalSubmissionStatus.reviewing => '审核中',
    LocalSubmissionStatus.accepted => '已采纳',
    LocalSubmissionStatus.resolved => '已更新',
    LocalSubmissionStatus.declined => '暂未采纳',
  };

  String get description => switch (this) {
    LocalSubmissionStatus.received => '已进入处理队列',
    LocalSubmissionStatus.reviewing => '正在核对资料与可执行性',
    LocalSubmissionStatus.accepted => '建议已采纳，等待完成更新',
    LocalSubmissionStatus.resolved => '本次反馈已经处理完成',
    LocalSubmissionStatus.declined => '本次暂未采纳，请查看处理说明',
  };

  bool get isInProgress =>
      this == LocalSubmissionStatus.received ||
      this == LocalSubmissionStatus.reviewing;

  bool get isAccepted =>
      this == LocalSubmissionStatus.accepted ||
      this == LocalSubmissionStatus.resolved;
}

class LocalSubmissionDraft {
  const LocalSubmissionDraft({
    required this.category,
    required this.description,
    this.subject,
    this.link,
    this.cardId,
    this.cardName,
    this.images = const [],
    this.publishAnonymously = true,
  });

  final LocalSubmissionCategory category;
  final String description;
  final String? subject;
  final String? link;
  final String? cardId;
  final String? cardName;
  final List<LocalSubmissionImage> images;
  final bool publishAnonymously;
}

class LocalSubmissionImage {
  LocalSubmissionImage({
    required Uint8List bytes,
    required this.fileName,
    required this.mimeType,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class LocalSubmission {
  const LocalSubmission({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
    this.status = LocalSubmissionStatus.received,
    this.updatedAt,
    this.statusNote,
    this.adminReply,
    this.repliedAt,
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
      status: LocalSubmissionStatus.received,
      updatedAt: timestamp,
      subject: _cleanOptional(draft.subject),
      link: _cleanOptional(draft.link),
      cardId: _cleanOptional(draft.cardId),
      cardName: _cleanOptional(draft.cardName),
    );
  }

  factory LocalSubmission.fromJson(Map<String, Object?> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return LocalSubmission(
      id: json['id']?.toString() ?? '',
      category: LocalSubmissionCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => LocalSubmissionCategory.message,
      ),
      description: json['description']?.toString().trim() ?? '',
      createdAt: createdAt,
      status: _submissionStatusFromJson(json),
      updatedAt:
          _dateFromJson(json, const ['updatedAt', 'statusUpdatedAt']) ??
          createdAt,
      statusNote: _firstCleanValue(json, const ['statusNote', 'statusMessage']),
      adminReply: _firstCleanValue(json, const [
        'adminReply',
        'reply',
        'response',
      ]),
      repliedAt: _dateFromJson(json, const [
        'repliedAt',
        'replyAt',
        'respondedAt',
      ]),
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
  final LocalSubmissionStatus status;
  final DateTime? updatedAt;
  final String? statusNote;
  final String? adminReply;
  final DateTime? repliedAt;
  final String? subject;
  final String? link;
  final String? cardId;
  final String? cardName;

  DateTime get lastActivityAt => repliedAt ?? updatedAt ?? createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (statusNote != null) 'statusNote': statusNote,
    if (adminReply != null) 'adminReply': adminReply,
    if (repliedAt != null) 'repliedAt': repliedAt!.toIso8601String(),
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
    'version': 2,
    'addedCardIds': addedCardIds,
    'favoriteCardIds': favoriteCardIds,
    'favoriteArticleIds': favoriteArticleIds,
    'recentCardIds': recentCardIds,
    'submissions': submissions.map((value) => value.toJson()).toList(),
  };
}

class LocalGuestStateRepository {
  static const legacyStorageKey = 'card-app-guest-state-v1';
  static const _userStorageKeyPrefix = 'card-app-user-state-v1:';

  Future<void> _writeQueue = Future.value();

  static String storageKeyForUser(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    final encodedUserId = base64Url
        .encode(utf8.encode(normalizedUserId))
        .replaceAll('=', '');
    return '$_userStorageKeyPrefix$encodedUserId';
  }

  Future<LocalGuestState?> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKeyForUser(userId));
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

  Future<void> save(String userId, LocalGuestState state) {
    final storageKey = storageKeyForUser(userId);
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

  Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKeyForUser(userId));
  }

  Future<void> clearLegacyState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(legacyStorageKey);
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

LocalSubmissionStatus _submissionStatusFromJson(Map<String, Object?> json) {
  final raw = (json['status'] ?? json['state'])
      ?.toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_');
  return switch (raw) {
    'reviewing' ||
    'in_review' ||
    'processing' => LocalSubmissionStatus.reviewing,
    'accepted' || 'adopted' || 'approved' => LocalSubmissionStatus.accepted,
    'resolved' ||
    'completed' ||
    'done' ||
    'updated' ||
    'published' => LocalSubmissionStatus.resolved,
    'declined' || 'rejected' || 'closed' => LocalSubmissionStatus.declined,
    _ => LocalSubmissionStatus.received,
  };
}

String? _firstCleanValue(Map<String, Object?> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = _cleanOptional(json[key]?.toString());
    if (value != null) return value;
  }
  return null;
}

DateTime? _dateFromJson(Map<String, Object?> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = DateTime.tryParse(json[key]?.toString() ?? '');
    if (value != null) return value;
  }
  return null;
}
