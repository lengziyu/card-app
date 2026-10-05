class CardCommentAuthor {
  const CardCommentAuthor({
    required this.displayName,
    required this.blockingKey,
    this.avatarUrl,
  });

  final String displayName;
  final String blockingKey;
  final String? avatarUrl;
}

class CardComment {
  const CardComment({
    required this.id,
    required this.cardId,
    required this.body,
    required this.status,
    required this.likeCount,
    required this.liked,
    required this.isMine,
    required this.createdAt,
    required this.author,
    this.moderationNote,
  });

  final String id;
  final String cardId;
  final String body;
  final String status;
  final int likeCount;
  final bool liked;
  final bool isMine;
  final DateTime createdAt;
  final CardCommentAuthor author;
  final String? moderationNote;

  bool get pending => status == 'pending';

  CardComment copyWith({bool? liked, int? likeCount}) => CardComment(
    id: id,
    cardId: cardId,
    body: body,
    status: status,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
    isMine: isMine,
    createdAt: createdAt,
    author: author,
    moderationNote: moderationNote,
  );
}

class CardCommentPageData {
  const CardCommentPageData({
    required this.enabled,
    required this.writeEnabled,
    required this.moderationRequired,
    required this.total,
    required this.items,
    this.nextCursor,
  });

  final bool enabled;
  final bool writeEnabled;
  final bool moderationRequired;
  final int total;
  final List<CardComment> items;
  final String? nextCursor;
}
