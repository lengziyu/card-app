import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
  late final ScrollController _scrollController;
  final ValueNotifier<double> _headerProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateHeaderProgress);
  }

  void _updateHeaderProgress() {
    final next = (_scrollController.offset / 150).clamp(0.0, 1.0);
    if ((next - _headerProgress.value).abs() > .002) {
      _headerProgress.value = next;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateHeaderProgress)
      ..dispose();
    _headerProgress.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_liked || _liking) return;
    setState(() => _liking = true);
    try {
      await widget.onLike?.call();
      if (!mounted) return;
      setState(() => _liked = true);
      AppNotice.success(context, '感谢你的认可，点赞已经记录。', title: '点赞成功');
    } catch (_) {
      if (mounted) {
        AppNotice.error(context, '这次没有点赞成功，请稍后再试。', title: '网络开小差了');
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppNotice.success(context, '$label已复制：$value', title: '复制成功');
  }

  String get _markdown => widget.article.markdown?.trim().isNotEmpty == true
      ? widget.article.markdown!.trim()
      : widget.article.body.join('\n\n');

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final relatedCards = widget.cards
        .where((card) => article.relatedCardIds.contains(card.id))
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final markdownStyle = MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(
          p: TextStyle(color: AppColors.text, fontSize: 14, height: 1.78),
          h1: TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
          h2: TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.35,
          ),
          h3: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          a: TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700),
          blockquote: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.7,
          ),
          blockquoteDecoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: AppColors.violet, width: 3)),
          ),
          code: TextStyle(
            color: AppColors.text,
            backgroundColor: AppColors.violet.withValues(alpha: 0.1),
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: AppColors.glassStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          listBullet: TextStyle(color: AppColors.violet, fontSize: 15),
        );

    return Stack(
      key: const Key('article-detail-page'),
      children: [
        _ArticleTopFadedScroll(
          topInset: topInset,
          child: ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              88 + topInset,
              20,
              28 + bottomInset,
            ),
            children: [
              if (article.coverImageUrl case final cover?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      memCacheWidth: 1200,
                      maxWidthDiskCache: 1400,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, _) => AppShimmer(
                        child: ColoredBox(
                          color: AppColors.violet.withValues(alpha: 0.08),
                        ),
                      ),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  _MetaPill(label: article.category),
                  const Spacer(),
                  Text(
                    article.publishedLabel,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (article.author?.isNotEmpty == true) ...[
                    const SizedBox(width: 10),
                    Text(
                      article.author!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                article.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  article.summary,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
              ],
              if (article.inviteCode?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                _InviteRow(
                  label: '邀请码',
                  value: article.inviteCode!,
                  onCopy: () => _copy(article.inviteCode!, '邀请码'),
                ),
              ],
              if (article.inviteUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _InviteRow(
                  label: '邀请链接',
                  value: article.inviteUrl!,
                  onCopy: () => _copy(article.inviteUrl!, '邀请链接'),
                ),
              ],
              if (article.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in article.tags) _MetaPill(label: tag),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              MarkdownBody(data: _markdown, styleSheet: markdownStyle),
              const SizedBox(height: 22),
              Text(
                '本文仅整理公开信息，不构成金融建议。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
              if (relatedCards.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  '关联卡片',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '文章里提到的卡片可以直接点进去查看详情。',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                for (final card in relatedCards) ...[
                  CatalogCardRow(
                    card: card,
                    onTap: () => widget.onOpenCard(card),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      key: const Key('article-like'),
                      icon: _liked
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      label: _liking ? '点赞中…' : (_liked ? '已点赞' : '点赞'),
                      loading: _liking,
                      onTap: _liking ? null : _toggleLike,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionPill(
                      key: const Key('article-favorite'),
                      icon: widget.favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      label: widget.favorite ? '已收藏' : '收藏',
                      active: widget.favorite,
                      onTap: () {
                        AppHaptics.selection();
                        widget.onFavoriteChanged(!widget.favorite);
                      },
                    ),
                  ),
                  if (article.inviteCode?.isNotEmpty == true) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionPill(
                        key: const Key('article-copy-invite'),
                        icon: Icons.copy_rounded,
                        label: '复制邀请码',
                        onTap: () => _copy(article.inviteCode!, '邀请码'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: FrostedHeaderFade(
            height: 80 + topInset,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8 + topInset, 20, 24),
              child: _ArticleNavigation(
                onBack: widget.onBack,
                title: article.title,
                progress: _headerProgress,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleTopFadedScroll extends StatelessWidget {
  const _ArticleTopFadedScroll({required this.topInset, required this.child});

  final double topInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final hold = (topInset * .55 / bounds.height).clamp(0.0, .18);
        final fadeEnd = ((topInset + 72) / bounds.height).clamp(.05, .26);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.transparent,
            Colors.black,
            Colors.black,
          ],
          stops: [0, hold, fadeEnd, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _ArticleNavigation extends StatelessWidget {
  const _ArticleNavigation({
    required this.onBack,
    required this.title,
    required this.progress,
  });
  final VoidCallback onBack;
  final String title;
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MotionPressEffect(
        child: IconButton.filledTonal(
          key: const Key('article-back'),
          onPressed: onBack,
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.glassStrong,
            side: BorderSide(color: AppColors.line),
          ),
        ),
      ),
      Expanded(
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CollapsingHeaderTitle(title: title, progress: value),
          ),
        ),
      ),
      const SizedBox(width: 48),
    ],
  );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: 0.10),
      border: Border.all(color: AppColors.violet.withValues(alpha: 0.16)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppColors.violet,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: 0.07),
      border: Border.all(color: AppColors.violet.withValues(alpha: 0.15)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('复制'),
        ),
      ],
    ),
  );
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.loading = false,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) => MotionPressEffect(
    enabled: onTap != null,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: loading
          ? const AppLoadingIndicator(size: 17)
          : MotionStateIcon(stateKey: icon, child: Icon(icon, size: 17)),
      label: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MotionTokens.stateChange,
        child: Text(label, key: ValueKey(label)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        minimumSize: const Size(0, 42),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        foregroundColor: active ? AppColors.violet : AppColors.text,
        side: BorderSide(
          color: active
              ? AppColors.violet.withValues(alpha: 0.35)
              : AppColors.line,
        ),
        backgroundColor: active
            ? AppColors.violet.withValues(alpha: 0.1)
            : AppColors.glassStrong,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
