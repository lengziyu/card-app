import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BlockedCommentAuthor {
  const BlockedCommentAuthor({required this.key, required this.displayName});

  final String key;
  final String displayName;

  Map<String, String> toJson() => {'key': key, 'displayName': displayName};

  static BlockedCommentAuthor? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final key = value['key']?.toString().trim() ?? '';
    final displayName = value['displayName']?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    return BlockedCommentAuthor(
      key: key,
      displayName: displayName.isEmpty ? '卡友' : displayName,
    );
  }
}

class CommentSafetyStore {
  CommentSafetyStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _storageKey = 'cardfi-blocked-comment-authors-v1';
  static const _reportedStorageKey = 'cardfi-hidden-reported-comments-v1';

  final Future<SharedPreferences> Function() _preferences;

  Future<List<BlockedCommentAuthor>> blockedAuthors() async {
    final preferences = await _preferences();
    final values = preferences.getStringList(_storageKey) ?? const [];
    final authors = <BlockedCommentAuthor>[];
    for (final value in values) {
      try {
        final author = BlockedCommentAuthor.fromJson(jsonDecode(value));
        if (author != null) authors.add(author);
      } catch (_) {
        // Ignore malformed legacy entries instead of breaking comment loading.
      }
    }
    authors.sort((a, b) => a.displayName.compareTo(b.displayName));
    return authors;
  }

  Future<Set<String>> blockedKeys() async =>
      (await blockedAuthors()).map((author) => author.key).toSet();

  Future<Set<String>> hiddenReportedCommentIds() async {
    final preferences = await _preferences();
    return (preferences.getStringList(_reportedStorageKey) ?? const []).toSet();
  }

  Future<void> hideReportedComment(String commentId) async {
    final normalizedId = commentId.trim();
    if (normalizedId.isEmpty) return;
    final preferences = await _preferences();
    final ids =
        (preferences.getStringList(_reportedStorageKey) ?? const []).toSet()
          ..add(normalizedId);
    await preferences.setStringList(_reportedStorageKey, ids.toList()..sort());
  }

  Future<void> block({required String key, required String displayName}) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;
    final authors = await blockedAuthors();
    final next = <BlockedCommentAuthor>[
      ...authors.where((author) => author.key != normalizedKey),
      BlockedCommentAuthor(
        key: normalizedKey,
        displayName: displayName.trim().isEmpty ? '卡友' : displayName.trim(),
      ),
    ];
    await _save(next);
  }

  Future<void> unblock(String key) async {
    final authors = await blockedAuthors();
    await _save(authors.where((author) => author.key != key).toList());
  }

  Future<void> _save(List<BlockedCommentAuthor> authors) async {
    final preferences = await _preferences();
    await preferences.setStringList(
      _storageKey,
      authors.map((author) => jsonEncode(author.toJson())).toList(),
    );
  }
}
