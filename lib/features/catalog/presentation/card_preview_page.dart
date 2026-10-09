import 'dart:async';
import 'dart:ui';

import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/motion/staggered_reveal.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/data/card_comment_repository.dart';
import 'package:cardfi/features/catalog/presentation/card_comments_page.dart';
import 'package:cardfi/features/catalog/widgets/interactive_card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/global_account_cover.dart';
import 'package:cardfi/features/pro/widgets/pro_crown_badge.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    this.onOpenApplicationAssistant,
    this.onManagePersonalCard,
    this.watched = false,
    this.onWatchChanged,
    this.usingOfflineFallback = false,
    this.onRetry,
    this.entranceAnimation,
    this.reconstructOnEntrance = false,
    this.fadeOnExit = false,
    this.onScrollOffsetChanged,
    this.sourceImageCacheWidth,
    this.isPro = false,
    this.commentRepository,
    this.signedIn = false,
    this.onCommentLoginRequired,
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
  final VoidCallback? onOpenApplicationAssistant;
  final VoidCallback? onManagePersonalCard;
  final bool watched;
  final ValueChanged<bool>? onWatchChanged;
  final bool usingOfflineFallback;
  final VoidCallback? onRetry;
  final Animation<double>? entranceAnimation;
  final bool reconstructOnEntrance;
  final bool fadeOnExit;
  final ValueChanged<double>? onScrollOffsetChanged;
  final int? sourceImageCacheWidth;
  final bool isPro;
  final CardCommentRepository? commentRepository;
  final bool signedIn;
  final VoidCallback? onCommentLoginRequired;

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
            child: _StickyDetailNavigation(
              onBack: onBack,
              onMore: () {},
              onEffects: null,
              isPro: false,
            ),
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
  static const _effectPreferenceKey = 'card-app-card-visual-effect-v1';
  CardVisualEffect _effect = CardVisualEffect.particle;
  bool _effectChangedLocally = false;
  bool _effectMenuOpen = false;
  bool _suppressEffectAnimation = false;
  late final ScrollController _scrollController;
  final ValueNotifier<double> _headerProgress = ValueNotifier(0);
  final ValueNotifier<bool> _cardStageTickerEnabled = ValueNotifier(true);
  // A shared card arrives fully rendered. Replaying a reconstruction after
  // the flight would dissolve it a second time; explicit effects still work.
  bool get _animateInitialEffect =>
      widget.reconstructOnEntrance || widget.entranceAnimation == null;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateHeaderProgress);
    unawaited(_restoreEffect());
  }

  Future<void> _restoreEffect() async {
    final preferences = await SharedPreferences.getInstance();
    final savedName = preferences.getString(_effectPreferenceKey);
    final savedEffect = CardVisualEffect.values
        .where((effect) => effect.name == savedName)
        .firstOrNull;
    if (!mounted ||
        _effectChangedLocally ||
        savedEffect == null ||
        (_isProEffect(savedEffect) && !widget.isPro)) {
      return;
    }
    final rebuildingOnEntrance =
        widget.reconstructOnEntrance &&
        (widget.entranceAnimation?.value ?? 1) < 1;
    setState(() {
      // If the saved effect arrives while reconstruction is still active,
      // replay that saved effect from zero as well. Settling it immediately
      // would reintroduce the complete-card flash this entrance avoids.
      _suppressEffectAnimation = !rebuildingOnEntrance;
      _effect = savedEffect;
    });
    // The preference restore is state hydration, not a user-selected replay.
    // Keep this one update settled, then allow later menu changes to animate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressEffectAnimation = false;
    });
  }

  void _selectEffect(CardVisualEffect effect) {
    setState(() {
      _effect = effect;
      _effectChangedLocally = true;
      _effectMenuOpen = false;
      _suppressEffectAnimation = false;
    });
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) =>
            preferences.setString(_effectPreferenceKey, effect.name),
      ),
    );
  }

  bool _isProEffect(CardVisualEffect effect) => switch (effect) {
    CardVisualEffect.magnetic ||
    CardVisualEffect.liquidMetal ||
    CardVisualEffect.spaceFold ||
    CardVisualEffect.shards ||
    CardVisualEffect.scanReveal ||
    CardVisualEffect.foldReveal ||
    CardVisualEffect.photoEtch ||
    CardVisualEffect.liquidCast ||
    CardVisualEffect.bandAlign => true,
    _ => false,
  };

  void _updateHeaderProgress() {
    widget.onScrollOffsetChanged?.call(_scrollController.offset);
    final next = (_scrollController.offset / 190).clamp(0.0, 1.0);
    if ((next - _headerProgress.value).abs() > .002) {
      _headerProgress.value = next;
    }
    final stageVisible = _scrollController.offset < 420;
    if (_cardStageTickerEnabled.value != stageVisible) {
      _cardStageTickerEnabled.value = stageVisible;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateHeaderProgress)
      ..dispose();
    _headerProgress.dispose();
    _cardStageTickerEnabled.dispose();
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
    await showAppBottomSheet<void>(
      context: context,
      barrierAlpha: .42,
      builder: (sheetContext) => _DetailActionSheet(
        card: widget.card,
        added: widget.added,
        favorite: widget.favorite,
        onFavorite: () {
          Navigator.pop(sheetContext);
          widget.onFavoriteChanged(!widget.favorite);
        },
        onViewSimilar: () {
          Navigator.pop(sheetContext);
          widget.onViewSimilar();
        },
        onCompare: () {
          Navigator.pop(sheetContext);
          widget.onCompare();
        },
        onManagePersonalCard: widget.onManagePersonalCard == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                widget.onManagePersonalCard!();
              },
        onOpenApplicationAssistant: widget.onOpenApplicationAssistant == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                widget.onOpenApplicationAssistant!();
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

  Widget _reveal(
    Widget child, {
    required double begin,
    required double end,
    double offset = 10,
  }) => StaggeredReveal(
    animation: widget.fadeOnExit ? null : widget.entranceAnimation,
    begin: begin,
    end: end,
    offset: offset,
    child: child,
  );

  Widget _sharedCardHandoff(Widget child) {
    final animation = widget.entranceAnimation;
    if (animation == null ||
        widget.fadeOnExit ||
        MediaQuery.disableAnimationsOf(context)) {
      return Opacity(
        key: const Key('detail-card-handoff-opacity'),
        opacity: 1,
        child: child,
      );
    }
    if (widget.reconstructOnEntrance &&
        animation.status != AnimationStatus.reverse) {
      return Opacity(
        key: const Key('detail-card-handoff-opacity'),
        opacity: 1,
        child: child,
      );
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        key: const Key('detail-card-handoff-opacity'),
        // This is the exact complement of MarketCardTransition's flight
        // opacity. Their sum therefore stays at one throughout the handoff.
        opacity: const Interval(
          .86,
          1,
          curve: Curves.easeOut,
        ).transform(animation.value),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final detail = widget.detail;
    final added = widget.added;
    final onBack = widget.onBack;
    final onAddedChanged = widget.onAddedChanged;
    final paymentChannels = paymentChannelsForPlatform(
      detail.paymentChannels,
      defaultTargetPlatform,
    );
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
              ValueListenableBuilder<bool>(
                valueListenable: _cardStageTickerEnabled,
                builder: (context, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!),
                child: _sharedCardHandoff(
                  card.isGlobalAccount
                      ? _GlobalAccountStage(
                          card: card,
                          effect: _effect,
                          animateInitialEffect: _animateInitialEffect,
                          animateEffectChanges: !_suppressEffectAnimation,
                        )
                      : _DetailCardStage(
                          card: card,
                          effect: _effect,
                          sourceImageCacheWidth: widget.sourceImageCacheWidth,
                          animateInitialEffect: _animateInitialEffect,
                          animateEffectChanges: !_suppressEffectAnimation,
                        ),
                ),
              ),
              SizedBox(height: card.isGlobalAccount ? 18 : 25),
              _reveal(
                Text(
                  card.name,
                  key: Key('detail-title'),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.65,
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                begin: .52,
                end: .76,
                offset: 8,
              ),
              if (detail.rating != null) ...[
                const SizedBox(height: 14),
                _reveal(
                  _CardRating(
                    rating: detail.rating!,
                    reviewCount: detail.reviewCount,
                  ),
                  begin: .54,
                  end: .78,
                  offset: 8,
                ),
              ],
              SizedBox(height: 16),
              _reveal(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // KYC is presented in its dedicated detail block below;
                    // keeping it out of the title tags avoids repeating a
                    // broad verification label such as “KYC：完整验证”.
                    for (final tag in detail.tags.where(
                      (tag) => !tag.startsWith('KYC：'),
                    ))
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
                    if (card.isGlobalAccount && card.isCryptoRelated)
                      const _CryptoRelatedBadge(),
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
              _reveal(
                _BasicInfo(card: card, detail: detail),
                begin: .6,
                end: .84,
              ),
              // 全球账户的中国大陆资格包含地区、主体与材料条件，不能和
              // 通用证件标签并列成两张 KYC 卡。若接口还没有该专门资料，
              // 才回退到通用 KYC 展示。
              if (!card.isGlobalAccount || detail.chinaKyc == null) ...[
                SizedBox(height: 16),
                _reveal(
                  _KycBlock(card: card, detail: detail),
                  begin: .64,
                  end: .88,
                ),
              ],
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
              if (card.isGlobalAccount &&
                  detail.supportedCurrencies.isNotEmpty) ...[
                const SizedBox(height: 18),
                _reveal(
                  _SupportedCurrenciesBlock(
                    currencies: detail.supportedCurrencies,
                  ),
                  begin: .67,
                  end: .91,
                ),
              ],
              if (detail.features.isNotEmpty) ...[
                SizedBox(height: 22),
                _reveal(
                  _FeatureBlock(features: detail.features),
                  begin: .68,
                  end: .92,
                ),
              ],
              if (detail.rules.isNotEmpty) ...[
                SizedBox(height: 22),
                _reveal(
                  _RuleBlock(
                    key: const Key('detail-usage-rules'),
                    title: '使用与返现规则',
                    rules: detail.rules,
                  ),
                  begin: .69,
                  end: .93,
                ),
              ],
              if (detail.fees.isNotEmpty) ...[
                SizedBox(height: 28),
                _reveal(_FeeBlock(detail: detail), begin: .7, end: .94),
              ],
              if (paymentChannels.isNotEmpty) ...[
                SizedBox(height: 20),
                _reveal(
                  _PaymentBlock(channels: paymentChannels),
                  begin: .72,
                  end: .96,
                ),
              ],
              if (!card.isGlobalAccount &&
                  widget.commentRepository != null) ...[
                const SizedBox(height: 20),
                CardCommentPreview(
                  card: card,
                  repository: widget.commentRepository!,
                  signedIn: widget.signedIn,
                  onLoginRequired: widget.onCommentLoginRequired ?? () {},
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
              onEffects: () =>
                  setState(() => _effectMenuOpen = !_effectMenuOpen),
              isPro: widget.isPro,
              title: card.name,
              progress: _headerProgress,
            ),
            begin: .44,
            end: .7,
            offset: -8,
          ),
        ),
        if (_effectMenuOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              key: const Key('detail-effects-menu-barrier'),
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _effectMenuOpen = false),
            ),
          ),
          Positioned(
            top: topInset + 66,
            right: 80,
            child: _CardEffectMenu(
              selected: _effect,
              isPro: widget.isPro,
              onSelected: _selectEffect,
              onProLocked: (label) => AppNotice.info(
                context,
                '开通 Pro 后即可使用$label效果。',
                title: 'Pro 专属效果',
              ),
            ),
          ),
        ],
        if (!card.isGlobalAccount)
          Align(
            alignment: Alignment.bottomCenter,
            child: _reveal(
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.canvas.withValues(alpha: 0),
                      AppColors.canvas.withValues(alpha: .92),
                      AppColors.canvas,
                    ],
                    stops: const [0, .35, 1],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12 + bottomInset),
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
                                  : const [
                                      Color(0xFF252B38),
                                      Color(0xFF0F1421),
                                    ],
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
                              child: Text(added ? '已加入我的卡片 · 管理' : '加入我的卡片'),
                            ),
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
  const _DetailCardStage({
    required this.card,
    required this.effect,
    required this.animateInitialEffect,
    required this.animateEffectChanges,
    this.sourceImageCacheWidth,
  });

  final CardSummary card;
  final CardVisualEffect effect;
  final bool animateInitialEffect;
  final bool animateEffectChanges;
  final int? sourceImageCacheWidth;

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
            child: InteractiveCardArtwork(
              card: card,
              effect: effect,
              artwork: sourceImageCacheWidth == null
                  ? null
                  : CardArtwork(
                      card: card,
                      showGeneratedLabels: false,
                      fallbackMemCacheWidth: sourceImageCacheWidth,
                    ),
              animateInitialEffect: animateInitialEffect,
              animateEffectChanges: animateEffectChanges,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalAccountStage extends StatelessWidget {
  const _GlobalAccountStage({
    required this.card,
    required this.effect,
    required this.animateInitialEffect,
    required this.animateEffectChanges,
  });

  final CardSummary card;
  final CardVisualEffect effect;
  final bool animateInitialEffect;
  final bool animateEffectChanges;

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
        child: InteractiveCardArtwork(
          card: card,
          effect: effect,
          animateInitialEffect: animateInitialEffect,
          animateEffectChanges: animateEffectChanges,
          borderRadius: BorderRadius.circular(14),
          artwork: GlobalAccountCover(card: card),
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
    required this.onEffects,
    required this.isPro,
    this.title,
    this.progress,
  });

  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback? onEffects;
  final bool isPro;
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
          onEffects: onEffects,
          isPro: isPro,
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
        // Keep scrolling text clear of the fixed title and its 48px controls.
        // Start the fade below them, so two titles never overlap on scroll.
        final hold = ((topInset + 56) / bounds.height).clamp(0.0, .22);
        final fadeEnd = ((topInset + 96) / bounds.height).clamp(.05, .32);
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
    required this.onEffects,
    required this.isPro,
    this.title,
    this.progress,
  });

  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback? onEffects;
  final bool isPro;
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
        if (onEffects != null) ...[
          const SizedBox(width: 8),
          MotionPressEffect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  key: const Key('detail-effects'),
                  onPressed: onEffects,
                  tooltip: '卡面效果',
                  icon: const Icon(Icons.auto_awesome_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.text,
                    backgroundColor: AppColors.glassStrong,
                    side: BorderSide(color: AppColors.line),
                  ),
                ),
                // The effect library is a Pro surface. Keep its crown visible
                // after unlocking too, rather than making the entry disappear.
                const Positioned(right: -3, top: -4, child: ProCrownBadge()),
              ],
            ),
          ),
        ],
        const SizedBox(width: 8),
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

class _CardEffectMenu extends StatelessWidget {
  const _CardEffectMenu({
    required this.selected,
    required this.isPro,
    required this.onSelected,
    required this.onProLocked,
  });

  static const _items = <(CardVisualEffect, IconData, String, bool)>[
    (CardVisualEffect.particle, Icons.auto_awesome_rounded, '粒子', false),
    (CardVisualEffect.flame, Icons.local_fire_department_rounded, '火焰', false),
    (CardVisualEffect.none, Icons.visibility_off_outlined, '关闭', false),
    (CardVisualEffect.fireworks, Icons.celebration_rounded, '烟花', false),
    (CardVisualEffect.prism, Icons.diamond_outlined, '棱镜', false),
    (
      CardVisualEffect.supernova,
      Icons.auto_awesome_motion_rounded,
      '超新星',
      false,
    ),
    (CardVisualEffect.magnetic, Icons.blur_circular_rounded, '磁场', true),
    (CardVisualEffect.liquidMetal, Icons.water_drop_outlined, '液态金属', true),
    (CardVisualEffect.spaceFold, Icons.all_inclusive_rounded, '空间折叠', true),
    (CardVisualEffect.shards, Icons.grid_view_rounded, '碎片归位', true),
    (CardVisualEffect.scanReveal, Icons.document_scanner_rounded, '扫描显影', true),
    (CardVisualEffect.foldReveal, Icons.view_carousel_rounded, '折页展开', true),
    (CardVisualEffect.photoEtch, Icons.gesture_rounded, '光刻成型', true),
    (CardVisualEffect.liquidCast, Icons.water_rounded, '液态凝固', true),
    (
      CardVisualEffect.bandAlign,
      Icons.align_horizontal_center_rounded,
      '条带校准',
      true,
    ),
  ];

  final CardVisualEffect selected;
  final bool isPro;
  final ValueChanged<CardVisualEffect> onSelected;
  final ValueChanged<String> onProLocked;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : MotionTokens.contentSwitch,
      curve: MotionTokens.standardEnter,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(
          alignment: Alignment.topRight,
          scale:
              MotionTokens.incomingScale +
              (1 - MotionTokens.incomingScale) * value,
          child: child,
        ),
      ),
      child: DecoratedBox(
        key: const Key('detail-effects-menu'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDark
                  ? const Color(0x55000000)
                  : const Color(0x2256678D),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 232,
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.isDark
                    ? const Color(0xEA272C3D)
                    : const Color(0xF2F9FBFF),
                border: Border.all(
                  color: AppColors.isDark
                      ? Colors.white.withValues(alpha: .18)
                      : const Color(0x305C73FF),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      '卡面效果',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var row = 0; row < _items.length; row += 3) ...[
                    Row(
                      children: [
                        for (final item in _items.skip(row).take(3))
                          Expanded(
                            child: _CardEffectMenuItem(
                              effect: item.$1,
                              icon: item.$2,
                              label: item.$3,
                              pro: item.$4,
                              selected: selected == item.$1,
                              locked: item.$4 && !isPro,
                              onTap: () {
                                if (item.$4 && !isPro) {
                                  onProLocked(item.$3);
                                  return;
                                }
                                onSelected(item.$1);
                              },
                            ),
                          ),
                      ],
                    ),
                    if (row + 3 < _items.length) const SizedBox(height: 3),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardEffectMenuItem extends StatelessWidget {
  const _CardEffectMenuItem({
    required this.effect,
    required this.icon,
    required this.label,
    required this.pro,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final CardVisualEffect effect;
  final IconData icon;
  final String label;
  final bool pro;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MotionPressEffect(
    child: InkWell(
      key: Key('detail-effect-${effect.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MotionTokens.stateChange,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.violet.withValues(alpha: .18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? AppColors.violet.withValues(alpha: .38)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.cyan : AppColors.textMuted,
                  size: 19,
                ),
                if (pro)
                  const Positioned(right: -10, top: -7, child: ProCrownBadge()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailActionSheet extends StatelessWidget {
  const _DetailActionSheet({
    required this.card,
    required this.added,
    required this.favorite,
    required this.onFavorite,
    required this.onViewSimilar,
    required this.onCompare,
    this.onManagePersonalCard,
    required this.onOpenApplicationAssistant,
    required this.watched,
    required this.onWatch,
    required this.onOpenOfficial,
    required this.onCorrection,
    required this.onRemove,
  });

  final CardSummary card;
  final bool added;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onViewSimilar;
  final VoidCallback onCompare;
  final VoidCallback? onManagePersonalCard;
  final VoidCallback? onOpenApplicationAssistant;
  final bool watched;
  final VoidCallback? onWatch;
  final VoidCallback onOpenOfficial;
  final VoidCallback onCorrection;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
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
            if (card.isGlobalAccount)
              _GlobalAccountActionList(
                watched: watched,
                onWatch: onWatch,
                onOpenOfficial: onOpenOfficial,
                onCorrection: onCorrection,
              )
            else
              _CardActionLayout(
                added: added,
                favorite: favorite,
                onFavorite: onFavorite,
                onViewSimilar: onViewSimilar,
                onCompare: onCompare,
                onManagePersonalCard: onManagePersonalCard,
                onOpenApplicationAssistant: onOpenApplicationAssistant,
                watched: watched,
                onWatch: onWatch,
                onOpenOfficial: onOpenOfficial,
                onCorrection: onCorrection,
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _CardRating extends StatelessWidget {
  const _CardRating({required this.rating, this.reviewCount});

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final ratingLabel = rating == rating.roundToDouble()
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);
    final reviews = reviewCount == null
        ? ''
        : ' (${_formatNumber(reviewCount!)})';
    return Semantics(
      label: reviewCount == null
          ? '评分 $ratingLabel'
          : '评分 $ratingLabel，共 $reviewCount 条评价',
      child: Row(
        key: const Key('detail-rating'),
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB11A), size: 25),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$ratingLabel$reviews',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

class _GlobalAccountActionList extends StatelessWidget {
  const _GlobalAccountActionList({
    required this.watched,
    required this.onWatch,
    required this.onOpenOfficial,
    required this.onCorrection,
  });

  final bool watched;
  final VoidCallback? onWatch;
  final VoidCallback onOpenOfficial;
  final VoidCallback onCorrection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionRow(
          key: const Key('detail-action-correction'),
          icon: Icons.edit_note_rounded,
          label: '提交信息纠正',
          onTap: onCorrection,
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
      ],
    );
  }
}

class _CardActionLayout extends StatelessWidget {
  const _CardActionLayout({
    required this.added,
    required this.favorite,
    required this.onFavorite,
    required this.onViewSimilar,
    required this.onCompare,
    this.onManagePersonalCard,
    required this.onOpenApplicationAssistant,
    required this.watched,
    required this.onWatch,
    required this.onOpenOfficial,
    required this.onCorrection,
    required this.onRemove,
  });

  final bool added;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onViewSimilar;
  final VoidCallback onCompare;
  final VoidCallback? onManagePersonalCard;
  final VoidCallback? onOpenApplicationAssistant;
  final bool watched;
  final VoidCallback? onWatch;
  final VoidCallback onOpenOfficial;
  final VoidCallback onCorrection;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final proActions = <Widget>[
      if (onOpenApplicationAssistant != null)
        _ActionTile(
          key: const Key('detail-action-application-assistant'),
          icon: Icons.auto_awesome_rounded,
          label: 'AI 协助开卡',
          onTap: onOpenApplicationAssistant,
        ),
      _ActionTile(
        key: const Key('detail-action-compare'),
        icon: Icons.compare_arrows_rounded,
        label: '加入卡片对比',
        onTap: onCompare,
      ),
      _ActionTile(
        key: const Key('detail-action-watch'),
        icon: watched
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
        label: watched ? '取消规则关注' : '关注规则变更',
        onTap: onWatch,
        showProBadge: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionTileGrid(
          children: [
            if (added && onManagePersonalCard != null)
              _ActionTile(
                key: const Key('detail-action-personal-card'),
                icon: Icons.account_balance_wallet_outlined,
                label: '管理这张卡',
                onTap: onManagePersonalCard,
              ),
            _ActionTile(
              key: const Key('detail-action-favorite'),
              icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
              label: favorite ? '取消收藏' : '收藏卡片',
              onTap: onFavorite,
            ),
            _ActionTile(
              key: const Key('detail-action-similar'),
              icon: Icons.storefront_outlined,
              label: '查看同类',
              onTap: onViewSimilar,
            ),
            _ActionTile(
              key: const Key('detail-action-official'),
              icon: Icons.open_in_new_rounded,
              label: '打开官网',
              onTap: onOpenOfficial,
            ),
            _ActionTile(
              key: const Key('detail-action-correction'),
              icon: Icons.edit_note_rounded,
              label: '信息纠正',
              onTap: onCorrection,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProActionGroup(children: proActions),
        if (added && onRemove != null) ...[
          const SizedBox(height: 14),
          _ActionRow(
            key: const Key('detail-action-remove'),
            icon: Icons.remove_circle_outline_rounded,
            label: '从我的卡片移除',
            onTap: onRemove,
            danger: true,
          ),
        ],
      ],
    );
  }
}

class _ProActionGroup extends StatelessWidget {
  const _ProActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detail-action-pro-group'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF4A51C,
        ).withValues(alpha: AppColors.isDark ? .10 : .075),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(
            0xFFF4A51C,
          ).withValues(alpha: AppColors.isDark ? .26 : .20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: AppColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '卡片工具',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  '对比、AI 与规则管理',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActionTileGrid(gap: 8, children: children),
        ],
      ),
    );
  }
}

class _ActionTileGrid extends StatelessWidget {
  const _ActionTileGrid({required this.children, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index += 2) ...[
          Row(
            children: [
              Expanded(child: children[index]),
              if (index + 1 < children.length) ...[
                SizedBox(width: gap),
                Expanded(child: children[index + 1]),
              ],
            ],
          ),
          if (index + 2 < children.length) SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showProBadge = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showProBadge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MotionPressEffect(
      enabled: enabled,
      scale: MotionTokens.pressedScale,
      child: Material(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                MotionStateIcon(
                  stateKey: icon,
                  child: Icon(
                    icon,
                    size: 20,
                    color: enabled ? AppColors.text : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? AppColors.text : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                ),
                if (showProBadge) ...[
                  const SizedBox(width: 5),
                  const ProCrownBadge(),
                ],
              ],
            ),
          ),
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

class _CryptoRelatedBadge extends StatelessWidget {
  const _CryptoRelatedBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('detail-crypto-related-badge'),
    height: 30,
    padding: const EdgeInsets.only(left: 12, right: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFFFB15C).withValues(alpha: .13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFFFB15C).withValues(alpha: .32)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '加密相关',
          style: TextStyle(
            color: Color(0xFFE58524),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          key: const Key('detail-crypto-related-info'),
          tooltip: '查看加密相关说明',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 30),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppHaptics.selection();
            showAppBottomSheet<void>(
              context: context,
              builder: (sheetContext) => const _CryptoRelatedInfoSheet(),
            );
          },
          icon: const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE58524),
            size: 16,
          ),
        ),
      ],
    ),
  );
}

class _CryptoRelatedInfoSheet extends StatelessWidget {
  const _CryptoRelatedInfoSheet();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('detail-crypto-related-sheet'),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: AppColors.line),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.currency_bitcoin_rounded,
                  color: Color(0xFFE58524),
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '加密相关',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '可能涉及数字资产价格、托管、链上转账及地区合规风险；不等同于存款账户，功能与资格以官方实时流程为准。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BasicInfo extends StatelessWidget {
  const _BasicInfo({required this.card, required this.detail});

  final CardSummary card;
  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-basic-info'),
      padding: const EdgeInsets.all(8),
      decoration: _detailPanelDecoration(),
      child: card.isGlobalAccount
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetaCell(label: '适用地区', value: detail.region),
                const SizedBox(height: 6),
                _MetaCell(label: '入金方式', value: detail.funding),
                const SizedBox(height: 6),
                _MetaCell(label: '开放状态', value: detail.availability),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactMetaCell(
                  label: '适用地区',
                  value: detail.region,
                  fullValueKey: const Key('detail-region-value'),
                ),
                if (card.cashbackRate.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _CompactMetaCell(
                    label: '返现概览',
                    value: card.cashbackRate,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final funding = _CompactMetaCell(
                      label: '入金方式',
                      value: detail.funding,
                      maxLines: 2,
                      fullValueKey: const Key('detail-funding-value'),
                    );
                    final availability = _CompactMetaCell(
                      label: '开放状态',
                      value: detail.availability,
                    );
                    final stack =
                        constraints.maxWidth < 260 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20;
                    if (stack) {
                      return Column(
                        key: const Key('detail-funding-availability'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          funding,
                          const SizedBox(height: 6),
                          availability,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        key: const Key('detail-funding-availability'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: funding),
                          const SizedBox(width: 6),
                          Expanded(child: availability),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _CompactMetaCell extends StatelessWidget {
  const _CompactMetaCell({
    required this.label,
    required this.value,
    this.maxLines = 3,
    this.fullValueKey,
  });

  final String label;
  final String value;
  final int maxLines;
  final Key? fullValueKey;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xFF272E40)
            : const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (fullValueKey != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: fullValueKey == null ? null : maxLines,
            overflow: fullValueKey == null ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
    if (fullValueKey == null) return content;
    return Semantics(
      button: true,
      label: '查看完整$label信息',
      child: GestureDetector(
        key: fullValueKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          showAppBottomSheet<void>(
            context: context,
            builder: (sheetContext) =>
                _FullDetailValueSheet(label: label, value: value),
          );
        },
        child: content,
      ),
    );
  }
}

class _FullDetailValueSheet extends StatelessWidget {
  const _FullDetailValueSheet({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detail-full-value-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .62,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppColors.text),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.line),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: SelectableText(
                value,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xFF272E40)
            : const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
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
    final opening = detail.openingRequirements;
    return Container(
      key: const Key('detail-kyc'),
      padding: const EdgeInsets.all(18),
      decoration: _detailPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opening == null ? '身份验证（KYC）' : '开卡条件',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (opening != null && opening.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '通常需要：${opening.summary}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (opening == null)
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
            )
          else
            Container(
              key: const Key('detail-opening-requirements'),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised.withValues(alpha: .48),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line.withValues(alpha: .7)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < OpeningRequirementKind.values.length;
                      index++
                    ) ...[
                      if (index > 0)
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: AppColors.line.withValues(alpha: .72),
                        ),
                      Expanded(
                        child: _OpeningRequirementItem(
                          kind: OpeningRequirementKind.values[index],
                          state: opening.stateFor(
                            OpeningRequirementKind.values[index],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

class _OpeningRequirementItem extends StatelessWidget {
  const _OpeningRequirementItem({required this.kind, required this.state});

  final OpeningRequirementKind kind;
  final OpeningRequirementState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon, stateLabel) = switch (state) {
      OpeningRequirementState.required => (
        AppColors.mint,
        Icons.check_rounded,
        '需要',
      ),
      OpeningRequirementState.notRequired => (
        AppColors.textMuted,
        Icons.remove_rounded,
        '不需要',
      ),
      OpeningRequirementState.unknown => (
        const Color(0xFFE7A84B),
        Icons.question_mark_rounded,
        '待确认',
      ),
    };
    return Semantics(
      key: Key('opening-requirement-${kind.name}'),
      label: '${kind.label}，$stateLabel',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kind.label,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: .32)),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stateLabel,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              Icon(Icons.location_city_rounded, color: color, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '中国大陆申请与 KYC',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
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
              fontSize: 11.5,
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
                    fontSize: 10.5,
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
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.35,
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

  String _asset(PaymentChannel channel) => switch (channel) {
    PaymentChannel.applePay => 'assets/payment-logos/apple-pay.png',
    PaymentChannel.googlePay =>
      AppColors.isDark
          ? 'assets/payment-logos/google-pay-dark.png'
          : 'assets/payment-logos/google-pay.png',
    PaymentChannel.wechatPay => 'assets/payment-logos/wechat-pay.png',
    PaymentChannel.alipay => 'assets/payment-logos/alipay.png',
  };

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
            Semantics(
              label: channel.label,
              child: Container(
                key: Key('detail-payment-${channel.name}'),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x8A3A4560), Color(0xD1181C28)],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: .34),
                            Colors.white.withValues(alpha: .14),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.isDark
                        ? const Color(0x24C6D8FF)
                        : Colors.white.withValues(alpha: .30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.isDark
                          ? const Color(0x3D050810)
                          : const Color(0x160D1C42),
                      blurRadius: AppColors.isDark ? 30 : 18,
                      offset: const Offset(0, 7),
                    ),
                    if (AppColors.isDark)
                      const BoxShadow(
                        color: Color(0x14FFFFFF),
                        blurRadius: 0,
                        spreadRadius: 1,
                        offset: Offset(0, 1),
                      ),
                  ],
                ),
                child: Image.asset(
                  _asset(channel),
                  height: 26,
                  fit: BoxFit.contain,
                  color: AppColors.isDark && channel == PaymentChannel.applePay
                      ? Colors.white
                      : null,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps payment-channel branding aligned with the platform being shipped.
///
/// Payment-channel information remains useful on Android, but Apple has
/// explicitly asked that this module not be shown in the iOS app.
/// This is intentionally platform-owned rather than remotely configurable so
/// the reviewed iOS experience cannot change after approval.
Set<PaymentChannel> paymentChannelsForPlatform(
  Set<PaymentChannel> channels,
  TargetPlatform platform,
) => platform == TargetPlatform.iOS ? const {} : {...channels};

class _SupportedCurrenciesBlock extends StatelessWidget {
  const _SupportedCurrenciesBlock({required this.currencies});

  final List<String> currencies;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('detail-supported-currencies'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '支持的具体货币',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${currencies.length}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final itemWidth = (constraints.maxWidth - gap * 3) / 4;
              return Wrap(
                key: const Key('detail-currency-grid'),
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final currency in currencies)
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        key: Key('detail-currency-$currency'),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.cyan.withValues(alpha: .20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currencyFlag(currency),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              currency,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '币种能力会因注册地区、账户类型和审核结果不同，以官网及实际账户页面为准。',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

String _currencyFlag(String currency) => switch (currency.toUpperCase()) {
  'AED' => '🇦🇪',
  'AUD' => '🇦🇺',
  'BRL' => '🇧🇷',
  'CAD' => '🇨🇦',
  'CHF' => '🇨🇭',
  'CLP' => '🇨🇱',
  'CNY' => '🇨🇳',
  'COP' => '🇨🇴',
  'CZK' => '🇨🇿',
  'DKK' => '🇩🇰',
  'EGP' => '🇪🇬',
  'EUR' => '🇪🇺',
  'GBP' => '🇬🇧',
  'HKD' => '🇭🇰',
  'HUF' => '🇭🇺',
  'IDR' => '🇮🇩',
  'ILS' => '🇮🇱',
  'INR' => '🇮🇳',
  'ISK' => '🇮🇸',
  'JPY' => '🇯🇵',
  'KRW' => '🇰🇷',
  'KZT' => '🇰🇿',
  'MAD' => '🇲🇦',
  'MXN' => '🇲🇽',
  'MYR' => '🇲🇾',
  'NOK' => '🇳🇴',
  'NZD' => '🇳🇿',
  'PHP' => '🇵🇭',
  'PLN' => '🇵🇱',
  'QAR' => '🇶🇦',
  'RON' => '🇷🇴',
  'RSD' => '🇷🇸',
  'SAR' => '🇸🇦',
  'SEK' => '🇸🇪',
  'SGD' => '🇸🇬',
  'THB' => '🇹🇭',
  'TRY' => '🇹🇷',
  'USD' => '🇺🇸',
  'VND' => '🇻🇳',
  'ZAR' => '🇿🇦',
  _ => '💱',
};

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

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({required this.title, required this.rules, super.key});

  final String title;
  final List<DetailRule> rules;

  IconData _icon(DetailFeatureIcon icon) => switch (icon) {
    DetailFeatureIcon.wallet => Icons.account_balance_wallet_outlined,
    DetailFeatureIcon.shield => Icons.shield_outlined,
    DetailFeatureIcon.payments => Icons.payments_outlined,
    DetailFeatureIcon.globe => Icons.public_rounded,
  };

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

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: key,
      title: title,
      child: Column(
        children: [
          for (var index = 0; index < rules.length; index++) ...[
            if (index > 0) Divider(height: 24, color: AppColors.line),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icon(rules[index].icon),
                  color: _color(rules[index].icon),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rules[index].label,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rules[index].value,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeBlock extends StatelessWidget {
  const _FeeBlock({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    final hasDetails = detail.fees.any((fee) => fee.note?.isNotEmpty == true);
    return _DetailPanel(
      key: const Key('detail-fees'),
      title: '费用',
      subtitle: hasDetails ? '点击带箭头的项目查看分档与限制' : null,
      child: Column(
        children: [
          for (var index = 0; index < detail.fees.length; index++) ...[
            if (index > 0) Divider(height: 22, color: AppColors.line),
            _FeeRow(fee: detail.fees[index]),
          ],
        ],
      ),
    );
  }
}

class _FeeRow extends StatefulWidget {
  const _FeeRow({required this.fee});

  final FeeLine fee;

  @override
  State<_FeeRow> createState() => _FeeRowState();
}

class _FeeRowState extends State<_FeeRow> {
  bool _expanded = false;

  void _toggle() {
    if (widget.fee.note?.isNotEmpty != true) return;
    AppHaptics.selection();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.fee;
    final hasDetails = fee.note?.isNotEmpty == true;
    return Semantics(
      button: hasDetails,
      expanded: hasDetails ? _expanded : null,
      label: hasDetails ? '${fee.label}，${fee.value}，查看详细说明' : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('detail-fee-${fee.label}'),
          onTap: hasDetails ? _toggle : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        fee.label,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Align(
                        key: Key('detail-fee-value-${fee.label}'),
                        alignment: Alignment.centerRight,
                        child: Text(
                          fee.value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (hasDetails) ...[
                      const SizedBox(width: 5),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 19,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_expanded
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            key: Key('detail-fee-note-${fee.label}'),
                            padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                            decoration: BoxDecoration(
                              color: AppColors.isDark
                                  ? Colors.white.withValues(alpha: .045)
                                  : const Color(
                                      0xFF6877FF,
                                    ).withValues(alpha: .055),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              fee.note!,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
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
                      '公开资料整理，具体信息以发卡方为准。如有错误、侵权或冒犯，可从更多操作提交更正或下架请求。',
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
      decoration: _detailPanelDecoration(),
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

BoxDecoration _detailPanelDecoration() => BoxDecoration(
  color: AppColors.isDark ? const Color(0xEE30384C) : const Color(0xF5FFFFFF),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color: AppColors.isDark ? const Color(0x14FFFFFF) : Colors.white,
  ),
  boxShadow: [
    BoxShadow(
      color: const Color(
        0xFF394B7A,
      ).withValues(alpha: AppColors.isDark ? .10 : .045),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ],
);
