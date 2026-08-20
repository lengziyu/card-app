import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/ranking/domain/local_article.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:cardfi/core/localization/localized_text.dart';
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
    this.onCorrection,
    super.key,
  });

  final LocalArticle article;
  final List<CardSummary> cards;
  final bool favorite;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<bool> onFavoriteChanged;
  final Future<void> Function()? onLike;
  final VoidCallback? onCorrection;

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
      AppNotice.success(
        context,
        widget.article.isCommunityTip ? '感谢反馈，已记录这个技巧对你有帮助。' : '感谢你的认可，点赞已经记录。',
        title: widget.article.isCommunityTip ? '已标记有帮助' : '点赞成功',
      );
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

  List<_ArticleImage> get _publicImages => widget.article.isCommunityTip
      ? _extractArticleImages(widget.article, _markdown)
      : const [];

  Future<void> _openImage(int index) async {
    final images = _publicImages;
    if (images.isEmpty || index < 0 || index >= images.length) return;
    AppHaptics.selection();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭图片浏览',
      barrierColor: Colors.black,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) =>
          _ArticleImageViewer(images: images, initialIndex: index),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  Widget _buildMarkdownImage(
    MarkdownImageConfig config,
    List<_ArticleImage> images,
  ) {
    final url = _normalizePublicImageUrl(config.uri.toString());
    final index = url == null
        ? -1
        : images.indexWhere((image) => image.url == url);
    if (url == null) return const SizedBox.shrink();
    return _ArticleInlineImage(
      key: index < 0 ? null : Key('article-inline-image-$index'),
      imageUrl: url,
      alt: config.alt,
      onTap: index < 0 ? null : () => _openImage(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final articleImages = _publicImages;
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
                Semantics(
                  button: article.isCommunityTip,
                  label: article.isCommunityTip ? '查看封面大图' : null,
                  child: GestureDetector(
                    key: article.isCommunityTip
                        ? const Key('article-cover-image')
                        : null,
                    onTap: article.isCommunityTip
                        ? () {
                            final url = _normalizePublicImageUrl(cover);
                            final index = articleImages.indexWhere(
                              (image) => image.url == url,
                            );
                            _openImage(index);
                          }
                        : null,
                    child: ClipRRect(
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
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaPill(label: article.category),
                  if (article.verifiedLabel case final verified?) ...[
                    _MetaPill(label: verified),
                  ],
                  Text(
                    article.publishedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (article.author?.isNotEmpty == true) ...[
                    Text(
                      article.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              MarkdownBody(
                data: _markdown,
                styleSheet: markdownStyle,
                sizedImageBuilder: article.isCommunityTip
                    ? (config) => _buildMarkdownImage(config, articleImages)
                    : null,
              ),
              const SizedBox(height: 22),
              Text(
                article.isCommunityTip
                    ? '本内容来自用户经验投稿，经基础内容审核，不代表发卡方官方说明。费用、地区、KYC 和功能可用性请以官方最新规则为准。'
                    : '本文仅整理公开信息，不构成金融建议。',
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
                      label: _liking
                          ? '提交中…'
                          : article.isCommunityTip
                          ? (_liked ? '已有帮助' : '有帮助')
                          : (_liked ? '已点赞' : '点赞'),
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
                  if (article.isCommunityTip &&
                      widget.onCorrection != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionPill(
                        key: const Key('article-correction'),
                        icon: Icons.rate_review_outlined,
                        label: '纠错',
                        onTap: widget.onCorrection,
                      ),
                    ),
                  ],
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

class _ArticleImage {
  const _ArticleImage({required this.url, required this.alt});

  final String url;
  final String alt;
}

List<_ArticleImage> _extractArticleImages(
  LocalArticle article,
  String markdown,
) {
  final images = <_ArticleImage>[];
  final seen = <String>{};

  void add(String rawUrl, String? rawAlt) {
    final url = _normalizePublicImageUrl(rawUrl);
    if (url == null || !seen.add(url)) return;
    final alt = rawAlt?.trim();
    images.add(
      _ArticleImage(url: url, alt: alt == null || alt.isEmpty ? '技巧配图' : alt),
    );
  }

  if (article.coverImageUrl case final cover?) add(cover, '文章封面');
  final imagePattern = RegExp(
    r'''!\[([^\]]*)\]\(\s*<?([^\s)>]+)>?(?:\s+["'][^)]*["'])?\s*\)''',
  );
  for (final match in imagePattern.allMatches(markdown)) {
    add(match.group(2) ?? '', match.group(1));
  }
  return List.unmodifiable(images);
}

String? _normalizePublicImageUrl(String rawUrl) {
  final source = rawUrl.trim().replaceAll('&amp;', '&');
  final uri = Uri.tryParse(source);
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) return null;
  return uri.replace(fragment: '').toString();
}

class _ArticleInlineImage extends StatelessWidget {
  const _ArticleInlineImage({
    required this.imageUrl,
    required this.alt,
    required this.onTap,
    super.key,
  });

  final String imageUrl;
  final String? alt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = alt?.trim().isNotEmpty == true ? alt!.trim() : '技巧配图';
    final width = MediaQuery.sizeOf(context).width - 40;
    return Semantics(
      button: onTap != null,
      label: onTap == null ? label : '查看大图：$label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 420),
          margin: const EdgeInsets.symmetric(vertical: 8),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 1200,
                maxWidthDiskCache: 1600,
                placeholder: (_, _) => AppShimmer(
                  child: ColoredBox(
                    color: AppColors.violet.withValues(alpha: 0.08),
                  ),
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: AppColors.glassStrong,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleImageViewer extends StatefulWidget {
  const _ArticleImageViewer({required this.images, required this.initialIndex});

  final List<_ArticleImage> images;
  final int initialIndex;

  @override
  State<_ArticleImageViewer> createState() => _ArticleImageViewerState();
}

class _ArticleImageViewerState extends State<_ArticleImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _currentImageZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _show(int index) {
    if (index < 0 || index >= widget.images.length || index == _currentIndex) {
      return;
    }
    AppHaptics.selection();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentImageZoomed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_currentIndex];
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      key: const Key('article-image-viewer'),
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              key: const Key('article-image-pages'),
              controller: _pageController,
              physics: _currentImageZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, index) => _ZoomableArticleImage(
                key: ValueKey('article-image-page-$index'),
                image: widget.images[index],
                active: index == _currentIndex,
                onZoomChanged: index == _currentIndex
                    ? (zoomed) {
                        if (mounted && zoomed != _currentImageZoomed) {
                          setState(() => _currentImageZoomed = zoomed);
                        }
                      }
                    : null,
              ),
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filled(
                  key: const Key('article-image-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    image.alt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '双指缩放 · 左右切换',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('article-image-previous'),
                        onPressed: _currentIndex == 0
                            ? null
                            : () => _show(_currentIndex - 1),
                        tooltip: '上一张',
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: Colors.white,
                        disabledColor: Colors.white30,
                      ),
                      Semantics(
                        label:
                            '第 ${_currentIndex + 1} 张，共 ${widget.images.length} 张',
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          key: const Key('article-image-position'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('article-image-next'),
                        onPressed: _currentIndex == widget.images.length - 1
                            ? null
                            : () => _show(_currentIndex + 1),
                        tooltip: '下一张',
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: Colors.white,
                        disabledColor: Colors.white30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableArticleImage extends StatefulWidget {
  const _ZoomableArticleImage({
    required this.image,
    required this.active,
    required this.onZoomChanged,
    super.key,
  });

  final _ArticleImage image;
  final bool active;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_ZoomableArticleImage> createState() => _ZoomableArticleImageState();
}

class _ZoomableArticleImageState extends State<_ZoomableArticleImage> {
  final TransformationController _transformationController =
      TransformationController();
  bool _zoomed = false;

  @override
  void didUpdateWidget(covariant _ZoomableArticleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _zoomed) {
      _transformationController.value = Matrix4.identity();
      _zoomed = false;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _updateZoom() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      key: Key('article-image-interactive-${widget.image.url}'),
      transformationController: _transformationController,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      scaleEnabled: true,
      boundaryMargin: const EdgeInsets.all(80),
      onInteractionUpdate: (_) => _updateZoom(),
      onInteractionEnd: (_) => _updateZoom(),
      child: Center(
        child: CachedNetworkImage(
          imageUrl: widget.image.url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 2200,
          maxWidthDiskCache: 2600,
          placeholder: (_, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 44,
            ),
          ),
        ),
      ),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
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
