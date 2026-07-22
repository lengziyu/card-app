import 'package:card_app/core/motion/app_bottom_sheet.dart';
import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/motion/staggered_reveal.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/interactive_card_artwork.dart';
import 'package:card_app/features/catalog/widgets/global_account_cover.dart';
import 'package:card_app/features/pro/widgets/pro_crown_badge.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CardPreviewPage extends StatefulWidget {
  const CardPreviewPage({
    required this.card,
    required this.detail,
    required this.added,
    required this.favorite,
    required this.onBack,
    required this.onAddedChanged,
    required this.onFavoriteChanged,
    required this.onCorrection,
    required this.onCompare,
    required this.onViewSimilar,
    this.watched = false,
    this.onWatchChanged,
    this.usingOfflineFallback = false,
    this.onRetry,
    this.entranceAnimation,
    super.key,
  });

  final CardSummary card;
  final CardDetail detail;
  final bool added;
  final bool favorite;
  final VoidCallback onBack;
  final ValueChanged<bool> onAddedChanged;
  final ValueChanged<bool> onFavoriteChanged;
  final VoidCallback onCorrection;
  final VoidCallback onCompare;
  final VoidCallback onViewSimilar;
  final bool watched;
  final ValueChanged<bool>? onWatchChanged;
  final bool usingOfflineFallback;
  final VoidCallback? onRetry;
  final Animation<double>? entranceAnimation;

  @override
  State<CardPreviewPage> createState() => _CardPreviewPageState();
}

class CardPreviewSkeleton extends StatelessWidget {
  const CardPreviewSkeleton({
    required this.onBack,
    this.globalAccount = false,
    this.entranceAnimation,
    super.key,
  });

  final VoidCallback onBack;
  final bool globalAccount;
  final Animation<double>? entranceAnimation;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return StaggeredReveal(
      animation: entranceAnimation,
      begin: .48,
      end: .82,
      offset: 8,
      child: Stack(
        key: const Key('card-preview-skeleton'),
        children: [
          AppShimmer(
            child: _TopFadedScroll(
              topInset: topInset,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  24,
                  topInset + 102,
                  24,
                  bottomInset + 40,
                ),
                children: [
                  if (globalAccount)
                    const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _SkeletonBox(height: double.infinity, radius: 14),
                    )
                  else
                    const _SkeletonBox(height: 214, radius: 22),
                  SizedBox(height: globalAccount ? 18 : 25),
                  const _SkeletonBox(height: 28, widthFactor: .58, radius: 10),
                  const SizedBox(height: 12),
                  const _SkeletonBox(height: 15, widthFactor: .34, radius: 8),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      _SkeletonBox(height: 34, width: 68, radius: 14),
                      SizedBox(width: 9),
                      _SkeletonBox(height: 34, width: 76, radius: 14),
                      SizedBox(width: 9),
                      _SkeletonBox(height: 34, width: 84, radius: 14),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SkeletonBox(height: 148, radius: 20),
                  const SizedBox(height: 16),
                  const _SkeletonBox(height: 132, radius: 18),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _StickyDetailNavigation(onBack: onBack, onMore: () {}),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.radius,
    this.width,
    this.widthFactor,
  });

  final double height;
  final double radius;
  final double? width;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? Colors.white.withValues(alpha: .075)
            : Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
    );
    if (widthFactor case final factor?) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: box,
      );
    }
    return box;
  }
}

class _CardPreviewPageState extends State<CardPreviewPage> {
  CardVisualEffect _effect = CardVisualEffect.particle;
  late final ScrollController _scrollController;
  final ValueNotifier<double> _headerProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateHeaderProgress);
  }

  void _updateHeaderProgress() {
    final next = (_scrollController.offset / 190).clamp(0.0, 1.0);
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

  void _showMessage(
    String message, {
    AppNoticeTone tone = AppNoticeTone.warning,
  }) => AppNotice.show(context, message, tone: tone);

  Future<void> _openOfficial() async {
    await _openUrl(widget.card.sourceUrl, unavailableMessage: '暂未提供官网地址');
  }

  Future<void> _openUrl(
    String? source, {
    required String unavailableMessage,
  }) async {
    if (source == null || source.isEmpty) {
      _showMessage(unavailableMessage);
      return;
    }
    final uri = Uri.tryParse(source);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showMessage('暂时无法打开官网');
    }
  }

  Future<void> _showActions() async {
    await showAppDraggableSheet<void>(
      context: context,
      initialSize: .72,
      minSize: .46,
      maxSize: .94,
      barrierAlpha: .42,
      builder: (sheetContext, scrollController) => _DetailActionSheet(
        card: widget.card,
        scrollController: scrollController,
        added: widget.added,
        favorite: widget.favorite,
        effect: _effect,
        onFavorite: () {
          Navigator.pop(sheetContext);
          widget.onFavoriteChanged(!widget.favorite);
        },
        onEffect: (effect) {
          Navigator.pop(sheetContext);
          setState(() => _effect = effect);
          _showMessage(
            '${_effectLabel(effect)}已启用',
            tone: AppNoticeTone.success,
          );
        },
        onViewSimilar: () {
          Navigator.pop(sheetContext);
          widget.onViewSimilar();
        },
        onCompare: () {
          Navigator.pop(sheetContext);
          widget.onCompare();
        },
        watched: widget.watched,
        onWatch: widget.onWatchChanged == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                widget.onWatchChanged!(!widget.watched);
              },
        onOpenOfficial: () {
          Navigator.pop(sheetContext);
          _openOfficial();
        },
        onCorrection: () {
          Navigator.pop(sheetContext);
          widget.onCorrection();
        },
        onRemove: widget.added
            ? () {
                Navigator.pop(sheetContext);
                widget.onAddedChanged(false);
              }
            : null,
      ),
    );
  }

  String _effectLabel(CardVisualEffect effect) => switch (effect) {
    CardVisualEffect.particle => '粒子效果',
    CardVisualEffect.flame => '火焰效果',
    CardVisualEffect.ice => '冰霜效果',
    CardVisualEffect.none => '无效果',
  };

  Widget _reveal(
    Widget child, {
    required double begin,
    required double end,
    double offset = 10,
  }) => StaggeredReveal(
    animation: widget.entranceAnimation,
    begin: begin,
    end: end,
    offset: offset,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final detail = widget.detail;
    final added = widget.added;
    final onBack = widget.onBack;
    final onAddedChanged = widget.onAddedChanged;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: Key('card-preview-page'),
      children: [
        _TopFadedScroll(
          topInset: topInset,
          child: ListView(
            controller: _scrollController,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              102 + topInset,
              24,
              (card.isGlobalAccount ? 40 : 112) + bottomInset,
            ),
            children: [
              _reveal(
                card.isGlobalAccount
                    ? _GlobalAccountStage(card: card)
                    : _DetailCardStage(card: card, effect: _effect),
                begin: .82,
                end: 1,
                offset: 0,
              ),
              SizedBox(height: card.isGlobalAccount ? 18 : 25),
              _reveal(
                Text(
                  card.name,
                  key: Key('detail-title'),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                  ),
                ),
                begin: .48,
                end: .72,
              ),
              SizedBox(height: 8),
              _reveal(
                Text(
                  card.issuer,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                begin: .52,
                end: .76,
                offset: 8,
              ),
              SizedBox(height: 16),
              _reveal(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in detail.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.isDark
                              ? const Color(0x297973FF)
                              : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: AppColors.isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x145B67A0),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: AppColors.isDark
                                ? const Color(0xFFC9C7FF)
                                : const Color(0xFF5E70FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                begin: .56,
                end: .8,
                offset: 8,
              ),
              if (widget.usingOfflineFallback) ...[
                const SizedBox(height: 14),
                _reveal(
                  _OfflineDetailNotice(onRetry: widget.onRetry),
                  begin: .58,
                  end: .82,
                ),
              ],
              SizedBox(height: 18),
              _reveal(_BasicInfo(detail: detail), begin: .6, end: .84),
              SizedBox(height: 16),
              _reveal(
                _KycBlock(card: card, detail: detail),
                begin: .64,
                end: .88,
              ),
              if (card.isGlobalAccount && detail.chinaKyc != null) ...[
                const SizedBox(height: 16),
                _reveal(
                  _ChinaKycBlock(
                    info: detail.chinaKyc!,
                    onOpenSource: () => _openUrl(
                      detail.chinaKyc!.sourceUrl,
                      unavailableMessage: '暂未提供中国大陆资格来源',
                    ),
                  ),
                  begin: .66,
                  end: .9,
                ),
              ],
              SizedBox(height: 22),
              _reveal(
                _FeatureBlock(features: detail.features),
                begin: .68,
                end: .92,
              ),
              SizedBox(height: 28),
              _reveal(_FeeBlock(detail: detail), begin: .7, end: .94),
              if (detail.paymentChannels.isNotEmpty) ...[
                SizedBox(height: 20),
                _reveal(
                  _PaymentBlock(channels: detail.paymentChannels),
                  begin: .72,
                  end: .96,
                ),
              ],
              SizedBox(height: 20),
              _reveal(
                _SourceBlock(detail: detail, onOpenOfficial: _openOfficial),
                begin: .74,
                end: .98,
              ),
              if (detail.inviteCode?.isNotEmpty == true ||
                  detail.inviteUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 20),
                _reveal(
                  _InviteBlock(detail: detail, onMessage: _showMessage),
                  begin: .76,
                  end: 1,
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _reveal(
            _StickyDetailNavigation(
              onBack: onBack,
              onMore: _showActions,
              title: card.name,
              progress: _headerProgress,
            ),
            begin: .44,
            end: .7,
            offset: -8,
          ),
        ),
        if (!card.isGlobalAccount)
          Align(
            alignment: Alignment.bottomCenter,
            child: _reveal(
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + bottomInset),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 342),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: MotionPressEffect(
                      scale: MotionTokens.pressedScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: added
                                ? const [Color(0xFFEF5B66), Color(0xFFDA4351)]
                                : const [Color(0xFF252B38), Color(0xFF0F1421)],
                          ),
                          borderRadius: BorderRadius.circular(29),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (added
                                          ? const Color(0xFFDA4351)
                                          : const Color(0xFF141C30))
                                      .withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          key: Key('detail-toggle-card'),
                          onPressed: added
                              ? _showActions
                              : () {
                                  AppHaptics.selection();
                                  onAddedChanged(true);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(29),
                            ),
                          ),
                          child: MotionStateIcon(
                            stateKey: added,
                            child: Text(added ? '已在本机卡包 · 管理' : '添加到本机卡包'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              begin: .68,
              end: .94,
              offset: 12,
            ),
          ),
      ],
    );
  }
}

class _OfflineDetailNotice extends StatelessWidget {
  const _OfflineDetailNotice({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('detail-offline-fallback'),
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.violet.withValues(alpha: .24)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '网络详情暂不可用，当前显示随包资料。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _DetailCardStage extends StatelessWidget {
  const _DetailCardStage({required this.card, required this.effect});

  final CardSummary card;
  final CardVisualEffect effect;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -74,
            bottom: -112,
            left: -92,
            right: -70,
            child: IgnorePointer(
              child: _HorizontalAmbientFade(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.72, -0.02),
                      radius: 0.86,
                      colors: AppColors.isDark
                          ? const [Color(0x8A9DA4B2), Color(0x00070B19)]
                          : const [Color(0x70C9D6F2), Color(0x00F8FBFF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -78,
            left: 42,
            right: -18,
            height: 164,
            child: IgnorePointer(
              child: _HorizontalAmbientFade(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1,
                      colors: AppColors.isDark
                          ? const [Color(0x294F2548), Color(0x00070B19)]
                          : const [Color(0x24E3C9F3), Color(0x00F8FBFF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: InteractiveCardArtwork(card: card, effect: effect),
          ),
        ],
      ),
    );
  }
}

class _GlobalAccountStage extends StatelessWidget {
  const _GlobalAccountStage({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: const Key('global-account-stage'),
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF56628C,
              ).withValues(alpha: AppColors.isDark ? .22 : .16),
              blurRadius: 28,
              spreadRadius: -5,
              offset: const Offset(0, 13),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GlobalAccountCover(card: card),
        ),
      ),
    );
  }
}

class _HorizontalAmbientFade extends StatelessWidget {
  const _HorizontalAmbientFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
          Colors.transparent,
        ],
        stops: [0, .16, .28, .72, .84, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

class _StickyDetailNavigation extends StatelessWidget {
  const _StickyDetailNavigation({
    required this.onBack,
    required this.onMore,
    this.title,
    this.progress,
  });

  final VoidCallback onBack;
  final VoidCallback onMore;
  final String? title;
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return FrostedHeaderFade(
      height: 92 + topInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8 + topInset, 24, 28),
        child: _DetailNavigation(
          onBack: onBack,
          onMore: onMore,
          title: title,
          progress: progress,
        ),
      ),
    );
  }
}

class _TopFadedScroll extends StatelessWidget {
  const _TopFadedScroll({required this.topInset, required this.child});

  final double topInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final hold = (topInset * .55 / bounds.height).clamp(0.0, .18);
        final fadeEnd = ((topInset + 82) / bounds.height).clamp(.05, .28);
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

class _DetailNavigation extends StatelessWidget {
  const _DetailNavigation({
    required this.onBack,
    required this.onMore,
    this.title,
    this.progress,
  });

  final VoidCallback onBack;
  final VoidCallback onMore;
  final String? title;
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MotionPressEffect(
          child: IconButton.filledTonal(
            key: Key('preview-back'),
            onPressed: onBack,
            tooltip: '返回',
            icon: Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size(48, 48),
              foregroundColor: AppColors.text,
              backgroundColor: AppColors.glassStrong,
              side: BorderSide(color: AppColors.line),
            ),
          ),
        ),
        Expanded(
          child: progress == null || title == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<double>(
                  valueListenable: progress!,
                  builder: (context, value, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: CollapsingHeaderTitle(
                      title: title!,
                      progress: value,
                    ),
                  ),
                ),
        ),
        MotionPressEffect(
          child: IconButton.filledTonal(
            key: const Key('detail-more'),
            onPressed: onMore,
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz_rounded),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.text,
              backgroundColor: AppColors.glassStrong,
              side: BorderSide(color: AppColors.line),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailActionSheet extends StatelessWidget {
  const _DetailActionSheet({
    required this.card,
    required this.scrollController,
    required this.added,
    required this.favorite,
    required this.effect,
    required this.onFavorite,
    required this.onEffect,
    required this.onViewSimilar,
    required this.onCompare,
    required this.watched,
    required this.onWatch,
    required this.onOpenOfficial,
    required this.onCorrection,
    required this.onRemove,
  });

  final CardSummary card;
  final ScrollController scrollController;
  final bool added;
  final bool favorite;
  final CardVisualEffect effect;
  final VoidCallback onFavorite;
  final ValueChanged<CardVisualEffect> onEffect;
  final VoidCallback onViewSimilar;
  final VoidCallback onCompare;
  final bool watched;
  final VoidCallback? onWatch;
  final VoidCallback onOpenOfficial;
  final VoidCallback onCorrection;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xF21C2030)
            : const Color(0xF5F8FAFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.glassStrong,
                    foregroundColor: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-favorite'),
              icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
              label: favorite ? '取消收藏' : '收藏卡片',
              onTap: onFavorite,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glassStrong,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '卡面效果',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final item in const [
                        (
                          CardVisualEffect.particle,
                          Icons.auto_awesome_rounded,
                          '粒子',
                        ),
                        (
                          CardVisualEffect.flame,
                          Icons.local_fire_department_rounded,
                          '火焰',
                        ),
                        (CardVisualEffect.ice, Icons.ac_unit_rounded, '冰霜'),
                        (
                          CardVisualEffect.none,
                          Icons.visibility_off_outlined,
                          '关闭',
                        ),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: MotionPressEffect(
                              child: InkWell(
                                key: Key('detail-effect-${item.$1.name}'),
                                onTap: () => onEffect(item.$1),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : MotionTokens.stateChange,
                                  curve: MotionTokens.standardEnter,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: effect == item.$1
                                        ? AppColors.violet.withValues(
                                            alpha: 0.24,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: effect == item.$1
                                          ? AppColors.violet.withValues(
                                              alpha: 0.5,
                                            )
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        item.$2,
                                        color: effect == item.$1
                                            ? AppColors.cyan
                                            : AppColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.$3,
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-similar'),
              icon: Icons.storefront_outlined,
              label: '查看同类卡片',
              onTap: onViewSimilar,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-correction'),
              icon: Icons.edit_note_rounded,
              label: '提交信息纠正',
              onTap: onCorrection,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-compare'),
              icon: Icons.compare_arrows_rounded,
              label: '加入卡片对比',
              onTap: onCompare,
              pro: true,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-watch'),
              icon: watched
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              label: watched ? '取消规则变更关注' : '关注规则变更',
              onTap: onWatch,
              pro: true,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-official'),
              icon: Icons.open_in_new_rounded,
              label: '打开官网',
              onTap: onOpenOfficial,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-remove'),
              icon: Icons.remove_circle_outline_rounded,
              label: added ? '从我的卡片移除' : '尚未添加到我的卡片',
              onTap: onRemove,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.pro = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF8496) : AppColors.text;
    return MotionPressEffect(
      enabled: onTap != null,
      scale: MotionTokens.pressedScale,
      child: Material(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                MotionStateIcon(
                  stateKey: icon,
                  child: Icon(
                    icon,
                    color: onTap == null ? AppColors.textMuted : color,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: onTap == null ? AppColors.textMuted : color,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (pro) ...[const ProCrownBadge(), const SizedBox(width: 7)],
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteBlock extends StatelessWidget {
  const _InviteBlock({required this.detail, required this.onMessage});

  final CardDetail detail;
  final ValueChanged<String> onMessage;

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) onMessage('$label已复制');
  }

  Future<void> _openLink(BuildContext context, String value) async {
    final url = Uri.tryParse(value);
    if (url == null ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) onMessage('暂时无法打开邀请链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: const Key('detail-invite'),
      title: '开卡信息',
      subtitle: '由运营后台人工审核后展示，请以官方规则为准',
      child: Column(
        children: [
          if (detail.inviteCode?.isNotEmpty == true)
            _InviteLine(
              label: '邀请码',
              value: detail.inviteCode!,
              icon: Icons.copy_rounded,
              actionLabel: '复制',
              onTap: () => _copy(context, detail.inviteCode!, '邀请码'),
            ),
          if (detail.inviteCode?.isNotEmpty == true &&
              detail.inviteUrl?.isNotEmpty == true)
            const SizedBox(height: 10),
          if (detail.inviteUrl?.isNotEmpty == true)
            _InviteLine(
              label: '邀请链接',
              value: detail.inviteUrl!,
              icon: Icons.open_in_new_rounded,
              actionLabel: '打开',
              onTap: () => _openLink(context, detail.inviteUrl!),
            ),
        ],
      ),
    );
  }
}

class _InviteLine extends StatelessWidget {
  const _InviteLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: AppColors.isDark ? .06 : .56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _BasicInfo extends StatelessWidget {
  const _BasicInfo({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-basic-info'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetaCell(label: '适用地区', value: detail.region),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: _MetaCell(
                  label: '入金方式',
                  value: detail.funding,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaCell(
                  label: '开放状态',
                  value: detail.availability,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBlock extends StatelessWidget {
  const _KycBlock({required this.card, required this.detail});

  final CardSummary card;
  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-kyc'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '身份验证（KYC）',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final document in KycDocument.values)
                _StatusPill(
                  label: document.label,
                  supported: card.kycDocuments.contains(document),
                ),
            ],
          ),
          if (_showKycNote(detail.kycNote)) ...[
            const SizedBox(height: 10),
            Text(
              detail.kycNote,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _showKycNote(String note) {
    final normalized = note.trim();
    return normalized.isNotEmpty &&
        !normalized.startsWith('待补充') &&
        !normalized.startsWith('暂无');
  }
}

class _ChinaKycBlock extends StatelessWidget {
  const _ChinaKycBlock({required this.info, required this.onOpenSource});

  final ChinaKycInfo info;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final color = switch (info.status) {
      ChinaKycStatus.available => AppColors.mint,
      ChinaKycStatus.restricted => const Color(0xFFFFB957),
      ChinaKycStatus.unavailable => const Color(0xFFFF8496),
      ChinaKycStatus.unknown => AppColors.textMuted,
    };
    return Container(
      key: const Key('detail-china-kyc'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city_rounded, color: color, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '中国大陆申请与 KYC',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChinaKycLine(
            label: '大陆居民账户',
            value: info.status.label,
            color: color,
          ),
          const SizedBox(height: 10),
          _ChinaKycLine(label: '可用证件', value: info.documentSummary),
          const SizedBox(height: 12),
          Text(
            info.note,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  info.checkedAt == null
                      ? '来源尚未标注核验日期'
                      : '官方来源 · 核验于 ${_dateLabel(info.checkedAt!)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: info.sourceUrl.isEmpty ? null : onOpenSource,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('查看来源'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _ChinaKycLine extends StatelessWidget {
  const _ChinaKycLine({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: AppColors.isDark ? .06 : .56),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.supported});

  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final color = supported ? AppColors.mint : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            supported ? Icons.check_circle_outline : Icons.help_outline,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '$label · ${supported ? '支持' : '待确认'}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.channels});

  final Set<PaymentChannel> channels;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: Key('detail-payments'),
      title: '支付渠道',
      subtitle: '支持状态仍需以官方最新说明为准',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final channel in channels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                channel.label,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({required this.features});

  final List<DetailFeature> features;

  IconData _icon(DetailFeatureIcon icon) => switch (icon) {
    DetailFeatureIcon.wallet => Icons.account_balance_wallet_outlined,
    DetailFeatureIcon.shield => Icons.shield_outlined,
    DetailFeatureIcon.payments => Icons.contactless_outlined,
    DetailFeatureIcon.globe => Icons.public_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('detail-features'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '核心权益',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final feature in features)
                  Container(
                    width: width,
                    constraints: const BoxConstraints(minHeight: 82),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.isDark
                            ? const [Color(0xD0303448), Color(0xB81C2030)]
                            : [
                                Colors.white.withValues(alpha: 0.72),
                                Colors.white.withValues(alpha: 0.48),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _icon(feature.icon),
                          color: _color(feature.icon),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature.text,
                            style: TextStyle(
                              color: AppColors.isDark
                                  ? const Color(0xFFB8BED0)
                                  : const Color(0xFF626B7E),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Color _color(DetailFeatureIcon icon) => switch (icon) {
    DetailFeatureIcon.wallet =>
      AppColors.isDark ? const Color(0xFF8F96FF) : const Color(0xFF5F6DFF),
    DetailFeatureIcon.payments =>
      AppColors.isDark ? const Color(0xFFA98AFF) : const Color(0xFF8668FF),
    DetailFeatureIcon.globe =>
      AppColors.isDark ? const Color(0xFF67D4FF) : const Color(0xFF2DA9C7),
    DetailFeatureIcon.shield =>
      AppColors.isDark ? const Color(0xFFA28CFF) : const Color(0xFF7767FF),
  };
}

class _FeeBlock extends StatelessWidget {
  const _FeeBlock({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('detail-fees'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '费用',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final fee in detail.fees)
          _FeeRow(label: fee.label, value: fee.value),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 132,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBlock extends StatelessWidget {
  const _SourceBlock({required this.detail, required this.onOpenOfficial});

  final CardDetail detail;
  final VoidCallback onOpenOfficial;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('detail-source'),
      color: AppColors.glass.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('detail-open-official'),
        onTap: onOpenOfficial,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '资料来源 · ${detail.sourceLabel}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '公开资料整理，具体信息以发卡方为准。',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '官网',
                    style: TextStyle(
                      color: AppColors.isDark
                          ? const Color(0xFFC9C7FF)
                          : AppColors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.isDark
                        ? const Color(0xFFC9C7FF)
                        : AppColors.cyan,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            SizedBox(height: 5),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
