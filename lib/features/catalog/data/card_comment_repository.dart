import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/data/comment_safety_store.dart';
import 'package:cardfi/features/catalog/domain/card_comment.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

typedef CommentAccessTokenProvider = Future<String?> Function();

class CardCommentRepository {
  CardCommentRepository(
    this._apiClient, {
    CommentSafetyStore? safetyStore,
    this.accessTokenProvider,
  }) : safetyStore = safetyStore ?? CommentSafetyStore();

  final ApiClient _apiClient;
  final CommentSafetyStore safetyStore;
  final CommentAccessTokenProvider? accessTokenProvider;

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'h5',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = (await accessTokenProvider?.call())?.trim();
    return token == null || token.isEmpty
        ? const <String, String>{}
        : {'authorization': 'Bearer $token'};
  }

  Future<CardCommentPageData> load(
    String cardId, {
    String sort = 'latest',
    String? cursor,
    int limit = 20,
  }) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/cards/${Uri.encodeComponent(cardId)}/comments',
        query: {
          'platform': _platform,
          'sort': sort,
          'limit': limit,
          'cursor': ?cursor,
        },
        headers: await _authHeaders(),
      ),
      label: '评论列表',
    );
    final comments = jsonList(response['items'] ?? const [], label: '评论列表')
        .map((item) => _comment(jsonObject(item, label: '评论')))
        .toList(growable: false);
    final blockedKeys = await safetyStore.blockedKeys();
    final hiddenReportedIds = await safetyStore.hiddenReportedCommentIds();
    return CardCommentPageData(
      enabled: response['enabled'] == true,
      writeEnabled: response['writeEnabled'] == true,
      // Older servers did not expose this flag and always moderated comments.
      // Preserve that behavior during a staged backend/app rollout.
      moderationRequired: response.containsKey('moderationRequired')
          ? response['moderationRequired'] == true
          : true,
      total: _int(response['total']),
      items: comments
          .where(
            (comment) =>
                !blockedKeys.contains(comment.author.blockingKey) &&
                !hiddenReportedIds.contains(comment.id),
          )
          .toList(growable: false),
      nextCursor: _nullable(response['nextCursor']),
    );
  }

  Future<CardComment> create(String cardId, String body) async {
    final response = jsonObject(
      await _apiClient.post(
        '/api/cards/${Uri.encodeComponent(cardId)}/comments?platform=$_platform',
        body: {'body': body},
        headers: await _authHeaders(),
      ),
      label: '评论提交结果',
    );
    return _comment(jsonObject(response['item'], label: '评论'));
  }

  Future<({bool liked, int likeCount})> setLiked(
    String commentId,
    bool liked,
  ) async {
    final response = jsonObject(
      await _apiClient.put(
        '/api/comments/${Uri.encodeComponent(commentId)}/like?platform=$_platform',
        body: {'liked': liked},
        headers: await _authHeaders(),
      ),
      label: '点赞结果',
    );
    return (
      liked: response['liked'] == true,
      likeCount: _int(response['likeCount']),
    );
  }

  Future<void> report(String commentId, String reason) async {
    await _apiClient.post(
      '/api/comments/${Uri.encodeComponent(commentId)}/reports?platform=$_platform',
      body: {'reason': reason},
      headers: await _authHeaders(),
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _apiClient.delete(
      '/api/comments/${Uri.encodeComponent(commentId)}?platform=$_platform',
      headers: await _authHeaders(),
    );
  }

  Future<void> blockAuthor(CardComment comment) => safetyStore.block(
    key: comment.author.blockingKey,
    displayName: comment.author.displayName,
  );

  Future<List<BlockedCommentAuthor>> blockedAuthors() =>
      safetyStore.blockedAuthors();

  Future<void> unblockAuthor(String blockingKey) =>
      safetyStore.unblock(blockingKey);

  Future<void> hideReportedComment(String commentId) =>
      safetyStore.hideReportedComment(commentId);

  CardComment _comment(Map<String, dynamic> value) {
    final author = jsonObject(value['author'] ?? const {}, label: '评论作者');
    final avatarPath = _nullable(author['avatarUrl']);
    final displayName = author['displayName']?.toString().trim() ?? '';
    final serverBlockingKey = _nullable(author['blockingKey']);
    final fallbackIdentity = [displayName, avatarPath ?? ''].join('|');
    final blockingKey = sha256
        .convert(utf8.encode(serverBlockingKey ?? fallbackIdentity))
        .toString();
    return CardComment(
      id: value['id']?.toString() ?? '',
      cardId: value['cardId']?.toString() ?? '',
      body: value['body']?.toString() ?? '',
      status: value['status']?.toString() ?? 'published',
      likeCount: _int(value['likeCount']),
      liked: value['liked'] == true,
      isMine: value['isMine'] == true,
      createdAt:
          DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      author: CardCommentAuthor(
        displayName: displayName.isEmpty ? '卡友' : displayName,
        blockingKey: blockingKey,
        avatarUrl: avatarPath == null
            ? null
            : _apiClient.resolve(avatarPath).toString(),
      ),
      moderationNote: _nullable(value['moderationNote']),
    );
  }

  int _int(Object? value) => NumberParsing.intValue(value);

  String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

abstract final class NumberParsing {
  static int intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
