import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_app/core/localization/app_language.dart';
import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/auth/data/auth_controller.dart';
import 'package:card_app/features/auth/data/auth_account_repository.dart';
import 'package:card_app/features/auth/data/auth_repository.dart';
import 'package:card_app/features/auth/data/supabase_auth_repository.dart';
import 'package:card_app/features/auth/presentation/auth_page.dart';
import 'package:card_app/features/add/presentation/add_card_page.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/catalog/data/local_card_details.dart';
import 'package:card_app/features/catalog/data/remote_card_catalog.dart';
import 'package:card_app/features/catalog/data/remote_card_details.dart';
import 'package:card_app/features/catalog/data/remote_global_account_catalog.dart';
import 'package:card_app/features/catalog/data/remote_catalog_settings.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/presentation/card_correction_page.dart';
import 'package:card_app/features/catalog/presentation/card_comparison_page.dart';
import 'package:card_app/features/catalog/presentation/card_preview_page.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/home/presentation/home_page.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/market/presentation/card_canvas_page.dart';
import 'package:card_app/features/market/presentation/card_advisor_page.dart';
import 'package:card_app/features/market/presentation/card_search_page.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:card_app/features/market/data/card_advisor_repository.dart';
import 'package:card_app/features/market/widgets/market_card_transition.dart';
import 'package:card_app/features/notifications/data/notification_repository.dart';
import 'package:card_app/features/notifications/data/notification_service.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:card_app/features/profile/presentation/profile_subpage.dart';
import 'package:card_app/features/profile/data/local_guest_state.dart';
import 'package:card_app/features/pro/data/pro_config.dart';
import 'package:card_app/features/pro/data/bill_analysis_repository.dart';
import 'package:card_app/features/pro/data/pro_controller.dart';
import 'package:card_app/features/pro/data/pro_workspace_controller.dart';
import 'package:card_app/features/pro/presentation/pro_page.dart';
import 'package:card_app/features/pro/presentation/bill_analysis_page.dart';
import 'package:card_app/features/pro/presentation/pro_workspace_page.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/presentation/article_detail_page.dart';
import 'package:card_app/features/ranking/presentation/ranking_page.dart';
import 'package:card_app/features/shell/widgets/aurora_background.dart';
import 'package:card_app/features/shell/widgets/bottom_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.enableRemoteData,
    required this.proUnlocked,
    this.proAccessTokenProvider,
    this.proApplicationUserNameProvider,
    this.authRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    super.key,
  });

  final bool enableRemoteData;
  final bool proUnlocked;
  final ProAccessTokenProvider? proAccessTokenProvider;
  final ProApplicationUserNameProvider? proApplicationUserNameProvider;
  final AuthRepository? authRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _homeCardHeightKey = 'card-app-home-card-height-scale-v1';
  static const _homeCardDisplayModeKey = 'card-app-home-card-display-mode-v1';
  static const _hapticsEnabledKey = 'card-app-haptics-enabled-v1';
  static const _cardSwipeHapticsKey = 'card-app-card-swipe-haptics-v1';
  static const _hapticStrengthKey = 'card-app-card-swipe-strength-v1';
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
  bool _cardAdvisorOpen = false;
  bool _proPageOpen = false;
  bool _proWorkspaceOpen = false;
  bool _billAnalysisOpen = false;
  bool _comparisonOpen = false;
  CardSummary? _comparisonInitialCard;
  List<CardSummary>? _comparisonInitialCards;
  CardSummary? _comparisonReturnCard;
  bool _comparisonReturnToWorkspace = false;
  bool _previewReturnToWorkspace = false;
  CardSearchMode? _searchMode;
  AuthMode? _authMode;
  CardSummary? _previewCard;
  CatalogCardSourceGeometry? _marketCardSourceGeometry;
  CardSummary? _marketTransitionCard;
  bool _transitionIncludesSourceTitle = true;
  bool _marketCardClosing = false;
  bool _preserveNavigationAfterMarketClose = false;
  ProfileSection? _profileSection;
  final List<ProfileSection> _profileSectionHistory = [];
  LocalArticle? _article;
  CardSummary? _correctionCard;
  final Set<String> _favoriteCardIds = <String>{};
  final Set<String> _favoriteArticleIds = <String>{};
  final Map<String, LocalArticle> _knownArticles = {
    for (final article in localArticles) article.id: article,
  };
  final List<String> _recentCardIds = <String>[];
  final List<LocalSubmission> _submissions = [];
  bool _hasPersistedGuestState = false;
  List<AppMessage> _appMessages = const [];
  bool _pushEnabled = false;
  bool _hapticsEnabled = true;
  bool _cardSwipeHapticsEnabled = true;
  AppHapticStrength _hapticStrength = AppHapticStrength.medium;
  bool _proModeRestored = false;
  double _homeCardHeightScale = homeCardStackDefaultScale;
  late HomeCardDisplayMode _homeCardDisplayMode;
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
  late final AuthController _authController;
  late final AuthAccountRepository _authAccountRepository;
  late final ProController _proController;
  late final ProWorkspaceController _proWorkspaceController;
  late final BillAnalysisRepository _billAnalysisRepository;
  late final CardAdvisorRepository _cardAdvisorRepository;
  late final AnimationController _marketCardTransitionController;
  StreamSubscription<String>? _notificationRouteSubscription;
  final LocalGuestStateRepository _localStateRepository =
      LocalGuestStateRepository();
  static const _detailRepository = LocalCardDetailRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _marketCardTransitionController = AnimationController(
      vsync: this,
      duration: MotionTokens.sharedCard,
      reverseDuration: MotionTokens.sharedCardReverse,
    );
    _homeCardDisplayMode = widget.proUnlocked
        ? _initialHomeCardDisplayMode()
        : HomeCardDisplayMode.wallet;
    _apiClient = ApiClient();
    _authController = AuthController(
      widget.authRepository ?? SupabaseAuthRepository(),
    )..addListener(_handleAuthChanged);
    final proAccessTokenProvider =
        widget.proAccessTokenProvider ?? _authController.idToken;
    _authAccountRepository = AuthAccountRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _proController = ProController(
      apiClient: _apiClient,
      // 正式认证接入后，在这里读取 Keychain/Keystore 中的短期访问令牌。
      // 不要通过 dart-define 或源码嵌入用户令牌、商店密钥或服务端密钥。
      accessTokenProvider: proAccessTokenProvider,
      // 正式账号服务应提供不可逆、稳定且不含邮箱等个人信息的购买关联 ID。
      applicationUserNameProvider:
          widget.proApplicationUserNameProvider ??
          _authAccountRepository.purchaseApplicationUserName,
      previewUnlocked: widget.proUnlocked,
    )..addListener(_handleProChanged);
    _proWorkspaceController = ProWorkspaceController(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    )..addListener(_handleProWorkspaceChanged);
    _billAnalysisRepository = BillAnalysisRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _cardAdvisorRepository = CardAdvisorRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _catalogRepository = !widget.enableRemoteData
        ? const _TestCatalogRepository()
        : RemoteMarketCatalogRepository(
            cards: RemoteCardCatalogRepository(_apiClient),
            globalAccounts: RemoteGlobalAccountCatalogRepository(_apiClient),
          );
    _rankingRepository = RemoteRankingRepository(_apiClient);
    _remoteDetailRepository = RemoteCardDetailRepository(_apiClient);
    _catalogSettingsRepository = RemoteCatalogSettingsRepository(_apiClient);
    _notificationRepository = NotificationRepository(_apiClient);
    _notificationService = NotificationService(_notificationRepository);
    _notificationRouteSubscription = _notificationService.routes.listen(
      _openNotificationRoute,
    );
    unawaited(_restoreLocalGuestState());
    unawaited(_loadHomeCardHeightScale());
    unawaited(_loadHomeCardDisplayMode());
    unawaited(_restorePushPreference());
    unawaited(_restoreHapticPreferences());
    unawaited(_authController.initialize());
    unawaited(_proController.initialize());
    unawaited(_proWorkspaceController.initialize());
    if (widget.enableRemoteData) {
      _loadRemoteCatalog();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _marketCardTransitionController
      ..duration = reduceMotion ? Duration.zero : MotionTokens.sharedCard
      ..reverseDuration = reduceMotion
          ? Duration.zero
          : MotionTokens.sharedCardReverse;
  }

  bool get _isPro => widget.proUnlocked || _proController.isActive;

  bool get _marketPreviewActive =>
      _marketCardSourceGeometry != null &&
      _marketTransitionCard?.id == _previewCard?.id;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _proController.billingEnabled &&
        _proController.accountConnected) {
      unawaited(_proController.refreshEntitlement());
    }
  }

  void _handleProChanged() {
    if (!mounted) return;
    if (!_isPro) {
      _proModeRestored = false;
      if (_homeCardDisplayMode.requiresPro) {
        _homeCardDisplayMode = HomeCardDisplayMode.wallet;
      }
      if (_comparisonOpen) {
        _comparisonOpen = false;
        _comparisonInitialCard = null;
        _comparisonInitialCards = null;
        _previewCard = _comparisonReturnCard;
        _comparisonReturnCard = null;
        _comparisonReturnToWorkspace = false;
        _proPageOpen = true;
      }
      _previewReturnToWorkspace = false;
      if (_proWorkspaceOpen) {
        _proWorkspaceOpen = false;
        _proPageOpen = true;
      }
      if (_billAnalysisOpen) {
        _billAnalysisOpen = false;
        _proPageOpen = true;
      }
    } else if (_isPro && !_proModeRestored) {
      unawaited(_loadHomeCardDisplayMode());
    }
    setState(() {});
  }

  void _handleProWorkspaceChanged() {
    if (mounted) setState(() {});
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    if (_authController.isVerified && _authMode != null) {
      _authMode = null;
    }
    if (!_authController.loading && _proController.billingEnabled) {
      unawaited(_proController.refreshEntitlement());
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proUnlocked &&
        !widget.proUnlocked &&
        _homeCardDisplayMode.requiresPro) {
      _homeCardDisplayMode = HomeCardDisplayMode.wallet;
      unawaited(
        SharedPreferences.getInstance().then(
          (preferences) => preferences.setString(
            _homeCardDisplayModeKey,
            HomeCardDisplayMode.wallet.name,
          ),
        ),
      );
    }
  }

  Future<void> _restoreLocalGuestState() async {
    final state = await _localStateRepository.load();
    if (!mounted || state == null) return;
    setState(() {
      _hasPersistedGuestState = true;
      _addedCardIds
        ..clear()
        ..addAll(state.addedCardIds);
      _favoriteCardIds
        ..clear()
        ..addAll(state.favoriteCardIds);
      _favoriteArticleIds
        ..clear()
        ..addAll(state.favoriteArticleIds);
      _recentCardIds
        ..clear()
        ..addAll(state.recentCardIds);
      _submissions
        ..clear()
        ..addAll(state.submissions);
    });
  }

  void _persistLocalGuestState() {
    _hasPersistedGuestState = true;
    unawaited(
      _localStateRepository.save(
        LocalGuestState(
          addedCardIds: _addedCardIds.toList(growable: false),
          favoriteCardIds: _favoriteCardIds.toList(growable: false),
          favoriteArticleIds: _favoriteArticleIds.toList(growable: false),
          recentCardIds: _recentCardIds.toList(growable: false),
          submissions: _submissions.toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _loadHomeCardHeightScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble(_homeCardHeightKey);
    if (!mounted || value == null) return;
    setState(() => _homeCardHeightScale = clampHomeCardHeightScale(value));
  }

  Future<void> _loadHomeCardDisplayMode() async {
    if (!_isPro) return;
    _proModeRestored = true;
    if (_hasHomeCardDisplayModeOverride) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_homeCardDisplayModeKey);
    if (!mounted || !_isPro || saved == null) return;
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
    return HomeCardDisplayMode.wallet;
  }

  Future<void> _restorePushPreference() async {
    final enabled = await _notificationService.isEnabled();
    if (!mounted) return;
    setState(() => _pushEnabled = enabled);
    if (enabled && widget.enableRemoteData) {
      unawaited(_notificationService.start(locale: _notificationLocale));
    }
  }

  Future<void> _restoreHapticPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_hapticsEnabledKey) ?? true;
    final cardSwipeEnabled = preferences.getBool(_cardSwipeHapticsKey) ?? true;
    final savedStrength = preferences.getString(_hapticStrengthKey);
    final strength = AppHapticStrength.values.firstWhere(
      (value) => value.name == savedStrength,
      orElse: () => AppHapticStrength.medium,
    );
    AppHaptics.configure(
      hapticsEnabled: enabled,
      swipeHapticsEnabled: cardSwipeEnabled,
      hapticStrength: strength,
    );
    if (!mounted) return;
    setState(() {
      _hapticsEnabled = enabled;
      _cardSwipeHapticsEnabled = cardSwipeEnabled;
      _hapticStrength = strength;
    });
  }

  void _changeHapticsEnabled(bool enabled) {
    setState(() => _hapticsEnabled = enabled);
    AppHaptics.configure(
      hapticsEnabled: enabled,
      swipeHapticsEnabled: _cardSwipeHapticsEnabled,
      hapticStrength: _hapticStrength,
    );
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setBool(_hapticsEnabledKey, enabled),
      ),
    );
    if (enabled) unawaited(AppHaptics.selection());
  }

  void _changeCardSwipeHapticsEnabled(bool enabled) {
    setState(() => _cardSwipeHapticsEnabled = enabled);
    AppHaptics.configure(
      hapticsEnabled: _hapticsEnabled,
      swipeHapticsEnabled: enabled,
      hapticStrength: _hapticStrength,
    );
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setBool(_cardSwipeHapticsKey, enabled),
      ),
    );
    if (enabled) unawaited(AppHaptics.cardSwipe());
  }

  void _changeHapticStrength(AppHapticStrength strength) {
    setState(() => _hapticStrength = strength);
    AppHaptics.configure(
      hapticsEnabled: _hapticsEnabled,
      swipeHapticsEnabled: _cardSwipeHapticsEnabled,
      hapticStrength: strength,
    );
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) =>
            preferences.setString(_hapticStrengthKey, strength.name),
      ),
    );
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
    if (mode.requiresPro && !_isPro) {
      _openPro();
      return;
    }
    setState(() => _homeCardDisplayMode = mode);
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) =>
            preferences.setString(_homeCardDisplayModeKey, mode.name),
      ),
    );
  }

  void _openPro() {
    AppHaptics.selection();
    setState(() => _proPageOpen = true);
  }

  void _openComparison([CardSummary? initialCard]) {
    _openComparisonCards(initialCard == null ? const [] : [initialCard]);
  }

  void _openComparisonCards(
    List<CardSummary> cards, {
    bool returnToWorkspace = false,
  }) {
    if (!_isPro) {
      _openPro();
      return;
    }
    AppHaptics.selection();
    setState(() {
      _comparisonReturnCard = _previewCard;
      _comparisonInitialCard = cards.firstOrNull ?? _previewCard;
      _comparisonInitialCards = cards.isEmpty
          ? null
          : cards.take(4).toList(growable: false);
      _comparisonReturnToWorkspace = returnToWorkspace;
      _comparisonOpen = true;
      _proPageOpen = false;
      _proWorkspaceOpen = false;
      _previewCard = null;
      _searchMode = null;
      _cardCanvasOpen = false;
    });
  }

  Future<CardDetail> _loadComparisonDetail(CardSummary card) async {
    if (!widget.enableRemoteData) return _detailRepository.detailFor(card);
    try {
      return await _remoteDetailRepository.detailFor(
        card,
        locale: Localizations.localeOf(context),
      );
    } catch (_) {
      return _proWorkspaceController.cachedDetailFor(card.id) ??
          _detailRepository.detailFor(card);
    }
  }

  void _openProWorkspace() {
    if (!_isPro) {
      _openPro();
      return;
    }
    AppHaptics.selection();
    setState(() {
      _proWorkspaceOpen = true;
      _proPageOpen = false;
    });
  }

  void _openBillAnalysis() {
    if (!_isPro) {
      _openPro();
      return;
    }
    AppHaptics.selection();
    setState(() {
      _billAnalysisOpen = true;
      _proWorkspaceOpen = false;
      _proPageOpen = false;
    });
  }

  void _previewProPurchase() {
    unawaited(() async {
      final message = await _proController.purchase();
      if (mounted && message != null) {
        AppNotice.info(context, message, title: 'Pro');
      }
    }());
  }

  void _restoreProPurchase() {
    unawaited(() async {
      final message = await _proController.restore();
      if (mounted && message != null) {
        AppNotice.info(context, message, title: '恢复购买');
      }
    }());
  }

  void _manageProSubscription() {
    unawaited(() async {
      final configuredUrl = ProConfig.manageSubscriptionUrl.trim();
      final fallbackUrl = switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS => 'https://apps.apple.com/account/subscriptions',
        _ => 'https://play.google.com/store/account/subscriptions',
      };
      final uri = Uri.tryParse(
        configuredUrl.isEmpty ? fallbackUrl : configuredUrl,
      );
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          AppNotice.info(context, '暂时无法打开系统订阅管理页。', title: '管理订阅');
        }
      }
    }());
  }

  void _openProDocument(String url, String title) {
    unawaited(() async {
      final uri = Uri.tryParse(url.trim());
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          AppNotice.info(context, '暂时无法打开$title。', title: title);
        }
      }
    }());
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
    _persistLocalGuestState();
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
          if (!_hasPersistedGuestState &&
              _initialMockState != 'empty' &&
              homeIds.isNotEmpty) {
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
      final targetWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(1, 1280);
      for (final card in cards.take(3)) {
        final imageUrl = card.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) continue;
        unawaited(
          precacheImage(
            ResizeImage.resizeIfNeeded(
              targetWidth,
              null,
              CachedNetworkImageProvider(imageUrl),
            ),
            context,
          ).catchError((_) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRouteSubscription?.cancel();
    _notificationService.dispose();
    _authController
      ..removeListener(_handleAuthChanged)
      ..dispose();
    _proController
      ..removeListener(_handleProChanged)
      ..dispose();
    _proWorkspaceController
      ..removeListener(_handleProWorkspaceChanged)
      ..dispose();
    _marketCardTransitionController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _addCard() {
    _selectDestination(4);
  }

  void _openAuth([AuthMode mode = AuthMode.login]) {
    AppHaptics.selection();
    setState(() {
      _authMode = mode;
    });
  }

  void _changeCard(CardSummary card, bool added) {
    if (added && !card.isAddableToCardWallet) {
      AppNotice.info(context, '全球账户仅供资料浏览，不能加入本机卡包。', title: '全球账户');
      return;
    }
    setState(() {
      if (added) {
        _addedCardIds.add(card.id);
      } else {
        _addedCardIds.remove(card.id);
      }
    });
    _persistLocalGuestState();
    AppNotice.success(
      context,
      added ? '已添加到本机卡包。' : '已从本机卡包移除。',
      title: added ? '添加成功' : '已移除',
    );
  }

  void _showSearch(CardSearchMode mode) {
    setState(() {
      _searchMode = mode;
      _previewCard = null;
    });
  }

  void _openCardCanvas() {
    AppHaptics.selection();
    setState(() {
      _cardCanvasOpen = true;
      _searchMode = null;
    });
  }

  void _openCardAdvisor() {
    AppHaptics.selection();
    setState(() {
      _cardAdvisorOpen = true;
      _searchMode = null;
      _cardCanvasOpen = false;
    });
  }

  void _openCard(CardSummary card) {
    _showCard(card);
  }

  void _openMarketCard(CardSummary card, CatalogCardSourceGeometry geometry) {
    if (_previewCard != null || _marketCardTransitionController.isAnimating) {
      return;
    }
    _showCard(card, marketSourceGeometry: geometry);
  }

  void _openHomeCard(CardSummary card, CatalogCardSourceGeometry geometry) {
    if (_previewCard != null || _marketCardTransitionController.isAnimating) {
      return;
    }
    _showCard(card, marketSourceGeometry: geometry, includeSourceTitle: false);
  }

  void _showCard(
    CardSummary card, {
    CatalogCardSourceGeometry? marketSourceGeometry,
    bool includeSourceTitle = true,
  }) {
    _marketCardTransitionController
      ..stop()
      ..value = 0;
    setState(() {
      _previewReturnToWorkspace = false;
      _previewCard = card;
      _marketCardSourceGeometry = marketSourceGeometry;
      _marketTransitionCard = marketSourceGeometry == null ? null : card;
      _transitionIncludesSourceTitle = includeSourceTitle;
      _marketCardClosing = false;
      _recentCardIds
        ..remove(card.id)
        ..insert(0, card.id);
      if (_recentCardIds.length > 8) {
        _recentCardIds.removeRange(8, _recentCardIds.length);
      }
    });
    _persistLocalGuestState();
    if (marketSourceGeometry != null) {
      _marketCardTransitionController.forward();
    }
  }

  void _openCardFromWorkspace(CardSummary card) {
    AppHaptics.selection();
    _clearMarketCardTransition();
    setState(() {
      _proWorkspaceOpen = false;
      _previewReturnToWorkspace = true;
      _previewCard = card;
      _recentCardIds
        ..remove(card.id)
        ..insert(0, card.id);
      if (_recentCardIds.length > 8) {
        _recentCardIds.removeRange(8, _recentCardIds.length);
      }
    });
    _persistLocalGuestState();
  }

  void _clearMarketCardTransition() {
    _marketCardTransitionController
      ..stop()
      ..value = 0;
    _marketCardSourceGeometry = null;
    _marketTransitionCard = null;
    _transitionIncludesSourceTitle = true;
    _marketCardClosing = false;
  }

  void _changeCardFavorite(CardSummary card, bool favorite) {
    setState(() {
      if (favorite) {
        _favoriteCardIds.add(card.id);
      } else {
        _favoriteCardIds.remove(card.id);
      }
    });
    _persistLocalGuestState();
  }

  void _changeArticleFavorite(LocalArticle article, bool favorite) {
    setState(() {
      _knownArticles[article.id] = article;
      if (favorite) {
        _favoriteArticleIds.add(article.id);
      } else {
        _favoriteArticleIds.remove(article.id);
      }
    });
    _persistLocalGuestState();
  }

  void _changeCardWatch(CardSummary card, bool watched) {
    if (!_isPro) {
      _openPro();
      return;
    }
    unawaited(() async {
      await _proWorkspaceController.toggleWatched(card);
      if (!mounted) return;
      if (watched) {
        AppNotice.success(context, '已加入规则变更关注；正式推送接入后会同步提醒。', title: '已关注');
      } else {
        AppNotice.info(context, '已取消这张卡片的规则变更关注。', title: '已取消');
      }
    }());
  }

  void _saveSubmission(LocalSubmissionDraft draft) {
    final submission = LocalSubmission.fromDraft(draft);
    setState(() => _submissions.insert(0, submission));
    _persistLocalGuestState();
  }

  void _deleteSubmission(String id) {
    setState(() => _submissions.removeWhere((item) => item.id == id));
    _persistLocalGuestState();
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
    if (section == ProfileSection.pro) {
      _openPro();
      return;
    }
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
    setState(() => _correctionCard = card);
  }

  void _viewSimilarCards() {
    _clearMarketCardTransition();
    setState(() {
      _index = 1;
      _navigationHidden = false;
      _cardCanvasOpen = false;
      _cardAdvisorOpen = false;
      _proPageOpen = false;
      _proWorkspaceOpen = false;
      _comparisonOpen = false;
      _comparisonInitialCard = null;
      _comparisonInitialCards = null;
      _comparisonReturnCard = null;
      _comparisonReturnToWorkspace = false;
      _previewReturnToWorkspace = false;
      _searchMode = null;
      _previewCard = null;
      _profileSection = null;
      _profileSectionHistory.clear();
      _article = null;
      _correctionCard = null;
    });
  }

  void _closeOverlay() {
    if (_marketPreviewActive &&
        !_proPageOpen &&
        !_proWorkspaceOpen &&
        !_billAnalysisOpen &&
        !_cardAdvisorOpen &&
        !_comparisonOpen &&
        _correctionCard == null &&
        _authMode == null) {
      unawaited(_closeMarketPreview());
      return;
    }
    _closeOverlayImmediately();
  }

  Future<void> _closeMarketPreview() async {
    if (_marketCardClosing) return;
    setState(() => _marketCardClosing = true);
    await _marketCardTransitionController.reverse();
    if (!mounted) return;
    setState(() {
      _previewCard = null;
      _previewReturnToWorkspace = false;
      _marketCardSourceGeometry = null;
      _marketTransitionCard = null;
      _transitionIncludesSourceTitle = true;
      _marketCardClosing = false;
      _preserveNavigationAfterMarketClose = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preserveNavigationAfterMarketClose = false;
    });
  }

  void _closeOverlayImmediately() {
    setState(() {
      if (_authMode != null) {
        _authMode = null;
      } else if (_proPageOpen) {
        _proPageOpen = false;
      } else if (_billAnalysisOpen) {
        _billAnalysisOpen = false;
        _proWorkspaceOpen = _isPro;
      } else if (_cardAdvisorOpen) {
        _cardAdvisorOpen = false;
      } else if (_proWorkspaceOpen) {
        _proWorkspaceOpen = false;
        _proPageOpen = true;
      } else if (_comparisonOpen) {
        _comparisonOpen = false;
        _comparisonInitialCard = null;
        _comparisonInitialCards = null;
        _previewCard = _comparisonReturnCard;
        _comparisonReturnCard = null;
        _proWorkspaceOpen = _comparisonReturnToWorkspace;
        _comparisonReturnToWorkspace = false;
      } else if (_correctionCard != null) {
        _correctionCard = null;
      } else if (_previewCard != null) {
        _previewCard = null;
        _proWorkspaceOpen = _previewReturnToWorkspace && _isPro;
        _previewReturnToWorkspace = false;
        _clearMarketCardTransition();
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
    AppHaptics.selection();
    setState(() {
      _index = index;
      _navigationHidden = false;
      _cardCanvasOpen = false;
      _cardAdvisorOpen = false;
      _proPageOpen = false;
      _proWorkspaceOpen = false;
      _billAnalysisOpen = false;
      _comparisonOpen = false;
      _comparisonInitialCard = null;
      _comparisonInitialCards = null;
      _comparisonReturnCard = null;
      _comparisonReturnToWorkspace = false;
      _previewReturnToWorkspace = false;
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
    final marketPreviewActive = _marketPreviewActive;
    final hasOverlay =
        _cardCanvasOpen ||
        _cardAdvisorOpen ||
        _proPageOpen ||
        _proWorkspaceOpen ||
        _billAnalysisOpen ||
        _comparisonOpen ||
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
                    offstage: hasOverlay && !marketPreviewActive,
                    child: AnimatedBuilder(
                      animation: _marketCardTransitionController,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: marketPreviewActive
                              ? MediaQuery.paddingOf(context).top
                              : 0,
                        ),
                        child: _mainBody(),
                      ),
                      builder: (context, child) {
                        final fade = marketPreviewActive
                            ? const Interval(
                                .12,
                                .56,
                                curve: Curves.easeOutCubic,
                              ).transform(_marketCardTransitionController.value)
                            : 0.0;
                        return Opacity(
                          opacity: 1 - fade,
                          child: IgnorePointer(
                            ignoring: hasOverlay,
                            child: ExcludeSemantics(
                              excluding: hasOverlay,
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration:
                        marketPreviewActive ||
                            MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : MotionTokens.page,
                    reverseDuration:
                        marketPreviewActive ||
                            MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : MotionTokens.pageReverse,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      if (marketPreviewActive) return child;
                      return buildMotionPageTransition(
                        context,
                        animation,
                        child,
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) =>
                        currentChild ?? const SizedBox.shrink(),
                    child: hasOverlay
                        ? _EdgeSwipeBack(
                            key: ValueKey(_overlayIdentity),
                            onBack: _closeOverlay,
                            child: marketPreviewActive
                                ? AnimatedBuilder(
                                    animation: _marketCardTransitionController,
                                    child: _overlayBody()!,
                                    builder: (context, child) {
                                      final interactive =
                                          !_marketCardClosing &&
                                          _marketCardTransitionController
                                                  .value >=
                                              .999;
                                      return IgnorePointer(
                                        ignoring: !interactive,
                                        child: ExcludeSemantics(
                                          excluding: !interactive,
                                          child: child,
                                        ),
                                      );
                                    },
                                  )
                                : _overlayBody()!,
                          )
                        : const SizedBox.shrink(key: ValueKey('main-pages')),
                  ),
                ),
                if ((!hasOverlay || marketPreviewActive) && !_navigationHidden)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: IgnorePointer(
                      ignoring: hasOverlay,
                      child: AnimatedBuilder(
                        animation: _marketCardTransitionController,
                        child: BottomNavigation(
                          selectedIndex: _index,
                          addSelected: _index == 4,
                          onDestinationSelected: _selectDestination,
                          onAdd: _addCard,
                          onAnalyzeBill: _openBillAnalysis,
                        ),
                        builder: (context, child) {
                          if (marketPreviewActive) {
                            final fade = const Interval(
                              0,
                              .38,
                              curve: Curves.easeOut,
                            ).transform(_marketCardTransitionController.value);
                            return Opacity(opacity: 1 - fade, child: child);
                          }
                          if (_preserveNavigationAfterMarketClose) {
                            return child!;
                          }
                          return TweenAnimationBuilder<double>(
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
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                if (marketPreviewActive)
                  if (_marketCardSourceGeometry case final sourceGeometry?)
                    MarketCardTransition(
                      key: const Key('market-card-transition'),
                      card: _marketTransitionCard!,
                      animation: _marketCardTransitionController,
                      sourceRect: sourceGeometry.artworkRect,
                      targetRect: _marketDetailArtworkRect(context),
                      sourceTitleRect: sourceGeometry.titleRect,
                      targetTitleRect: _marketDetailTitleRect(context),
                      animateTitle: _transitionIncludesSourceTitle,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Rect _marketDetailArtworkRect(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 48;
    return Rect.fromLTWH(
      24,
      MediaQuery.paddingOf(context).top + 102,
      width,
      _marketTransitionCard?.isGlobalAccount == true
          ? width / (16 / 9)
          : width / 1.586,
    );
  }

  Rect _marketDetailTitleRect(BuildContext context) {
    final artworkRect = _marketDetailArtworkRect(context);
    return Rect.fromLTWH(
      artworkRect.left,
      artworkRect.bottom +
          (_marketTransitionCard?.isGlobalAccount == true ? 18 : 25),
      artworkRect.width,
      32,
    );
  }

  String get _overlayIdentity {
    if (_billAnalysisOpen) return 'bill-analysis';
    if (_cardAdvisorOpen) return 'card-advisor';
    if (_proWorkspaceOpen) return 'pro-workspace';
    if (_proPageOpen) return 'pro';
    if (_authMode case final mode?) return 'auth-${mode.name}';
    if (_comparisonOpen) {
      return 'comparison-${_comparisonInitialCard?.id ?? 'catalog'}';
    }
    if (_correctionCard case final card?) return 'correction-${card.id}';
    if (_previewCard case final card?) return 'preview-${card.id}';
    if (_article case final article?) return 'article-${article.id}';
    if (_profileSection case final section?) return 'profile-${section.name}';
    if (_searchMode case final mode?) return 'search-${mode.name}';
    if (_cardCanvasOpen) return 'card-canvas';
    return 'main-pages';
  }

  Widget? _overlayBody() {
    if (_billAnalysisOpen) {
      return BillAnalysisPage(
        repository: _billAnalysisRepository,
        enableRemoteData: widget.enableRemoteData,
        onBack: _closeOverlay,
      );
    }
    if (_cardAdvisorOpen) {
      return CardAdvisorPage(
        repository: _cardAdvisorRepository,
        cards: _catalogCards,
        onBack: _closeOverlay,
        onOpenCard: (card) {
          setState(() {
            _cardAdvisorOpen = false;
            _previewCard = card;
          });
        },
        onLoginRequired: () => setState(() {
          _cardAdvisorOpen = false;
          _authMode = AuthMode.login;
        }),
      );
    }
    if (_proWorkspaceOpen) {
      return ProWorkspacePage(
        controller: _proWorkspaceController,
        cards: _catalogCards,
        collectionCards: _cardsForIds(_addedCardIds),
        loadDetail: _loadComparisonDetail,
        onBack: _closeOverlay,
        onOpenCard: _openCardFromWorkspace,
        onOpenComparison: (cards) =>
            _openComparisonCards(cards, returnToWorkspace: true),
        onOpenBillAnalysis: _openBillAnalysis,
      );
    }
    if (_proPageOpen) {
      return ProPage(
        controller: _proController,
        onBack: _closeOverlay,
        onPurchase: _previewProPurchase,
        onRestore: _restoreProPurchase,
        onManageSubscription: _manageProSubscription,
        onOpenWorkspace: _openProWorkspace,
        onOpenComparison: _openComparison,
        onOpenTerms: ProConfig.termsUrl.trim().isEmpty
            ? null
            : () => _openProDocument(ProConfig.termsUrl, '会员服务条款'),
        onOpenPrivacy: ProConfig.privacyUrl.trim().isEmpty
            ? null
            : () => _openProDocument(ProConfig.privacyUrl, '隐私政策'),
      );
    }
    final authMode = _authMode;
    if (authMode != null) {
      return AuthPage(
        controller: _authController,
        mode: authMode,
        onBack: _closeOverlay,
        onModeChanged: (mode) => setState(() => _authMode = mode),
      );
    }
    if (_comparisonOpen) {
      return CardComparisonPage(
        cards: _catalogCards,
        initialCard: _comparisonInitialCard,
        initialCards: _comparisonInitialCards,
        workspaceController: _proWorkspaceController,
        loadDetail: _loadComparisonDetail,
        onBack: _closeOverlay,
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
          onCompare: () => _openComparison(previewCard),
          watched: _proWorkspaceController.isWatched(previewCard.id),
          onWatchChanged: (watched) => _changeCardWatch(previewCard, watched),
          onViewSimilar: _viewSimilarCards,
          entranceAnimation: _marketPreviewActive
              ? _marketCardTransitionController
              : null,
        );
      }
      return FutureBuilder(
        future: _remoteDetailRepository.detailFor(
          previewCard,
          locale: Localizations.localeOf(context),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CardPreviewSkeleton(
              onBack: _closeOverlay,
              globalAccount: previewCard.isGlobalAccount,
              entranceAnimation: _marketPreviewActive
                  ? _marketCardTransitionController
                  : null,
            );
          }
          final cachedDetail = _isPro
              ? _proWorkspaceController.cachedDetailFor(previewCard.id)
              : null;
          final detail =
              snapshot.data ??
              cachedDetail ??
              _detailRepository.detailFor(previewCard);
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
            onCompare: () => _openComparison(previewCard),
            watched: _proWorkspaceController.isWatched(previewCard.id),
            onWatchChanged: (watched) => _changeCardWatch(previewCard, watched),
            onViewSimilar: _viewSimilarCards,
            usingOfflineFallback: snapshot.hasError,
            entranceAnimation: _marketPreviewActive
                ? _marketCardTransitionController
                : null,
            onRetry: snapshot.hasError
                ? () {
                    _remoteDetailRepository.detailFor(
                      previewCard,
                      force: true,
                      locale: Localizations.localeOf(context),
                    );
                    setState(() {});
                  }
                : null,
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
        favoriteCards: _cardsForIds(_favoriteCardIds),
        recentCards: _cardsForIds(_recentCardIds),
        favoriteArticles: _favoriteArticleIds
            .map((id) => _knownArticles[id])
            .whereType<LocalArticle>()
            .toList(growable: false),
        submissions: _submissions,
        appMessages: _appMessages,
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onOpenArticle: _openArticle,
        onOpenSection: _openNestedProfileSection,
        onSubmit: _saveSubmission,
        onDeleteSubmission: _deleteSubmission,
        onRefreshAppMessages: () => _loadAppMessages(rethrowOnError: true),
        onOpenAppMessage: (message) => _openNotificationRoute(message.route),
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        pushEnabled: _pushEnabled,
        onPushEnabledChanged: _changePushEnabled,
        hapticsEnabled: _hapticsEnabled,
        cardSwipeHapticsEnabled: _cardSwipeHapticsEnabled,
        hapticStrength: _hapticStrength,
        onHapticsEnabledChanged: _changeHapticsEnabled,
        onCardSwipeHapticsEnabledChanged: _changeCardSwipeHapticsEnabled,
        onHapticStrengthChanged: _changeHapticStrength,
        profileName: _authController.user?.profileName,
        onProfileNameChanged: _authController.user == null
            ? null
            : _authController.updateDisplayName,
        onLogout: _authController.user == null ? null : _authController.signOut,
        onDeleteAccount: _authController.isVerified
            ? () => _authController.deleteAccount(
                _authAccountRepository.deleteAccount,
              )
            : null,
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
          onOpenCardTransition: _openHomeCard,
          transitioningCardId: _marketPreviewActive
              ? _marketTransitionCard?.id
              : null,
          onCardHeightScaleChanged: _changeHomeCardHeightScale,
          onReorderCards: _reorderHomeCards,
          onDisplayModeChanged: _changeHomeCardDisplayMode,
          isPro: _isPro,
          onOpenPro: _openPro,
          onToggleNavigation: () =>
              setState(() => _navigationHidden = !_navigationHidden),
        ),
        MarketPage(
          repository: _catalogRepository,
          onSearch: () => _showSearch(CardSearchMode.market),
          onCompare: _openComparison,
          onOpenCanvas: _openCardCanvas,
          onOpenAiAdvisor: _openCardAdvisor,
          onOpenCard: _openCard,
          onOpenCardTransition: _openMarketCard,
          transitioningCardId: _marketPreviewActive
              ? _marketTransitionCard?.id
              : null,
        ),
        RankingPage(
          cards: _catalogCards,
          onOpenCard: _openCard,
          onOpenArticle: _openArticle,
          repository: _rankingRepository,
          enableRemoteData: widget.enableRemoteData,
          isPro: _isPro,
          onOpenPro: _openPro,
        ),
        ProfilePage(
          onOpenSection: _openProfileSection,
          onLogin: _openAuth,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          isPro: _isPro,
          authUser: _authController.user,
          cardCount: _addedCardIds.length,
          favoriteCount: _favoriteCardIds.length + _favoriteArticleIds.length,
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

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: MotionTokens.tabSwitch,
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
        : MotionTokens.tabSwitch;
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _visited.add(widget.index);
    _outgoingIndex = oldWidget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = MotionTokens.standardEnter.transform(_controller.value);
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
                        childIndex != widget.index &&
                        childIndex != _outgoingIndex,
                    child: IgnorePointer(
                      ignoring: childIndex != widget.index,
                      child: ExcludeSemantics(
                        excluding: childIndex != widget.index,
                        child: TickerMode(
                          enabled:
                              childIndex == widget.index ||
                              childIndex == _outgoingIndex,
                          child: Opacity(
                            opacity: childIndex == widget.index
                                ? value
                                : 1 - value,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                childIndex == widget.index
                                    ? (1 - value) * MotionTokens.smallOffset
                                    : -value * 4,
                              ),
                              child: Transform.scale(
                                scale: childIndex == widget.index
                                    ? MotionTokens.incomingScale +
                                          (1 - MotionTokens.incomingScale) *
                                              value
                                    : 1 -
                                          (1 - MotionTokens.outgoingScale) *
                                              value,
                                alignment: Alignment.center,
                                child: widget.children[childIndex],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _TestCatalogRepository implements CardCatalogRepository {
  const _TestCatalogRepository();

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async =>
      const <CardSummary>[];
}
