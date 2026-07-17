import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:flutter/material.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    required this.article,
    required this.cards,
    required this.favorite,
    required this.onBack,
    required this.onOpenCard,
    required this.onFavoriteChanged,
    this.onLike,
    super.key,
  });

  final LocalArticle article;
  final List<CardSummary> cards;
  final bool favorite;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<bool> onFavoriteChanged;
  final Future<void> Function()? onLike;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  bool _liked = false;
  bool _liking = false;

  Future<void> _toggleLike() async {
    if (_liked || _liking) return;
    setState(() => _liking = true);
    try {
      await widget.onLike?.call();
      if (mounted) setState(() => _liked = true);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedCards = widget.cards
        .where((card) => widget.article.relatedCardIds.contains(card.id))
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: Key('article-detail-page'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              key: Key('article-back'),
              onPressed: widget.onBack,
              tooltip: '返回',
              icon: Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: Size(48, 48),
                foregroundColor: AppColors.text,
                backgroundColor: AppColors.glassStrong,
                side: BorderSide(color: AppColors.line),
              ),
            ),
            SizedBox(width: 14),
            Text(
              '文章详情',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.article.category,
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  Text(
                    widget.article.publishedLabel,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                widget.article.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 12),
              Text(
                widget.article.summary,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.article.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.violet.withValues(alpha: 0.15),
                      side: BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(
                        color: AppColors.text,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
              Divider(height: 38, color: AppColors.line),
              for (final paragraph in widget.article.body) ...[
                Text(
                  paragraph,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.75,
                  ),
                ),
                SizedBox(height: 16),
              ],
              Text(
                '本文仅整理公开信息，不构成金融建议。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (relatedCards.isNotEmpty) ...[
          SizedBox(height: 22),
          Text(
            '相关卡片',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          for (final card in relatedCards) ...[
            CatalogCardRow(card: card, onTap: () => widget.onOpenCard(card)),
            SizedBox(height: 10),
          ],
        ],
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: Key('article-like'),
                onPressed: _liking ? null : _toggleLike,
                icon: Icon(_liked ? Icons.thumb_up : Icons.thumb_up_outlined),
                label: Text(_liking ? '提交中' : (_liked ? '已点赞' : '点赞')),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: Key('article-favorite'),
                onPressed: () => widget.onFavoriteChanged(!widget.favorite),
                icon: Icon(
                  widget.favorite ? Icons.star : Icons.star_border_rounded,
                ),
                label: Text(widget.favorite ? '已收藏' : '收藏'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
