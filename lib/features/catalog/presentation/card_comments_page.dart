import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/data/card_comment_repository.dart';
import 'package:cardfi/features/catalog/data/comment_safety_store.dart';
import 'package:cardfi/features/catalog/domain/card_comment.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/profile/data/legal_config.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

class CardCommentPreview extends StatefulWidget {
  const CardCommentPreview({
    required this.card,
    required this.repository,
    required this.signedIn,
    required this.onLoginRequired,
    super.key,
  });

  final CardSummary card;
  final CardCommentRepository repository;
  final bool signedIn;
  final VoidCallback onLoginRequired;

  @override
  State<CardCommentPreview> createState() => _CardCommentPreviewState();
}

class _CardCommentPreviewState extends State<CardCommentPreview> {
  CardCommentPageData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CardCommentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.repository.load(widget.card.id, limit: 2);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open({bool compose = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CardCommentsPage(
          card: widget.card,
          repository: widget.repository,
          signedIn: widget.signedIn,
          onLoginRequired: widget.onLoginRequired,
          autofocusComposer: compose,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (!_loading && (data == null || !data.enabled)) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('card-comment-preview'),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1058659A),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, color: AppColors.violet, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '卡友讨论',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (data != null)
                Text(
                  '${data.total} 条公开',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (data!.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '还没有公开评论，欢迎分享真实使用体验。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (var index = 0; index < data.items.length; index++) ...[
              _CommentRow(comment: data.items[index], compact: true),
              if (index != data.items.length - 1)
                Divider(
                  height: 22,
                  color: AppColors.line.withValues(alpha: .7),
                ),
            ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('card-comments-open'),
                  onPressed: () => _open(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  child: const Text('查看全部评论  →'),
                ),
              ),
              if (data?.writeEnabled == true &&
                  data?.moderationRequired == true)
                FilledButton.tonalIcon(
                  key: const Key('card-comments-compose'),
                  onPressed: () => _open(compose: true),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('写评论'),
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    backgroundColor: AppColors.violet.withValues(alpha: .1),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CardCommentsPage extends StatefulWidget {
  const CardCommentsPage({
    required this.card,
    required this.repository,
    required this.signedIn,
    required this.onLoginRequired,
    this.autofocusComposer = false,
    super.key,
  });

  final CardSummary card;
  final CardCommentRepository repository;
  final bool signedIn;
  final VoidCallback onLoginRequired;
  final bool autofocusComposer;

  @override
  State<CardCommentsPage> createState() => _CardCommentsPageState();
}

class _CardCommentsPageState extends State<CardCommentsPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _comments = <CardComment>[];
  final _likingIds = <String>{};
  String _sort = 'latest';
  String? _nextCursor;
  bool _enabled = true;
  bool _writeEnabled = false;
  bool _publishingEnabled = false;
  bool _moderationRequired = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _loadFailed = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autofocusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.signedIn) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_nextCursor == null || _loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final result = await widget.repository.load(
        widget.card.id,
        sort: _sort,
        cursor: more ? _nextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        _enabled = result.enabled;
        _writeEnabled = result.writeEnabled;
        // Store-review builds never publish UGC immediately. A server-side
        // moderation flag is required before the composer is exposed.
        _publishingEnabled = result.writeEnabled && result.moderationRequired;
        _moderationRequired = result.moderationRequired;
        _total = result.total;
        _nextCursor = result.nextCursor;
        if (!more) _comments.clear();
        _comments.addAll(result.items);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadFailed = !more);
        AppNotice.error(context, context.tr('评论加载失败，请稍后重试'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _requireLogin() {
    Navigator.of(context).pop();
    widget.onLoginRequired();
  }

  Future<void> _submit() async {
    if (!widget.signedIn) return _requireLogin();
    final body = _controller.text.trim();
    if (body.isEmpty || body.length > 500) {
      AppNotice.warning(context, context.tr('评论需控制在 500 字以内'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = await widget.repository.create(widget.card.id, body);
      if (!mounted) return;
      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _comments.insert(0, comment);
        if (!comment.pending) _total += 1;
      });
      AppNotice.success(
        context,
        context.tr(comment.pending ? '评论已提交，审核通过后公开展示' : '评论已发布'),
      );
    } catch (error) {
      if (mounted) AppNotice.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleLike(CardComment comment) async {
    if (!widget.signedIn) return _requireLogin();
    if (_likingIds.contains(comment.id)) return;
    final index = _comments.indexWhere((item) => item.id == comment.id);
    if (index < 0) return;
    final desired = !comment.liked;
    setState(() {
      _likingIds.add(comment.id);
      _comments[index] = comment.copyWith(
        liked: desired,
        likeCount: (comment.likeCount + (desired ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
    AppHaptics.selection();
    try {
      final result = await widget.repository.setLiked(comment.id, desired);
      if (mounted) {
        final currentIndex = _comments.indexWhere(
          (item) => item.id == comment.id,
        );
        if (currentIndex >= 0) {
          setState(
            () => _comments[currentIndex] = _comments[currentIndex].copyWith(
              liked: result.liked,
              likeCount: result.likeCount,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        final currentIndex = _comments.indexWhere(
          (item) => item.id == comment.id,
        );
        if (currentIndex >= 0) {
          setState(() => _comments[currentIndex] = comment);
        }
        AppNotice.error(context, context.tr('操作失败，请稍后重试'));
      }
    } finally {
      if (mounted) {
        setState(() => _likingIds.remove(comment.id));
      }
    }
  }

  Future<void> _delete(CardComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteComment(comment.id);
      if (mounted) {
        setState(() {
          _comments.removeWhere((item) => item.id == comment.id);
          if (!comment.pending) _total = (_total - 1).clamp(0, 1 << 30);
        });
      }
    } catch (_) {
      if (mounted) {
        AppNotice.error(context, context.tr('删除失败，请稍后重试'));
      }
    }
  }

  Future<void> _report(CardComment comment) async {
    if (!widget.signedIn) return _requireLogin();
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '举报评论',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final reason in const [
              '包含隐私或敏感信息',
              '推广、邀请码或外部引流',
              '骚扰或不友善内容',
              '与卡片无关',
            ])
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await widget.repository.report(comment.id, reason);
      await widget.repository.hideReportedComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((item) => item.id == comment.id);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
      AppNotice.success(context, context.tr('举报已提交，已隐藏这条评论'));
    } catch (error) {
      if (mounted) AppNotice.error(context, error.toString());
    }
  }

  Future<void> _blockAuthor(CardComment comment) async {
    if (!widget.signedIn) return _requireLogin();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('屏蔽该用户？'),
        content: const Text('屏蔽后将隐藏该用户的评论。你可以在评论安全中心取消屏蔽。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('屏蔽'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.blockAuthor(comment);
    if (!mounted) return;
    setState(() {
      final hidden = _comments
          .where(
            (item) =>
                item.author.blockingKey == comment.author.blockingKey &&
                !item.pending,
          )
          .length;
      _comments.removeWhere(
        (item) => item.author.blockingKey == comment.author.blockingKey,
      );
      _total = (_total - hidden).clamp(0, 1 << 30);
    });
    AppNotice.success(context, context.tr('已屏蔽该用户'));
  }

  Future<void> _openSafetyCenter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CommentSafetySheet(repository: widget.repository),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      key: const Key('card-comments-page'),
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text('卡友讨论'),
        actions: [
          IconButton(
            key: const Key('comment-safety-center'),
            tooltip: '评论安全与社区规则',
            onPressed: _openSafetyCenter,
            icon: const Icon(Icons.shield_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_enabled
          ? Center(
              child: Text(
                '评论区暂未开放',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : Column(
              children: [
                _CardDiscussionHeader(card: widget.card),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(14) > 17;
                      final compact = constraints.maxWidth < 360 || largeText;
                      final count = Text(
                        '$_total 条公开评论',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                      final selector = _CommentSortControl(
                        selected: _sort,
                        onChanged: (value) {
                          if (_sort == value) return;
                          setState(() => _sort = value);
                          _load();
                        },
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            count,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: selector,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: count),
                          selector,
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadFailed
                      ? _CommentLoadError(onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _comments.isEmpty
                              ? _CommentEmptyState(
                                  moderationRequired: _moderationRequired,
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    24,
                                  ),
                                  itemCount:
                                      _comments.length +
                                      (_nextCursor == null ? 0 : 1),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    if (index == _comments.length) {
                                      return Center(
                                        child: TextButton(
                                          onPressed: _loadingMore
                                              ? null
                                              : () => _load(more: true),
                                          child: Text(
                                            _loadingMore ? '加载中…' : '加载更多',
                                          ),
                                        ),
                                      );
                                    }
                                    final comment = _comments[index];
                                    return _CommentCard(
                                      comment: comment,
                                      liking: _likingIds.contains(comment.id),
                                      onLike: _writeEnabled
                                          ? () => _toggleLike(comment)
                                          : null,
                                      onDelete: _writeEnabled && comment.isMine
                                          ? () => _delete(comment)
                                          : null,
                                      onReport: !_writeEnabled || comment.isMine
                                          ? null
                                          : () => _report(comment),
                                      onBlock: comment.isMine
                                          ? null
                                          : () => _blockAuthor(comment),
                                    );
                                  },
                                ),
                        ),
                ),
                if (_publishingEnabled)
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.isDark
                                ? const Color(0x38000000)
                                : const Color(0x1458659A),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const Key('comment-rules-from-composer'),
                                onPressed: _openSafetyCenter,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textMuted,
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    0,
                                    8,
                                    7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 15,
                                ),
                                label: const Text(
                                  '内容经人工审核后公开 · 查看社区规则',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('card-comment-input'),
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    readOnly: !widget.signedIn,
                                    onTap: widget.signedIn
                                        ? null
                                        : _requireLogin,
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: 500,
                                    decoration: InputDecoration(
                                      hintText: widget.signedIn
                                          ? '分享真实使用体验…'
                                          : '登录后参与讨论',
                                      counterText: '',
                                      filled: true,
                                      fillColor: AppColors.surfaceRaised,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.violet.withValues(
                                            alpha: .10,
                                          ),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.violet.withValues(
                                            alpha: .55,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filled(
                                  key: const Key('card-comment-submit'),
                                  onPressed: _submitting ? null : _submit,
                                  icon: _submitting
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_upward_rounded),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    backgroundColor: AppColors.violet,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CardDiscussionHeader extends StatelessWidget {
  const _CardDiscussionHeader({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppColors.isDark
          ? null
          : const [
              BoxShadow(
                color: Color(0x0E58659A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            key: Key('card-comment-artwork-${card.id}'),
            width: 104,
            height: 65,
            child: CardArtwork(
              card: card,
              showGeneratedLabels: false,
              memCacheWidth: 360,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                card.issuer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.forum_outlined, color: AppColors.violet, size: 18),
        ),
      ],
    ),
  );
}

class _CommentSortControl extends StatelessWidget {
  const _CommentSortControl({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommentSortOption(
          label: '最新',
          value: 'latest',
          selected: selected == 'latest',
          onTap: onChanged,
        ),
        _CommentSortOption(
          label: '最有帮助',
          value: 'helpful',
          selected: selected == 'helpful',
          onTap: onChanged,
        ),
      ],
    ),
  );
}

class _CommentSortOption extends StatelessWidget {
  const _CommentSortOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.violet.withValues(alpha: .13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.violet : AppColors.textMuted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _CommentLoadError extends StatelessWidget {
  const _CommentLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
    children: [
      Icon(
        Icons.forum_outlined,
        size: 38,
        color: AppColors.textMuted.withValues(alpha: .7),
      ),
      const SizedBox(height: 14),
      Text(
        '暂时无法加载评论',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '请检查网络后重试，卡片其他信息不受影响。',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, height: 1.5),
      ),
      const SizedBox(height: 16),
      Center(
        child: OutlinedButton.icon(
          key: const Key('card-comments-retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重新加载'),
        ),
      ),
    ],
  );
}

class _CommentEmptyState extends StatelessWidget {
  const _CommentEmptyState({required this.moderationRequired});

  final bool moderationRequired;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
    children: [
      Icon(
        Icons.chat_bubble_outline_rounded,
        size: 38,
        color: AppColors.violet.withValues(alpha: .65),
      ),
      const SizedBox(height: 14),
      Text(
        '还没有公开评论',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        moderationRequired
            ? '欢迎分享真实使用体验，评论审核通过后会公开展示。'
            : '欢迎分享真实使用体验，发布后会立即公开展示。',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, height: 1.5),
      ),
    ],
  );
}

class _CommentSafetySheet extends StatefulWidget {
  const _CommentSafetySheet({required this.repository});

  final CardCommentRepository repository;

  @override
  State<_CommentSafetySheet> createState() => _CommentSafetySheetState();
}

class _CommentSafetySheetState extends State<_CommentSafetySheet> {
  List<BlockedCommentAuthor>? _blockedAuthors;

  @override
  void initState() {
    super.initState();
    _loadBlockedAuthors();
  }

  Future<void> _loadBlockedAuthors() async {
    final authors = await widget.repository.blockedAuthors();
    if (mounted) setState(() => _blockedAuthors = authors);
  }

  Future<void> _unblock(BlockedCommentAuthor author) async {
    await widget.repository.unblockAuthor(author.key);
    if (!mounted) return;
    setState(
      () => _blockedAuthors = _blockedAuthors
          ?.where((item) => item.key != author.key)
          .toList(growable: false),
    );
  }

  Future<void> _contactSupport() async {
    final uri = LegalConfig.supportEmailUri;
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      AppNotice.error(context, context.tr('暂时无法打开支持邮箱'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedAuthors = _blockedAuthors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .86,
        child: ListView(
          key: const Key('comment-safety-sheet'),
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          children: [
            Text(
              '评论安全与社区规则',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '评论用于分享真实卡片体验。发布内容会经过基础安全检查和人工审核。',
              style: TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            _SafetyRule(
              icon: Icons.privacy_tip_outlined,
              title: '保护隐私',
              body: '不要发布完整卡号、证件、订单号、联系方式、密码、验证码或钱包密钥。',
            ),
            _SafetyRule(
              icon: Icons.link_off_rounded,
              title: '禁止推广和引流',
              body: '不要发布邀请码、返佣、Affiliate、CPA、外链或隐藏跳转。',
            ),
            _SafetyRule(
              icon: Icons.volunteer_activism_outlined,
              title: '友善且真实',
              body: '禁止骚扰、仇恨、威胁、冒充、刷赞和虚假体验。违规内容可能被隐藏，账号可能被限制。',
            ),
            const SizedBox(height: 10),
            if (LegalConfig.supportEmailUri != null)
              OutlinedButton.icon(
                key: const Key('comment-contact-support'),
                onPressed: _contactSupport,
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('联系支持'),
              ),
            const SizedBox(height: 22),
            Text(
              '已屏蔽用户',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '屏蔽信息仅保存在本设备，CardFi 不会为此保存原始账号标识。',
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 10),
            if (blockedAuthors == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (blockedAuthors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '暂未屏蔽任何用户',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final author in blockedAuthors)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.violet.withValues(alpha: .1),
                    foregroundColor: AppColors.violet,
                    child: const Icon(Icons.person_off_outlined, size: 19),
                  ),
                  title: Text(author.displayName),
                  trailing: TextButton(
                    key: Key('unblock-comment-author-${author.key}'),
                    onPressed: () => _unblock(author),
                    child: const Text('取消屏蔽'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SafetyRule extends StatelessWidget {
  const _SafetyRule({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.violet, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    this.liking = false,
    this.onLike,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });
  final CardComment comment;
  final bool liking;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15, 14, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppColors.isDark
          ? null
          : const [
              BoxShadow(
                color: Color(0x0C58659A),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentAvatar(author: comment.author, radius: 18),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTime(comment.createdAt),
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  if (onDelete != null || onReport != null || onBlock != null)
                    SizedBox(
                      width: 34,
                      height: 30,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 19,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.textMuted,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') return onDelete?.call();
                          if (value == 'block') return onBlock?.call();
                          onReport?.call();
                        },
                        itemBuilder: (_) => [
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除评论'),
                            ),
                          if (onReport != null)
                            const PopupMenuItem(
                              value: 'report',
                              child: Text('举报评论'),
                            ),
                          if (onBlock != null)
                            const PopupMenuItem(
                              value: 'block',
                              child: Text('屏蔽该用户'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.body,
                style: TextStyle(
                  color: AppColors.text,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 9),
              _CommentActions(comment: comment, liking: liking, onLike: onLike),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CommentActions extends StatelessWidget {
  const _CommentActions({
    required this.comment,
    required this.liking,
    required this.onLike,
  });

  final CardComment comment;
  final bool liking;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final pending = _CommentPendingBadge(visible: comment.pending);
    final like = _CommentLikeAction(
      comment: comment,
      liking: liking,
      onLike: onLike,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(12) > 15;
        final stacked =
            comment.pending && (constraints.maxWidth < 250 || largeText);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pending),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: like),
            ],
          );
        }
        return Row(
          children: [if (comment.pending) pending, const Spacer(), like],
        );
      },
    );
  }
}

class _CommentPendingBadge extends StatelessWidget {
  const _CommentPendingBadge({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '审核中 · 仅自己可见',
        style: TextStyle(
          color: AppColors.violet,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _CommentLikeAction extends StatelessWidget {
  const _CommentLikeAction({
    required this.comment,
    required this.liking,
    required this.onLike,
  });

  final CardComment comment;
  final bool liking;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    if (onLike == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '有帮助 ${comment.likeCount}',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: liking ? null : onLike,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (liking)
                const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  comment.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 17,
                  color: comment.liked ? AppColors.pink : AppColors.textMuted,
                ),
              const SizedBox(width: 5),
              Text(
                '有帮助 ${comment.likeCount}',
                style: TextStyle(
                  color: comment.liked ? AppColors.pink : AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, this.compact = false});
  final CardComment comment;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _CommentAvatar(author: comment.author, radius: 16),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _relativeTime(comment.createdAt),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              comment.body,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: AppColors.text,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (compact) ...[
              const SizedBox(height: 5),
              Text(
                comment.pending ? '审核中 · 仅自己可见' : '有帮助 ${comment.likeCount}',
                style: TextStyle(
                  color: comment.pending
                      ? AppColors.violet
                      : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.author, required this.radius});

  final CardCommentAuthor author;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = author.avatarUrl?.trim();
    final fallback = Center(
      child: Text(
        author.displayName.characters.firstOrNull ?? '卡',
        style: TextStyle(
          color: AppColors.violet,
          fontSize: radius * .9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: .11),
        shape: BoxShape.circle,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          if (avatarUrl != null && avatarUrl.isNotEmpty)
            ClipOval(
              child: Image.network(
                avatarUrl,
                key: ValueKey('comment-avatar-$avatarUrl'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time.toLocal());
  if (difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  if (difference.inDays < 30) return '${difference.inDays} 天前';
  return '${time.toLocal().month}-${time.toLocal().day}';
}
