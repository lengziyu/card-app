import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/core/localization/app_language.dart';
import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/auth/presentation/auth_page.dart';
import 'package:card_app/features/add/presentation/add_card_page.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/catalog/data/local_card_details.dart';
import 'package:card_app/features/catalog/data/remote_card_catalog.dart';
import 'package:card_app/features/catalog/data/remote_card_details.dart';
import 'package:card_app/features/catalog/data/remote_catalog_settings.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/presentation/card_correction_page.dart';
import 'package:card_app/features/catalog/presentation/card_preview_page.dart';
import 'package:card_app/features/home/presentation/home_page.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/market/presentation/card_canvas_page.dart';
import 'package:card_app/features/market/presentation/card_search_page.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:card_app/features/notifications/data/notification_repository.dart';
import 'package:card_app/features/notifications/data/notification_service.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:card_app/features/profile/presentation/profile_subpage.dart';
import 'package:card_app/features/profile/data/local_guest_state.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/presentation/article_detail_page.dart';
import 'package:card_app/features/ranking/presentation/ranking_page.dart';
import 'package:card_app/features/shell/widgets/aurora_background.dart';
import 'package:card_app/features/shell/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.enableRemoteData,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    super.key,
  });

  final bool enableRemoteData;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _homeCardHeightKey = 'card-app-home-card-height-scale-v1';
  static const _homeCardDisplayModeKey = 'card-app-home-card-display-mode-v1';
  static const _homeCardDisplayModeOverride = String.fromEnvironment(
    'HOME_CARD_DISPLAY_MODE',
  );
  static const _initialMockState = String.fromEnvironment(
    'MOCK_STATE',
    defaultValue: 'cards',
  );

  int _index = 0;
  bool _navigationHidden = false;
  bool _cardCanvasOpen = false;
  CardSearchMode? _searchMode;
  AuthMode? _authMode;
  CardSummary? _previewCard;
  ProfileSection? _profileSection;
  final List<ProfileSection> _profileSectionHistory = [];
  LocalArticle? _article;
  CardSummary? _correctionCard;
  final Set<String> _favoriteCardIds = {'etherfi-core', 'metamask-card'};
  final Set<String> _favoriteArticleIds = <String>{};
  final Map<String, LocalArticle> _knownArticles = {
    for (final article in localArticles) article.id: article,
  };
  final List<String> _recentCardIds = [
    'etherfi-core',
    'bybit-card',
    'redotpay',
  ];
  final List<LocalSubmission> _submissions = [];
  List<AppMessage> _appMessages = const [];
  bool _pushEnabled = false;
  double _homeCardHeightScale = homeCardStackDefaultScale;
  HomeCardDisplayMode _homeCardDisplayMode = _initialHomeCardDisplayMode();
  List<CardSummary> _catalogCards = localCardCatalog;
  late final Set<String> _addedCardIds = _initialMockState == 'empty'
      ? <String>{}
      : localCardCatalog
            .where((card) => card.assetPath != null)
            .map((card) => card.id)
            .toSet();

  late final ApiClient _apiClient;
  late final CardCatalogRepository _catalogRepository;
  late final RemoteRankingRepository _rankingRepository;
  late final RemoteCardDetailRepository _remoteDetailRepository;
  late final RemoteCatalogSettingsRepository _catalogSettingsRepository;
  late final NotificationRepository _notificationRepository;
  late final NotificationService _notificationService;
  StreamSubscription<String>? _notificationRouteSubscription;
  final LocalGuestStateRepository _localStateRepository =
      LocalGuestStateRepository();
  static const _detailRepository = LocalCardDetailRepository();

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _catalogRepository = !widget.enableRemoteData
        ? const _TestCatalogRepository()
        : RemoteCardCatalogRepository(_apiClient);
    _rankingRepository = RemoteRankingRepository(_apiClient);
    _remoteDetailRepository = RemoteCardDetailRepository(_apiClient);
    _catalogSettingsRepository = RemoteCatalogSettingsRepository(_apiClient);
    _notificationRepository = NotificationRepository(_apiClient);
    _notificationService = NotificationService(_notificationRepository);
    _notificationRouteSubscription = _notificationService.routes.listen(
      _openNotificationRoute,
    );
    unawaited(_localStateRepository.clear());
    unawaited(_loadHomeCardHeightScale());
    unawaited(_loadHomeCardDisplayMode());
    unawaited(_restorePushPreference());
    if (widget.enableRemoteData) {
      _loadRemoteCatalog();
      unawaited(_loadAppMessages());
    }
  }

  Future<void> _loadHomeCardHeightScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble(_homeCardHeightKey);
    if (!mounted || value == null) return;
    setState(() => _homeCardHeightScale = clampHomeCardHeightScale(value));
  }

  Future<void> _loadHomeCardDisplayMode() async {
    if (_hasHomeCardDisplayModeOverride) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_homeCardDisplayModeKey);
    if (!mounted || saved == null) return;
    final matches = HomeCardDisplayMode.values.where(
      (mode) => mode.name == saved,
    );
    if (matches.isNotEmpty) {
      setState(() => _homeCardDisplayMode = matches.first);
    }
  }

  static bool get _hasHomeCardDisplayModeOverride => HomeCardDisplayMode.values
      .any((mode) => mode.name == _homeCardDisplayModeOverride);

  static HomeCardDisplayMode _initialHomeCardDisplayMode() {
    for (final mode in HomeCardDisplayMode.values) {
      if (mode.name == _homeCardDisplayModeOverride) return mode;
    }
    return HomeCardDisplayMode.stack;
  }

  Future<void> _restorePushPreference() async {
    final enabled = await _notificationService.isEnabled();
    if (!mounted) return;
    setState(() => _pushEnabled = enabled);
    if (enabled && widget.enableRemoteData) {
      unawaited(_notificationService.start(locale: _notificationLocale));
    }
  }

  Future<void> _loadAppMessages({bool rethrowOnError = false}) async {
    if (!widget.enableRemoteData) return;
    try {
      final messages = await _notificationRepository.loadMessages(
        await _notificationService.installationId(),
      );
      if (mounted) setState(() => _appMessages = messages);
    } catch (error, stackTrace) {
      // The profile page keeps a friendly empty state when the service is offline.
      if (rethrowOnError) Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String get _notificationLocale =>
      widget.selectedLanguage.locale?.toLanguageTag() ?? 'system';

  Future<void> _changePushEnabled(bool enabled) async {
    if (!widget.enableRemoteData) {
      if (mounted) {
        AppNotice.info(context, '连接正式服务后即可开启内容更新提醒。', title: '暂不可用');
      }
      return;
    }
    if (!enabled) {
      await _notificationService.disable();
      if (mounted) setState(() => _pushEnabled = false);
      return;
    }
    final result = await _notificationService.enable(
      locale: _notificationLocale,
    );
    if (!mounted) return;
    switch (result) {
      case NotificationEnableResult.enabled:
        setState(() => _pushEnabled = true);
        AppNotice.success(context, '资讯和新卡上线时会提醒你。', title: '通知已开启');
      case NotificationEnableResult.denied:
        AppNotice.info(context, '你可以在系统设置中允许“集卡”发送通知。', title: '通知权限未开启');
      case NotificationEnableResult.unavailable:
        AppNotice.warning(context, '通知服务尚未配置或当前网络不可用。', title: '暂时无法开启');
    }
  }

  void _openNotificationRoute(String route) {
    if (!mounted) return;
    const cardPrefix = '/card/';
    const articlePrefix = '/articles/';
    if (route.startsWith(cardPrefix)) {
      final id = route.substring(cardPrefix.length);
      final matches = _catalogCards.where((item) => item.id == id);
      if (matches.isNotEmpty) _openCard(matches.first);
      return;
    }
    if (route.startsWith(articlePrefix) && widget.enableRemoteData) {
      final slug = route.substring(articlePrefix.length);
      unawaited(() async {
        try {
          final article = await _rankingRepository.loadArticle(slug);
          if (mounted) setState(() => _article = article.article);
        } catch (_) {
          if (mounted) {
            AppNotice.info(context, '内容已更新，请稍后在资讯页查看。', title: '打开失败');
          }
        }
      }());
    }
  }

  void _changeHomeCardHeightScale(double value) {
    final nextValue = clampHomeCardHeightScale(value);
    setState(() => _homeCardHeightScale = nextValue);
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setDouble(_homeCardHeightKey, nextValue),
      ),
    );
  }

  void _changeHomeCardDisplayMode(HomeCardDisplayMode mode) {
    setState(() => _homeCardDisplayMode = mode);
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) =>
            preferences.setString(_homeCardDisplayModeKey, mode.name),
      ),
    );
  }

  void _reorderHomeCards(List<String> orderedIds) {
    final currentIds = _addedCardIds.toSet();
    final nextIds = [
      ...orderedIds.where(currentIds.contains),
      ..._addedCardIds.where((id) => !orderedIds.contains(id)),
    ];
    if (nextIds.length != _addedCardIds.length) return;
    setState(() {
      _addedCardIds
        ..clear()
        ..addAll(nextIds);
    });
  }

  Future<void> _loadRemoteCatalog({
    bool force = false,
    bool rethrowOnError = false,
  }) async {
    try {
      final homeFuture = _loadCardIdsOrEmpty(
        _catalogSettingsRepository.loadHomeDefaultCardIds(),
      );
      final orderFuture = _loadCardIdsOrEmpty(
        _catalogSettingsRepository.loadListCardOrder(),
      );
      final cards = await _catalogRepository.loadCards(force: force);
      final homeIds = await homeFuture;
      final order = await orderFuture;
      final orderById = {
        for (var index = 0; index < order.length; index++) order[index]: index,
      };
      final sortedCards = [...cards]
        ..sort((left, right) {
          final leftOrder = orderById[left.id];
          final rightOrder = orderById[right.id];
          if (leftOrder == null && rightOrder == null) return 0;
          if (leftOrder == null) return 1;
          if (rightOrder == null) return -1;
          return leftOrder.compareTo(rightOrder);
        });
      if (mounted) {
        setState(() {
          _catalogCards = sortedCards;
          if (_initialMockState != 'empty' && homeIds.isNotEmpty) {
            _addedCardIds
              ..clear()
              ..addAll(homeIds);
          }
        });
        _warmCardArtwork(
          sortedCards.where((card) => homeIds.contains(card.id)).take(8),
        );
      }
    } catch (error, stackTrace) {
      // 市场展示正式失败态；搜索继续使用随包目录作为离线兜底。
      if (rethrowOnError) Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<String>> _loadCardIdsOrEmpty(Future<List<String>> request) async {
    try {
      return await request;
    } catch (_) {
      return const [];
    }
  }

  void _warmCardArtwork(Iterable<CardSummary> cards) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final card in cards) {
        final imageUrl = card.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) continue;
        unawaited(
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            context,
          ).catchError((_) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _notificationRouteSubscription?.cancel();
    _notificationService.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _addCard() {
    _openAuth();
  }

  void _openAuth([AuthMode mode = AuthMode.login]) {
    HapticFeedback.selectionClick();
    setState(() {
      _authMode = mode;
    });
  }

  void _requireLogin() {
    AppNotice.info(context, '登录后即可自定义卡片、收藏和反馈。', title: '需要登录');
    _openAuth();
  }

  void _changeCard(CardSummary card, bool added) {
    _requireLogin();
  }

  void _showSearch(CardSearchMode mode) {
    if (mode == CardSearchMode.add) {
      _openAuth();
      return;
    }
    setState(() {
      _searchMode = mode;
      _previewCard = null;
    });
  }

  void _openCardCanvas() {
    HapticFeedback.selectionClick();
    setState(() {
      _cardCanvasOpen = true;
      _searchMode = null;
    });
  }

  void _openCard(CardSummary card) {
    setState(() {
      _previewCard = card;
      _recentCardIds
        ..remove(card.id)
        ..insert(0, card.id);
      if (_recentCardIds.length > 8) {
        _recentCardIds.removeRange(8, _recentCardIds.length);
      }
    });
  }

  void _changeCardFavorite(CardSummary card, bool favorite) {
    _requireLogin();
  }

  void _changeArticleFavorite(LocalArticle article, bool favorite) {
    _requireLogin();
  }

  void _saveSubmission(LocalSubmissionDraft draft) {
    final submission = LocalSubmission.fromDraft(draft);
    setState(() => _submissions.insert(0, submission));
  }

  void _deleteSubmission(String id) {
    setState(() => _submissions.removeWhere((item) => item.id == id));
  }

  List<CardSummary> _cardsForIds(Iterable<String> ids) {
    final cardsById = {
      for (final card in localCardCatalog) card.id: card,
      for (final card in _catalogCards) card.id: card,
    };
    return ids.map((id) => cardsById[id]).whereType<CardSummary>().toList();
  }

  Future<void> _openArticle(LocalArticle article) async {
    setState(() => _article = article);
    if (!widget.enableRemoteData) return;
    try {
      final detail = await _rankingRepository.loadArticle(article.id);
      if (mounted && _article?.id == article.id) {
        setState(() {
          _article = detail.article;
          _knownArticles[detail.article.id] = detail.article;
        });
      }
      await _rankingRepository.recordArticleView(article.id);
    } catch (_) {
      // 列表摘要仍可离线阅读，详情请求失败不打断当前页面。
    }
  }

  void _openProfileSection(ProfileSection section) {
    setState(() {
      _profileSectionHistory.clear();
      _profileSection = section;
    });
  }

  void _openNestedProfileSection(ProfileSection section) {
    if (_profileSection == section) return;
    setState(() {
      final currentSection = _profileSection;
      if (currentSection != null) {
        _profileSectionHistory.add(currentSection);
      }
      _profileSection = section;
    });
  }

  void _openCorrection(CardSummary card) {
    _requireLogin();
  }

  void _viewSimilarCards() {
    setState(() {
      _index = 1;
      _navigationHidden = false;
      _cardCanvasOpen = false;
      _searchMode = null;
      _previewCard = null;
      _profileSection = null;
      _profileSectionHistory.clear();
      _article = null;
      _correctionCard = null;
    });
  }

  void _closeOverlay() {
    setState(() {
      if (_authMode != null) {
        _authMode = null;
      } else if (_correctionCard != null) {
        _correctionCard = null;
      } else if (_previewCard != null) {
        _previewCard = null;
      } else if (_article != null) {
        _article = null;
      } else if (_profileSection != null) {
        _profileSection = _profileSectionHistory.isEmpty
            ? null
            : _profileSectionHistory.removeLast();
      } else if (_cardCanvasOpen) {
        _cardCanvasOpen = false;
      } else {
        _searchMode = null;
      }
    });
  }

  void _selectDestination(int index) {
    if (index == _index) return;
    if (index == 4) {
      _openAuth();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _navigationHidden = false;
      _cardCanvasOpen = false;
      _searchMode = null;
      _previewCard = null;
      _profileSection = null;
      _profileSectionHistory.clear();
      _article = null;
      _correctionCard = null;
      _authMode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay =
        _cardCanvasOpen ||
        _searchMode != null ||
        _previewCard != null ||
        _profileSection != null ||
        _article != null ||
        _correctionCard != null ||
        _authMode != null;
    return PopScope(
      canPop: !hasOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeOverlay();
      },
      child: AuroraBackground(
        authBackground: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: !hasOverlay,
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Offstage(
                    offstage: hasOverlay,
                    child: IgnorePointer(
                      ignoring: hasOverlay,
                      child: ExcludeSemantics(
                        excluding: hasOverlay,
                        child: _mainBody(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 360),
                    reverseDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.055, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (currentChild, previousChildren) =>
                        currentChild ?? const SizedBox.shrink(),
                    child: hasOverlay
                        ? _EdgeSwipeBack(
                            key: ValueKey(_overlayIdentity),
                            onBack: _closeOverlay,
                            child: _overlayBody()!,
                          )
                        : const SizedBox.shrink(key: ValueKey('main-pages')),
                  ),
                ),
                if (!hasOverlay && !_navigationHidden)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 18),
                          child: child,
                        ),
                      ),
                      child: BottomNavigation(
                        selectedIndex: _index,
                        addSelected: _index == 4,
                        onDestinationSelected: _selectDestination,
                        onAdd: _addCard,
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

  String get _overlayIdentity {
    if (_authMode case final mode?) return 'auth-${mode.name}';
    if (_correctionCard case final card?) return 'correction-${card.id}';
    if (_previewCard case final card?) return 'preview-${card.id}';
    if (_article case final article?) return 'article-${article.id}';
    if (_profileSection case final section?) return 'profile-${section.name}';
    if (_searchMode case final mode?) return 'search-${mode.name}';
    if (_cardCanvasOpen) return 'card-canvas';
    return 'main-pages';
  }

  Widget? _overlayBody() {
    final authMode = _authMode;
    if (authMode != null) {
      return AuthPage(
        mode: authMode,
        onBack: _closeOverlay,
        onModeChanged: (mode) => setState(() => _authMode = mode),
      );
    }
    final correctionCard = _correctionCard;
    if (correctionCard != null) {
      return CardCorrectionPage(
        card: correctionCard,
        onBack: _closeOverlay,
        onSubmit: _saveSubmission,
      );
    }
    final previewCard = _previewCard;
    if (previewCard != null) {
      if (!widget.enableRemoteData) {
        return CardPreviewPage(
          card: previewCard,
          detail: _detailRepository.detailFor(previewCard),
          added: _addedCardIds.contains(previewCard.id),
          favorite: _favoriteCardIds.contains(previewCard.id),
          onBack: _closeOverlay,
          onAddedChanged: (added) => _changeCard(previewCard, added),
          onFavoriteChanged: (favorite) =>
              _changeCardFavorite(previewCard, favorite),
          onCorrection: () => _openCorrection(previewCard),
          onViewSimilar: _viewSimilarCards,
        );
      }
      return FutureBuilder(
        future: _remoteDetailRepository.detailFor(previewCard),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CardPreviewSkeleton(onBack: _closeOverlay);
          }
          final detail =
              snapshot.data ?? _detailRepository.detailFor(previewCard);
          return CardPreviewPage(
            card: previewCard,
            detail: detail,
            added: _addedCardIds.contains(previewCard.id),
            favorite: _favoriteCardIds.contains(previewCard.id),
            onBack: _closeOverlay,
            onAddedChanged: (added) => _changeCard(previewCard, added),
            onFavoriteChanged: (favorite) =>
                _changeCardFavorite(previewCard, favorite),
            onCorrection: () => _openCorrection(previewCard),
            onViewSimilar: _viewSimilarCards,
          );
        },
      );
    }
    final article = _article;
    if (article != null) {
      return ArticleDetailPage(
        article: article,
        cards: _catalogCards,
        favorite: _favoriteArticleIds.contains(article.id),
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onFavoriteChanged: (favorite) =>
            _changeArticleFavorite(article, favorite),
        onLike: widget.enableRemoteData
            ? () => _rankingRepository.likeArticle(article.id)
            : null,
      );
    }
    final profileSection = _profileSection;
    if (profileSection != null) {
      return ProfileSubpage(
        key: ValueKey(profileSection),
        section: profileSection,
        cards: _cardsForIds(_addedCardIds),
        favoriteCards: _cardsForIds(_favoriteCardIds),
        recentCards: _cardsForIds(_recentCardIds),
        favoriteArticles: _favoriteArticleIds
            .map((id) => _knownArticles[id])
            .whereType<LocalArticle>()
            .toList(growable: false),
        submissions: _submissions,
        appMessages: _appMessages,
        cardHeightScale: _homeCardHeightScale,
        onCardHeightScaleChanged: _changeHomeCardHeightScale,
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onOpenArticle: _openArticle,
        onOpenSection: _openNestedProfileSection,
        onSubmit: _saveSubmission,
        onDeleteSubmission: _deleteSubmission,
        onRefreshAppMessages: () => _loadAppMessages(rethrowOnError: true),
        onOpenAppMessage: (message) => _openNotificationRoute(message.route),
        onLogin: _openAuth,
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        pushEnabled: _pushEnabled,
        onPushEnabledChanged: _changePushEnabled,
      );
    }
    final searchMode = _searchMode;
    if (searchMode != null) {
      return CardSearchPage(
        mode: searchMode,
        cards: _catalogCards,
        addedCardIds: _addedCardIds,
        onBack: _closeOverlay,
        onRefresh: () => _refreshCatalog(force: true),
        onOpenCard: _openCard,
        onCardChanged: _changeCard,
      );
    }
    if (_cardCanvasOpen) {
      return CardCanvasPage(
        cards: _catalogCards,
        onBack: _closeOverlay,
        onOpenCard: _openCard,
      );
    }
    return null;
  }

  Future<void> _refreshCatalog({bool force = false}) async {
    if (!widget.enableRemoteData) return;
    await _loadRemoteCatalog(force: force, rethrowOnError: true);
  }

  Widget _mainBody() {
    return _AnimatedTabStage(
      index: _index,
      children: [
        HomePage(
          cards: _cardsForIds(_addedCardIds),
          cardHeightScale: _homeCardHeightScale,
          displayMode: _homeCardDisplayMode,
          onAddCard: _addCard,
          onOpenCard: _openCard,
          onCardHeightScaleChanged: _changeHomeCardHeightScale,
          onReorderCards: _reorderHomeCards,
          onDisplayModeChanged: _changeHomeCardDisplayMode,
          onToggleNavigation: () =>
              setState(() => _navigationHidden = !_navigationHidden),
        ),
        MarketPage(
          repository: _catalogRepository,
          onSearch: () => _showSearch(CardSearchMode.market),
          onOpenCanvas: _openCardCanvas,
          onOpenCard: _openCard,
        ),
        RankingPage(
          cards: _catalogCards,
          onOpenCard: _openCard,
          onOpenArticle: _openArticle,
          repository: _rankingRepository,
          enableRemoteData: widget.enableRemoteData,
        ),
        ProfilePage(
          cardCount: _addedCardIds.length,
          favoriteCount: _favoriteCardIds.length + _favoriteArticleIds.length,
          historyCount: _recentCardIds.length,
          submissionCount: _submissions.length,
          onOpenSection: _openProfileSection,
          onLogin: _openAuth,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
        AddCardPage(
          cards: _catalogCards,
          addedCardIds: _addedCardIds,
          onCardChanged: _changeCard,
          onSearch: () => _showSearch(CardSearchMode.add),
        ),
      ],
    );
  }
}

class _AnimatedTabStage extends StatefulWidget {
  const _AnimatedTabStage({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedTabStage> createState() => _AnimatedTabStageState();
}

/// H5 页面在触屏设备上支持从左边缘右滑返回；所有二级页面共用这一层。
class _EdgeSwipeBack extends StatefulWidget {
  const _EdgeSwipeBack({required this.child, required this.onBack, super.key});

  final Widget child;
  final VoidCallback onBack;

  @override
  State<_EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<_EdgeSwipeBack> {
  bool _tracking = false;
  double _distance = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (details) {
      _tracking = details.globalPosition.dx <= 28;
      _distance = 0;
    },
    onHorizontalDragUpdate: (details) {
      if (_tracking && details.primaryDelta != null) {
        _distance += details.primaryDelta!;
      }
    },
    onHorizontalDragEnd: (details) {
      final velocity = details.primaryVelocity ?? 0;
      if (_tracking && (_distance > 72 || velocity > 680)) widget.onBack();
      _tracking = false;
      _distance = 0;
    },
    onHorizontalDragCancel: () {
      _tracking = false;
      _distance = 0;
    },
    child: widget.child,
  );
}

class _AnimatedTabStageState extends State<_AnimatedTabStage>
    with SingleTickerProviderStateMixin {
  late final Set<int> _visited = {widget.index};
  late final AnimationController _controller;
  int? _outgoingIndex;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 340),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _outgoingIndex != null) {
            setState(() => _outgoingIndex = null);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 340);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _visited.add(widget.index);
    _outgoingIndex = oldWidget.index;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        for (
          var childIndex = 0;
          childIndex < widget.children.length;
          childIndex++
        )
          if (_visited.contains(childIndex))
            KeyedSubtree(
              key: ValueKey('main-tab-$childIndex'),
              child: Offstage(
                offstage:
                    childIndex != widget.index && childIndex != _outgoingIndex,
                child: IgnorePointer(
                  ignoring: childIndex != widget.index,
                  child: ExcludeSemantics(
                    excluding: childIndex != widget.index,
                    child: TickerMode(
                      enabled:
                          childIndex == widget.index ||
                          childIndex == _outgoingIndex,
                      child: FadeTransition(
                        opacity: childIndex == widget.index
                            ? curvedAnimation
                            : ReverseAnimation(curvedAnimation),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: childIndex == widget.index
                                ? Offset(_direction * 0.045, 0)
                                : Offset.zero,
                            end: childIndex == widget.index
                                ? Offset.zero
                                : Offset(_direction * -0.025, 0),
                          ).animate(curvedAnimation),
                          child: widget.children[childIndex],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _TestCatalogRepository implements CardCatalogRepository {
  const _TestCatalogRepository();

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async =>
      const <CardSummary>[];
}
