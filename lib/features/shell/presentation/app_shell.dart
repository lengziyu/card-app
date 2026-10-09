import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/config/app_feature_config.dart';
import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/celebration_effects.dart';
import 'package:cardfi/core/motion/edge_swipe_back.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/auth/data/auth_controller.dart';
import 'package:cardfi/features/profile/data/avatar_repository.dart';
import 'package:cardfi/features/auth/data/auth_account_repository.dart';
import 'package:cardfi/features/auth/data/auth_repository.dart';
import 'package:cardfi/features/auth/data/supabase_auth_repository.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/auth/presentation/auth_page.dart';
import 'package:cardfi/features/debug/presentation/motion_lab_page.dart';
import 'package:cardfi/features/add/presentation/add_card_page.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/catalog/data/card_comment_repository.dart';
import 'package:cardfi/features/catalog/data/local_card_details.dart';
import 'package:cardfi/features/catalog/data/remote_card_catalog.dart';
import 'package:cardfi/features/catalog/data/remote_card_details.dart';
import 'package:cardfi/features/catalog/data/remote_global_account_catalog.dart';
import 'package:cardfi/features/catalog/data/remote_catalog_settings.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/presentation/card_correction_page.dart';
import 'package:cardfi/features/catalog/presentation/card_comparison_page.dart';
import 'package:cardfi/features/catalog/presentation/card_preview_page.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/home/presentation/home_page.dart';
import 'package:cardfi/features/home/domain/home_card_layout.dart';
import 'package:cardfi/features/market/presentation/card_canvas_page.dart';
import 'package:cardfi/features/market/presentation/card_advisor_page.dart';
import 'package:cardfi/features/market/presentation/ai_assistant_hub_sheet.dart';
import 'package:cardfi/features/market/presentation/card_application_assistant_page.dart';
import 'package:cardfi/features/market/presentation/card_search_page.dart';
import 'package:cardfi/features/market/presentation/market_page.dart';
import 'package:cardfi/features/market/data/card_advisor_repository.dart';
import 'package:cardfi/features/market/data/card_application_assistant_repository.dart';
import 'package:cardfi/features/market/widgets/market_card_transition.dart';
import 'package:cardfi/features/notifications/data/notification_repository.dart';
import 'package:cardfi/features/notifications/data/notification_service.dart';
import 'package:cardfi/features/notifications/presentation/notification_permission_sheet.dart';
import 'package:cardfi/features/profile/presentation/profile_page.dart';
import 'package:cardfi/features/profile/presentation/profile_subpage.dart';
import 'package:cardfi/features/profile/presentation/app_update_dialog.dart';
import 'package:cardfi/features/profile/data/app_version_repository.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/profile/data/remote_user_data_repository.dart';
import 'package:cardfi/features/referrals/data/pending_referral_store.dart';
import 'package:cardfi/features/referrals/data/referral_repository.dart';
import 'package:cardfi/features/referrals/presentation/referral_page.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/data/bill_analysis_repository.dart';
import 'package:cardfi/features/pro/data/bill_benchmark_repository.dart';
import 'package:cardfi/features/pro/data/bill_history_repository.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:cardfi/features/ledger/data/ledger_repository.dart';
import 'package:cardfi/features/ledger/presentation/ledger_workspace_page.dart';
import 'package:cardfi/features/pro/data/pro_controller.dart';
import 'package:cardfi/features/pro/data/pro_workspace_controller.dart';
import 'package:cardfi/features/pro/presentation/pro_page.dart';
import 'package:cardfi/features/pro/presentation/bill_analysis_page.dart';
import 'package:cardfi/features/pro/presentation/bill_history_page.dart';
import 'package:cardfi/features/pro/presentation/pro_workspace_page.dart';
import 'package:cardfi/features/ranking/domain/local_article.dart';
import 'package:cardfi/features/ranking/data/remote_ranking_repository.dart';
import 'package:cardfi/features/ranking/presentation/article_detail_page.dart';
import 'package:cardfi/features/ranking/presentation/ranking_page.dart';
import 'package:cardfi/features/ranking/presentation/tip_submission_page.dart';
import 'package:cardfi/features/shell/widgets/aurora_background.dart';
import 'package:cardfi/features/shell/widgets/bottom_navigation.dart';
import 'package:cardfi/features/tools/data/tools_repository.dart';
import 'package:cardfi/features/tools/presentation/tools_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.enableRemoteData,
    required this.proUnlocked,
    this.proAccessTokenProvider,
    this.proApplicationUserNameProvider,
    this.authRepository,
    this.catalogRepository,
    this.toolsRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.edgeSwipeBackEnabled = AppFeatureConfig.edgeSwipeBackEnabled,
    super.key,
  });

  final bool enableRemoteData;
  final bool proUnlocked;
  final ProAccessTokenProvider? proAccessTokenProvider;
  final ProApplicationUserNameProvider? proApplicationUserNameProvider;
  final AuthRepository? authRepository;
  final CardCatalogRepository? catalogRepository;
  final ToolsRepository? toolsRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final bool edgeSwipeBackEnabled;

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
  static const _notificationPromptShownKey =
      'notification-permission-explainer-shown-v1';
  static const _optionalUpdateDismissedPrefix =
      'optional-app-update-dismissed-v1';
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
  bool _applicationAssistantOpen = false;
  CardSummary? _applicationAssistantInitialCard;
  CardSummary? _applicationAssistantReturnCard;
  bool _proPageOpen = false;
  bool _proWorkspaceOpen = false;
  bool _billAnalysisOpen = false;
  bool _billAnalysisReturnToWorkspace = false;
  bool _tipSubmissionOpen = false;
  bool _comparisonOpen = false;
  CardSummary? _comparisonInitialCard;
  List<CardSummary>? _comparisonInitialCards;
  CardSummary? _comparisonReturnCard;
  bool _comparisonReturnToWorkspace = false;
  bool _previewReturnToWorkspace = false;
  CardSearchMode? _searchMode;
  AuthMode? _authMode;
  int _authCelebrationVersion = 0;
  CardSummary? _previewCard;
  CatalogCardSourceGeometry? _marketCardSourceGeometry;
  CardSummary? _marketTransitionCard;
  bool _transitionIncludesSourceTitle = true;
  bool _reconstructPreviewOnEntrance = false;
  bool _marketCardClosing = false;
  double _previewScrollOffset = 0;
  double _closingPreviewScrollOffset = 0;
  bool _marketReturnUsesFade = false;
  bool _preserveNavigationAfterMarketClose = false;
  ProfileSection? _profileSection;
  final List<ProfileSection> _profileSectionHistory = [];
  LocalArticle? _article;
  bool _articleReturnToApplicationAssistant = false;
  CardSummary? _correctionCard;
  final Set<String> _favoriteCardIds = <String>{};
  final Set<String> _favoriteArticleIds = <String>{};
  final Map<String, LocalArticle> _knownArticles = {
    for (final article in localArticles) article.id: article,
    for (final article in localCommunityTipArticles) article.id: article,
  };
  final List<String> _recentCardIds = <String>[];
  final List<LocalSubmission> _submissions = [];
  List<AppMessage> _appMessages = const [];
  bool _pushEnabled = false;
  bool _versionDialogVisible = false;
  NotificationPermissionStatus _notificationPermissionStatus =
      NotificationPermissionStatus.unavailable;
  bool _hapticsEnabled = true;
  bool _cardSwipeHapticsEnabled = true;
  AppHapticStrength _hapticStrength = AppHapticStrength.medium;
  bool _proModeRestored = false;
  double _homeCardHeightScale = homeCardStackDefaultScale;
  late HomeCardDisplayMode _homeCardDisplayMode;
  List<CardSummary> _catalogCards = localCardCatalog;
  late final Set<String> _demoCardIds = _initialMockState == 'empty'
      ? <String>{}
      : localCardCatalog
            .where((card) => card.assetPath != null)
            .map((card) => card.id)
            .toSet();
  final Set<String> _addedCardIds = <String>{};

  late final ApiClient _apiClient;
  late final ToolsRepository _toolsRepository;
  final _toolsPageKey = GlobalKey<ToolsPageState>();
  late final CardCatalogRepository _catalogRepository;
  late final RemoteRankingRepository _rankingRepository;
  late final RemoteCardDetailRepository _remoteDetailRepository;
  late final CardCommentRepository _cardCommentRepository;
  late final RemoteCatalogSettingsRepository _catalogSettingsRepository;
  late final AppVersionRepository _appVersionRepository;
  late final NotificationRepository _notificationRepository;
  late final NotificationService _notificationService;
  late final AuthController _authController;
  late final AuthAccountRepository _authAccountRepository;
  late final ProController _proController;
  late final ProWorkspaceController _proWorkspaceController;
  late final BillAnalysisRepository _billAnalysisRepository;
  late final BillBenchmarkRepository _billBenchmarkRepository;
  late final BillHistoryRepository _billHistoryRepository;
  late final ApiClient _ledgerApiClient;
  late final CardAdvisorRepository _cardAdvisorRepository;
  late final CardApplicationAssistantRepository _applicationAssistantRepository;
  late final RemoteUserDataRepository _remoteUserDataRepository;
  late final ReferralRepository _referralRepository;
  final PendingReferralStore _pendingReferralStore = PendingReferralStore();
  bool _referralEnabled = false;
  late final AnimationController _marketCardTransitionController;
  StreamSubscription<String>? _notificationRouteSubscription;
  final LocalGuestStateRepository _localStateRepository =
      LocalGuestStateRepository();
  Future<void> _personalStateWriteQueue = Future.value();
  String? _activePersonalStateUserId;
  String? _remotePersonalDataLoadingUserId;
  int? _remotePersonalDataLoadingGeneration;
  int _personalStateGeneration = 0;
  bool _accountStateInitialized = false;
  String? _reportedAuthClientContextKey;
  String? _reportingAuthClientContextKey;
  Future<PackageInfo>? _packageInfo;
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
    _toolsRepository = widget.toolsRepository ?? ToolsRepository(_apiClient);
    _authController = AuthController(
      widget.authRepository ??
          SupabaseAuthRepository(
            registerAppleAuthorizationCode: (authorizationCode, accessToken) =>
                _authAccountRepository.registerAppleAuthorizationCode(
                  authorizationCode,
                  accessToken,
                ),
            revokeAppleCredential: () =>
                _authAccountRepository.revokeAppleCredential(),
          ),
      avatarRepository: widget.enableRemoteData
          ? AvatarRepository(
              _apiClient,
              accessTokenProvider: () => _authController.idToken(),
            )
          : null,
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
      path: ProConfig.billHistoryEnabled
          ? ProConfig.billAnalysisV2Path
          : ProConfig.billAnalysisPath,
    );
    _billBenchmarkRepository = BillBenchmarkRepository(_apiClient);
    _billHistoryRepository = BillHistoryRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _ledgerApiClient = ApiClient(
      baseUrl: LedgerConfig.baseUrl.isEmpty ? null : LedgerConfig.baseUrl,
    );
    _cardAdvisorRepository = CardAdvisorRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _applicationAssistantRepository = CardApplicationAssistantRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _remoteUserDataRepository = RemoteUserDataRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _referralRepository = ReferralRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _catalogRepository =
        widget.catalogRepository ??
        (!widget.enableRemoteData
            ? const _TestCatalogRepository()
            : RemoteMarketCatalogRepository(
                cards: RemoteCardCatalogRepository(_apiClient),
                globalAccounts: RemoteGlobalAccountCatalogRepository(
                  _apiClient,
                ),
              ));
    _rankingRepository = RemoteRankingRepository(_apiClient);
    _remoteDetailRepository = RemoteCardDetailRepository(_apiClient);
    _cardCommentRepository = CardCommentRepository(
      _apiClient,
      accessTokenProvider: proAccessTokenProvider,
    );
    _catalogSettingsRepository = RemoteCatalogSettingsRepository(_apiClient);
    _appVersionRepository = AppVersionRepository(_apiClient);
    _notificationRepository = NotificationRepository(_apiClient);
    _notificationService = NotificationService(_notificationRepository);
    _notificationRouteSubscription = _notificationService.routes.listen(
      _openNotificationRoute,
    );
    unawaited(_localStateRepository.clearLegacyState());
    unawaited(_loadHomeCardHeightScale());
    unawaited(_loadHomeCardDisplayMode());
    unawaited(_restoreHapticPreferences());
    unawaited(_initializeAccountState());
    if (widget.enableRemoteData && ProConfig.referralProgramEnabled) {
      unawaited(_loadReferralConfiguration());
    }
    if (widget.enableRemoteData) {
      _loadRemoteCatalog();
      unawaited(_initializeStartupPrompts());
    } else {
      unawaited(_initializeNotifications());
    }
  }

  Future<void> _initializeStartupPrompts() async {
    final updatePromptScheduled = await _checkAppVersionOnLaunch();
    if (updatePromptScheduled) {
      await _restorePushPreference();
    } else {
      await _initializeNotifications();
    }
  }

  Future<void> _initializeAccountState() async {
    // Supabase restores (and, after a cold update launch, may refresh) the
    // secure session before any consumer asks for a bearer token.
    await _authController.initialize();
    if (!mounted) return;
    unawaited(_reportAuthClientContext());
    await Future.wait([
      _proController.initialize(),
      _proWorkspaceController.initialize(),
    ]);
    if (!mounted) return;
    _accountStateInitialized = true;
    // Cover a session event that may have arrived while the Pro controller was
    // initializing without issuing a duplicate request on the normal path.
    if (_authController.isVerified && !_proController.accountConnected) {
      unawaited(_proController.refreshEntitlement());
    }
  }

  Future<bool> _checkAppVersionOnLaunch() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final update = await _appVersionRepository.checkInstalledVersion(
        packageInfo,
      );
      if (!mounted || !update.needsUpdate || _versionDialogVisible) {
        return false;
      }
      if (update.status == AppUpdateStatus.optional) {
        final preferences = await SharedPreferences.getInstance();
        if (preferences.getBool(_optionalUpdateDismissalKey(update)) ?? false) {
          return false;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _versionDialogVisible) return;
        _versionDialogVisible = true;
        final dialog = update.requiresUpdate
            ? _showRequiredAppUpdate(update)
            : _showOptionalAppUpdate(update);
        unawaited(
          dialog.whenComplete(() {
            _versionDialogVisible = false;
          }),
        );
      });
      return true;
    } on ApiException {
      // 无网络或服务端未配置版本时，不能阻止用户使用已安装的 App。
      return false;
    } catch (_) {
      // 版本检查是发布后的增强能力，读取失败不影响主流程。
      return false;
    }
  }

  String _optionalUpdateDismissalKey(AppVersionUpdate update) =>
      '$_optionalUpdateDismissedPrefix-'
      '${defaultTargetPlatform.name}-${update.latestVersion}-'
      '${update.latestBuildNumber}';

  Future<void> _showRequiredAppUpdate(AppVersionUpdate update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(
        update: update,
        blocking: true,
        onUpdate: () => _openRequiredUpdateUrl(update.updateUrl),
      ),
    );
  }

  Future<void> _showOptionalAppUpdate(AppVersionUpdate update) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AppUpdateDialog(
        update: update,
        blocking: false,
        onLater: () => Navigator.pop(dialogContext, false),
        onUpdate: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (shouldUpdate == true) {
      _openRequiredUpdateUrl(update.updateUrl);
      return;
    }
    await (await SharedPreferences.getInstance()).setBool(
      _optionalUpdateDismissalKey(update),
      true,
    );
  }

  void _openRequiredUpdateUrl(String value) {
    unawaited(() async {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          AppNotice.error(context, '暂时无法打开应用商店，请稍后重试。', title: '打开失败');
        }
      }
    }());
  }

  Future<bool> _deleteCurrentAccount() async {
    final userId = _activePersonalStateUserId;
    final deleted = await _authController.deleteAccount(() async {
      final token = await _authController.idToken();
      if (userId == null ||
          _authController.user?.id != userId ||
          token == null) {
        throw const ApiException(
          code: 'SESSION_CHANGED',
          message: '账号已切换，请重新操作',
        );
      }
      var ledgerCleared = false;
      if (widget.enableRemoteData) {
        ledgerCleared = await _ledgerRepository(
          userId,
        ).eraseForAccountDeletion();
      }
      if (_authController.user?.id != userId) {
        throw const ApiException(
          code: 'SESSION_CHANGED',
          message: '账号已切换，请重新操作',
        );
      }
      try {
        // Keep the original account's token across the cleanup boundary.
        await _authAccountRepository.deleteAccount(accessToken: token);
      } on ApiException catch (error) {
        if (!ledgerCleared) rethrow;
        throw ApiException(
          code: error.code,
          statusCode: error.statusCode,
          message: '账本数据已清除，但账号删除未完成：${error.message}',
        );
      }
      await _localStateRepository.clear(userId);
    });
    return deleted;
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

  bool get _canManagePersonalData => _authController.isVerified;

  Set<String> get _visibleAddedCardIds =>
      _canManagePersonalData ? _addedCardIds : const <String>{};

  Set<String> get _visibleFavoriteCardIds =>
      _canManagePersonalData ? _favoriteCardIds : const <String>{};

  Set<String> get _visibleFavoriteArticleIds =>
      _canManagePersonalData ? _favoriteArticleIds : const <String>{};

  bool get _canUseHomeCardDisplayModes => _isPro;

  bool get _marketPreviewActive =>
      _marketCardSourceGeometry != null &&
      _marketTransitionCard?.id == _previewCard?.id;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enableRemoteData) {
      unawaited(_restorePushPreference());
    }
    if (state == AppLifecycleState.resumed && _accountStateInitialized) {
      unawaited(_reportAuthClientContext());
      unawaited(_proController.refreshEntitlement());
      final userId = _activePersonalStateUserId;
      if (userId != null && widget.enableRemoteData) {
        unawaited(_loadRemotePersonalData(userId, _personalStateGeneration));
      }
    }
  }

  void _handleProChanged() {
    if (!mounted) return;
    if (!_isPro) {
      _proModeRestored = false;
      if (!_canUseHomeCardDisplayModes && _homeCardDisplayMode.requiresPro) {
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
    } else if (_canUseHomeCardDisplayModes && !_proModeRestored) {
      unawaited(_loadHomeCardDisplayMode());
    }
    setState(() {});
  }

  void _handleProWorkspaceChanged() {
    if (mounted) setState(() {});
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    if (_authController.passwordRecoveryPending) {
      _authMode = AuthMode.passwordRecovery;
    } else if (_authController.isVerified && _authMode != null) {
      final completedPasswordRecovery = _authMode == AuthMode.passwordRecovery;
      _authMode = null;
      if (completedPasswordRecovery) {
        _index = 3;
        _profileSection = null;
        _profileSectionHistory.clear();
      } else {
        _authCelebrationVersion++;
      }
    }
    if (_accountStateInitialized && !_authController.loading) {
      unawaited(_reportAuthClientContext());
      unawaited(_proController.refreshEntitlement());
    }
    if (_authController.isVerified && _referralEnabled) {
      unawaited(_bindPendingReferralCode());
    }
    final userId = _authController.isVerified ? _authController.user?.id : null;
    if (userId != _activePersonalStateUserId) {
      _switchPersonalStateUser(userId);
    }
    setState(() {});
  }

  String? get _clientPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };

  Future<void> _reportAuthClientContext() async {
    final user = _authController.user;
    final platform = _clientPlatform;
    if (!_authController.isVerified ||
        _authController.loading ||
        user == null ||
        platform == null) {
      return;
    }
    final authMethod =
        _authController.lastSuccessfulAuthMethod ?? 'session_restore';
    final isRegistration =
        authMethod != 'session_restore' && user.appearsRecentlyRegistered();
    try {
      final packageInfo = await (_packageInfo ??= PackageInfo.fromPlatform());
      if (!mounted || _authController.user?.id != user.id) return;
      final key = [
        user.id,
        platform,
        authMethod,
        isRegistration,
        packageInfo.version,
        packageInfo.buildNumber,
      ].join(':');
      if (_reportedAuthClientContextKey == key ||
          _reportingAuthClientContextKey == key) {
        return;
      }
      _reportingAuthClientContextKey = key;
      await _authAccountRepository.reportClientContext(
        platform: platform,
        authMethod: authMethod,
        isRegistration: isRegistration,
        appVersion: packageInfo.version,
        appBuildNumber: packageInfo.buildNumber,
      );
      if (mounted && _authController.user?.id == user.id) {
        _reportedAuthClientContextKey = key;
      }
      if (_reportingAuthClientContextKey == key) {
        _reportingAuthClientContextKey = null;
      }
    } catch (_) {
      // This metadata is best effort. An old server or a temporary network
      // failure must never block session restore or a successful login.
      _reportingAuthClientContextKey = null;
    }
  }

  Future<void> _loadReferralConfiguration() async {
    if (!ProConfig.referralProgramEnabled) return;
    try {
      final configuration = await _referralRepository.loadConfiguration();
      if (!mounted) return;
      setState(() => _referralEnabled = configuration.enabled);
      if (configuration.enabled && _authController.isVerified) {
        unawaited(_bindPendingReferralCode());
      }
    } on ApiException {
      // Fail closed: referral UI is never shown without an explicit server flag.
    }
  }

  Future<void> _savePendingReferralCode(String code) async {
    await _pendingReferralStore.save(code);
  }

  Future<void> _bindPendingReferralCode() async {
    final code = await _pendingReferralStore.read();
    if (code == null || !_authController.isVerified) return;
    try {
      await _referralRepository.bind(code);
      final profile = await _referralRepository.activate();
      // Keep retrying on later verified sign-ins until the server confirms the
      // account has met the activity and anti-abuse requirements.
      if (profile.activated) await _pendingReferralStore.clear();
    } on ApiException catch (error) {
      if (error.code == 'REFERRAL_CODE_ALREADY_BOUND' ||
          error.code == 'REFERRAL_PROGRAM_DISABLED') {
        await _pendingReferralStore.clear();
      }
    }
  }

  List<CardSummary> get _uCardsForCelebration {
    final uCards = _catalogCards
        .where((card) => card.category == CardCategory.uCard)
        .take(20)
        .toList(growable: false);
    if (uCards.isEmpty) return const <CardSummary>[];
    // The bundled development directory includes fewer than twenty U cards.
    // Repeat only in that fallback so production always uses its first 20.
    return List<CardSummary>.generate(
      20,
      (index) => uCards[index % uCards.length],
      growable: false,
    );
  }

  void _clearAuthCelebration() {
    if (!mounted || _authCelebrationVersion == 0) return;
    setState(() => _authCelebrationVersion = 0);
  }

  void _switchPersonalStateUser(String? userId) {
    _personalStateGeneration++;
    final generation = _personalStateGeneration;
    _activePersonalStateUserId = userId;
    _remotePersonalDataLoadingUserId = null;
    _remotePersonalDataLoadingGeneration = null;
    _clearPersonalState();
    if (userId != null) {
      unawaited(_restorePersonalState(userId, generation));
    }
  }

  void _clearPersonalState() {
    _addedCardIds.clear();
    _favoriteCardIds.clear();
    _favoriteArticleIds.clear();
    _recentCardIds.clear();
    _submissions.clear();
  }

  bool _isCurrentPersonalState(String userId, int generation) {
    return mounted &&
        _activePersonalStateUserId == userId &&
        _personalStateGeneration == generation &&
        _authController.isVerified &&
        _authController.user?.id == userId;
  }

  Future<void> _restorePersonalState(String userId, int generation) async {
    final state = await _localStateRepository.load(userId);
    if (!_isCurrentPersonalState(userId, generation)) return;
    if (state != null) {
      setState(() => _replacePersonalState(state));
    }
    if (widget.enableRemoteData) {
      await _loadRemotePersonalData(userId, generation);
    }
  }

  void _replacePersonalState(LocalGuestState state) {
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
  }

  Future<T?> _loadPersonalPart<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException {
      return null;
    }
  }

  Future<void> _loadRemotePersonalData(String userId, int generation) async {
    if (!_isCurrentPersonalState(userId, generation) ||
        (_remotePersonalDataLoadingUserId == userId &&
            _remotePersonalDataLoadingGeneration == generation)) {
      return;
    }
    _remotePersonalDataLoadingUserId = userId;
    _remotePersonalDataLoadingGeneration = generation;
    try {
      final accessToken = await _authController.idToken();
      if (!_isCurrentPersonalState(userId, generation) ||
          accessToken == null ||
          accessToken.trim().isEmpty) {
        return;
      }
      final results = await Future.wait<Object?>([
        _loadPersonalPart(
          () =>
              _remoteUserDataRepository.loadCardState(accessToken: accessToken),
        ),
        _loadPersonalPart(
          () => _remoteUserDataRepository.loadArticleFavorites(
            accessToken: accessToken,
          ),
        ),
        _loadPersonalPart(
          () => _remoteUserDataRepository.loadSubmissions(
            accessToken: accessToken,
          ),
        ),
      ]);
      if (!_isCurrentPersonalState(userId, generation)) return;
      final cardState = results[0] as RemoteUserCardState?;
      final articleFavorites = results[1] as List<String>?;
      final submissions = results[2] as List<LocalSubmission>?;
      if (cardState == null &&
          articleFavorites == null &&
          submissions == null) {
        return;
      }
      setState(() {
        if (cardState != null) {
          _addedCardIds
            ..clear()
            ..addAll(cardState.addedCardIds);
          _favoriteCardIds
            ..clear()
            ..addAll(cardState.favoriteCardIds);
          _recentCardIds
            ..clear()
            ..addAll(cardState.recentCardIds);
        }
        if (articleFavorites != null) {
          _favoriteArticleIds
            ..clear()
            ..addAll(articleFavorites);
        }
        if (submissions != null) {
          _submissions
            ..clear()
            ..addAll(submissions);
        }
      });
      _persistLocalGuestState();
    } finally {
      if (_remotePersonalDataLoadingUserId == userId &&
          _remotePersonalDataLoadingGeneration == generation) {
        _remotePersonalDataLoadingUserId = null;
        _remotePersonalDataLoadingGeneration = null;
      }
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proUnlocked &&
        !widget.proUnlocked &&
        !_canUseHomeCardDisplayModes &&
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

  void _persistLocalGuestState() {
    final userId = _activePersonalStateUserId;
    if (userId == null || _authController.user?.id != userId) return;
    unawaited(
      _localStateRepository.save(
        userId,
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

  void _scheduleRemotePersonalStateSync() {
    final userId = _activePersonalStateUserId;
    if (!_canManagePersonalData || !widget.enableRemoteData || userId == null) {
      return;
    }
    final generation = _personalStateGeneration;
    final nextCardState = RemoteUserCardState(
      addedCardIds: _addedCardIds.toList(growable: false),
      favoriteCardIds: _favoriteCardIds.toList(growable: false),
      recentCardIds: _recentCardIds.toList(growable: false),
    );
    final articleFavorites = _favoriteArticleIds.toList(growable: false);
    _personalStateWriteQueue = _personalStateWriteQueue.catchError((_) {}).then(
      (_) async {
        if (!_isCurrentPersonalState(userId, generation)) return;
        final accessToken = await _authController.idToken();
        if (!_isCurrentPersonalState(userId, generation) ||
            accessToken == null ||
            accessToken.trim().isEmpty) {
          return;
        }
        await Future.wait([
          _remoteUserDataRepository.saveCardState(
            nextCardState,
            accessToken: accessToken,
          ),
          _remoteUserDataRepository.saveArticleFavorites(
            articleFavorites,
            accessToken: accessToken,
          ),
        ]);
      },
    );
    unawaited(_personalStateWriteQueue.catchError((_) {}));
  }

  Future<void> _loadHomeCardHeightScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble(_homeCardHeightKey);
    if (!mounted || value == null) return;
    setState(() => _homeCardHeightScale = clampHomeCardHeightScale(value));
  }

  Future<void> _loadHomeCardDisplayMode() async {
    if (!_canUseHomeCardDisplayModes) return;
    _proModeRestored = true;
    if (_hasHomeCardDisplayModeOverride) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_homeCardDisplayModeKey);
    if (!mounted || !_canUseHomeCardDisplayModes || saved == null) return;
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

  Future<void> _initializeNotifications() async {
    await _restorePushPreference();
    await _maybeShowNotificationPermissionPrompt();
  }

  Future<void> _restorePushPreference() async {
    final status = await _notificationService.status();
    if (!mounted) return;
    setState(() {
      _pushEnabled = status.canDeliver;
      _notificationPermissionStatus = status.permission;
    });
    if (status.canDeliver && widget.enableRemoteData) {
      unawaited(_notificationService.start(locale: _notificationLocale));
    }
  }

  Future<void> _maybeShowNotificationPermissionPrompt() async {
    if (!widget.enableRemoteData ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_notificationPromptShownKey) ?? false) return;
    final status = await _notificationService.status();
    if (status.permission == NotificationPermissionStatus.unavailable) return;
    if (status.permission != NotificationPermissionStatus.notDetermined) {
      await preferences.setBool(_notificationPromptShownKey, true);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || Navigator.of(context).canPop()) return;
    await preferences.setBool(_notificationPromptShownKey, true);
    if (!mounted) return;
    final accepted = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const NotificationPermissionSheet(),
    );
    if (accepted == true && mounted) await _changePushEnabled(true);
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

  Future<void> _loadRemoteSubmissions({bool rethrowOnError = false}) async {
    final userId = _activePersonalStateUserId;
    final generation = _personalStateGeneration;
    if (!widget.enableRemoteData ||
        userId == null ||
        !_isCurrentPersonalState(userId, generation)) {
      return;
    }
    try {
      final accessToken = await _authController.idToken();
      if (!_isCurrentPersonalState(userId, generation) ||
          accessToken == null ||
          accessToken.trim().isEmpty) {
        return;
      }
      final submissions = await _remoteUserDataRepository.loadSubmissions(
        accessToken: accessToken,
      );
      if (!_isCurrentPersonalState(userId, generation)) return;
      setState(() {
        _submissions
          ..clear()
          ..addAll(submissions);
      });
      _persistLocalGuestState();
    } catch (error, stackTrace) {
      if (rethrowOnError) Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _refreshNotificationCenter() async {
    await Future.wait([
      _loadAppMessages(rethrowOnError: true),
      _loadRemoteSubmissions(rethrowOnError: true),
    ]);
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
      if (mounted) await _restorePushPreference();
      return;
    }
    final currentStatus = await _notificationService.status();
    if (!mounted) return;
    if (currentStatus.permission == NotificationPermissionStatus.denied) {
      await _showOpenNotificationSettingsDialog();
      return;
    }
    final result = await _notificationService.enable(
      locale: _notificationLocale,
    );
    if (!mounted) return;
    switch (result) {
      case NotificationEnableResult.enabled:
        await _restorePushPreference();
        if (!mounted) return;
        AppNotice.success(context, '资讯和新卡上线时会提醒你。', title: '通知已开启');
      case NotificationEnableResult.denied:
        await _restorePushPreference();
        if (!mounted) return;
        AppNotice.info(context, '你可以在系统设置中允许“CardFi”发送通知。', title: '通知权限未开启');
      case NotificationEnableResult.unavailable:
        await _restorePushPreference();
        if (!mounted) return;
        AppNotice.warning(context, '通知服务尚未配置或当前网络不可用。', title: '暂时无法开启');
    }
  }

  Future<void> _showOpenNotificationSettingsDialog() async {
    final localizations = AppLocalizations.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.text('通知权限已关闭')),
        content: Text(
          localizations.text('请前往系统设置允许 CardFi 发送通知，返回 App 后状态会自动更新。'),
        ),
        actions: [
          TextButton(
            key: const Key('notification-settings-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localizations.text('取消')),
          ),
          FilledButton(
            key: const Key('notification-settings-open'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(localizations.text('前往系统设置')),
          ),
        ],
      ),
    );
    if (open != true || !mounted) return;
    final opened = await _notificationService.openSystemSettings();
    if (!opened && mounted) {
      AppNotice.warning(context, '暂时无法打开系统设置，请手动前往通知设置。', title: '打开失败');
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
          final article = await _rankingRepository.loadArticle(
            slug,
            locale: Localizations.localeOf(context),
          );
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
    if (mode.requiresPro && !_canUseHomeCardDisplayModes) {
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
    if (_accountStateInitialized) {
      unawaited(_proController.refreshEntitlement());
    }
  }

  void _openComparison([CardSummary? initialCard]) {
    _openComparisonCards(initialCard == null ? const [] : [initialCard]);
  }

  void _openComparisonCards(
    List<CardSummary> cards, {
    bool returnToWorkspace = false,
  }) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    final comparableCards = cards
        .where((card) => !card.isGlobalAccount)
        .toList(growable: false);
    AppHaptics.selection();
    setState(() {
      _comparisonReturnCard = _previewCard;
      _comparisonInitialCard = comparableCards.firstOrNull;
      _comparisonInitialCards = comparableCards.isEmpty
          ? null
          : comparableCards.take(_isPro ? 4 : 2).toList(growable: false);
      _comparisonReturnToWorkspace = returnToWorkspace;
      _comparisonOpen = true;
      _proPageOpen = false;
      _proWorkspaceOpen = false;
      _tipSubmissionOpen = false;
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
    AppHaptics.selection();
    setState(() {
      _proWorkspaceOpen = true;
      _proPageOpen = false;
    });
  }

  void _openBillAnalysis() {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    setState(() {
      _billAnalysisReturnToWorkspace = _proWorkspaceOpen;
      _billAnalysisOpen = true;
      _proWorkspaceOpen = false;
      _proPageOpen = false;
    });
  }

  void _openBillHistory() {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    final owner = _activePersonalStateUserId;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: MotionTokens.page,
        reverseTransitionDuration: MotionTokens.pageReverse,
        pageBuilder: (routeContext, _, _) => EdgeSwipeBack(
          enabled: widget.edgeSwipeBackEnabled,
          onBack: () => Navigator.of(routeContext).pop(),
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: BillHistoryPage(
              repository: _billHistoryRepository,
              benchmarkRepository: _billBenchmarkRepository,
              cards: _catalogCards,
              onOpenLedger: LedgerConfig.enabled
                  ? () => _openLedger(expectedSubject: owner)
                  : null,
              onAddToLedger: LedgerConfig.enabled
                  ? (bill) => _openLedger(bill: bill, expectedSubject: owner)
                  : null,
              onBack: () => Navigator.of(routeContext).pop(),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, _, child) =>
            buildMotionPageTransition(context, animation, child),
      ),
    );
  }

  LedgerRepository _ledgerRepository(String subject) => LedgerRepository(
    _ledgerApiClient,
    subject: subject,
    currentSubject: () =>
        _authController.isVerified ? _authController.user?.id : null,
    accessToken: _authController.idToken,
  );

  void _openLedger({
    CardSummary? product,
    BillRecord? bill,
    String? expectedSubject,
  }) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    final subject = _activePersonalStateUserId;
    if (subject == null ||
        expectedSubject != null && expectedSubject != subject) {
      return;
    }
    Navigator.of(context).push<void>(
      ledgerRoute(
        context,
        LedgerWorkspacePage(
          repository: _ledgerRepository(subject),
          catalog: _catalogCards,
          initialProduct: product,
          importBill: bill,
          sessionChanges: _authController,
          sessionValid: () =>
              _authController.isVerified && _authController.user?.id == subject,
          onBack: () => Navigator.of(context).pop(),
          onAnalyze: () {
            Navigator.of(context).pop();
            // Close any legacy history/detail routes above the shell first.
            Navigator.of(context).popUntil((route) => route.isFirst);
            _openBillAnalysis();
          },
        ),
      ),
    );
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
    final targetIds = _canManagePersonalData ? _addedCardIds : _demoCardIds;
    final currentIds = targetIds.toSet();
    final nextIds = [
      ...orderedIds.where(currentIds.contains),
      ...targetIds.where((id) => !orderedIds.contains(id)),
    ];
    if (nextIds.length != targetIds.length) return;
    setState(() {
      targetIds
        ..clear()
        ..addAll(nextIds);
    });
    if (_canManagePersonalData) _persistLocalGuestState();
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
      final nonGlobalAccounts =
          cards.where((card) => !card.isGlobalAccount).toList(growable: false)
            ..sort((left, right) {
              final leftOrder = orderById[left.id];
              final rightOrder = orderById[right.id];
              if (leftOrder == null && rightOrder == null) return 0;
              if (leftOrder == null) return 1;
              if (rightOrder == null) return -1;
              return leftOrder.compareTo(rightOrder);
            });
      // Global accounts are curated through their own H5 directory. Do not
      // run them through the card-only market ordering, which would otherwise
      // make the app's sort unstable and discard the configured account order.
      final sortedCards = [
        ...nonGlobalAccounts,
        ...cards.where((card) => card.isGlobalAccount),
      ];
      if (mounted) {
        setState(() {
          _catalogCards = sortedCards;
          if (_initialMockState != 'empty' && homeIds.isNotEmpty) {
            _demoCardIds
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
    _billBenchmarkRepository.dispose();
    _ledgerApiClient.close();
    _apiClient.close();
    super.dispose();
  }

  void _addCard() {
    _selectDestination(4);
  }

  void _openAuth([AuthMode mode = AuthMode.login]) {
    AppHaptics.selection();
    _authController.clearMessage();
    setState(() {
      _authMode = mode;
    });
  }

  Future<void> _logoutFromSettings() async {
    await _authController.signOut();
    if (!mounted) return;
    setState(() {
      _profileSectionHistory.clear();
      _profileSection = null;
    });
    AppNotice.success(context, '已退出账号。', title: '退出登录');
  }

  void _openTipSubmission() {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    setState(() => _tipSubmissionOpen = true);
  }

  void _openTipContributions() {
    setState(() {
      _tipSubmissionOpen = false;
      _profileSectionHistory.clear();
      _profileSection = ProfileSection.notifications;
    });
    unawaited(_refreshNotificationCenter().catchError((_) {}));
  }

  void _openArticleCorrection() {
    if (!_canManagePersonalData) {
      setState(() => _article = null);
      _openAuth();
      return;
    }
    setState(() {
      _article = null;
      _profileSectionHistory.clear();
      _profileSection = ProfileSection.feedback;
    });
  }

  void _changeCard(CardSummary card, bool added) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    if (added && !card.isAddableToCardWallet) {
      AppNotice.info(context, '全球账户用于比较币种与账户能力，不加入“我的卡片”。', title: '全球账户');
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
    _scheduleRemotePersonalStateSync();
    AppNotice.success(
      context,
      added ? '已加入我的卡片。' : '已从我的卡片移除。',
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

  Future<void> _openAiAssistantHub() async {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    final mode = await showAppBottomSheet<AiAssistantMode>(
      context: context,
      builder: (sheetContext) => const AiAssistantHubSheet(),
    );
    if (!mounted || mode == null) return;
    switch (mode) {
      case AiAssistantMode.cardMatch:
        _openCardAdvisor();
      case AiAssistantMode.applicationPrep:
        _openApplicationAssistant();
    }
  }

  void _openCardAdvisor() {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    setState(() {
      _cardAdvisorOpen = true;
      _applicationAssistantOpen = false;
      _applicationAssistantInitialCard = null;
      _applicationAssistantReturnCard = null;
      _searchMode = null;
      _cardCanvasOpen = false;
    });
  }

  void _openApplicationAssistant([CardSummary? initialCard]) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    AppHaptics.selection();
    _clearMarketCardTransition();
    setState(() {
      _applicationAssistantReturnCard = _previewCard;
      _applicationAssistantInitialCard = initialCard;
      _applicationAssistantOpen = true;
      _cardAdvisorOpen = false;
      _previewCard = null;
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
    _showCard(
      card,
      marketSourceGeometry: geometry,
      includeSourceTitle: false,
      reconstructOnEntrance: true,
    );
  }

  void _showCard(
    CardSummary card, {
    CatalogCardSourceGeometry? marketSourceGeometry,
    bool includeSourceTitle = true,
    bool reconstructOnEntrance = false,
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
      _reconstructPreviewOnEntrance = reconstructOnEntrance;
      _marketCardClosing = false;
      _previewScrollOffset = 0;
      _closingPreviewScrollOffset = 0;
      _marketReturnUsesFade = false;
      if (_canManagePersonalData) {
        _recentCardIds
          ..remove(card.id)
          ..insert(0, card.id);
        if (_recentCardIds.length > 8) {
          _recentCardIds.removeRange(8, _recentCardIds.length);
        }
      }
    });
    if (_canManagePersonalData) _persistLocalGuestState();
    if (_canManagePersonalData) _scheduleRemotePersonalStateSync();
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
      if (_canManagePersonalData) {
        _recentCardIds
          ..remove(card.id)
          ..insert(0, card.id);
        if (_recentCardIds.length > 8) {
          _recentCardIds.removeRange(8, _recentCardIds.length);
        }
      }
    });
    if (_canManagePersonalData) _persistLocalGuestState();
    if (_canManagePersonalData) _scheduleRemotePersonalStateSync();
  }

  void _clearMarketCardTransition() {
    _marketCardTransitionController
      ..stop()
      ..value = 0;
    _marketCardSourceGeometry = null;
    _marketTransitionCard = null;
    _transitionIncludesSourceTitle = true;
    _reconstructPreviewOnEntrance = false;
    _marketCardClosing = false;
    _previewScrollOffset = 0;
    _closingPreviewScrollOffset = 0;
    _marketReturnUsesFade = false;
  }

  void _changeCardFavorite(CardSummary card, bool favorite) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    setState(() {
      if (favorite) {
        _favoriteCardIds.add(card.id);
      } else {
        _favoriteCardIds.remove(card.id);
      }
    });
    _persistLocalGuestState();
    _scheduleRemotePersonalStateSync();
  }

  void _changeArticleFavorite(LocalArticle article, bool favorite) {
    if (!_canManagePersonalData) {
      _openAuth();
      return;
    }
    setState(() {
      _knownArticles[article.id] = article;
      if (favorite) {
        _favoriteArticleIds.add(article.id);
      } else {
        _favoriteArticleIds.remove(article.id);
      }
    });
    _persistLocalGuestState();
    _scheduleRemotePersonalStateSync();
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

  Future<void> _saveSubmission(LocalSubmissionDraft draft) async {
    if (!_canManagePersonalData) {
      _openAuth();
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录并完成邮箱验证后再提交。',
      );
    }
    if (!widget.enableRemoteData) {
      throw const ApiException(
        code: 'SERVICE_UNAVAILABLE',
        message: '连接正式服务后才能提交反馈。',
      );
    }
    final userId = _activePersonalStateUserId;
    final generation = _personalStateGeneration;
    if (userId == null || !_isCurrentPersonalState(userId, generation)) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '登录状态已变化，请重新提交。');
    }
    final accessToken = await _authController.idToken();
    if (!_isCurrentPersonalState(userId, generation) ||
        accessToken == null ||
        accessToken.trim().isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '登录状态已变化，请重新提交。');
    }
    final submission = await _remoteUserDataRepository.createSubmission(
      draft,
      accessToken: accessToken,
    );
    if (!_isCurrentPersonalState(userId, generation)) return;
    setState(() {
      _submissions.removeWhere((item) => item.id == submission.id);
      _submissions.insert(0, submission);
    });
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
      final detail = await _rankingRepository.loadArticle(
        article.id,
        locale: Localizations.localeOf(context),
      );
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

  Future<void> _openArticleBySlug(String slug) async {
    void prepareApplicationReturn() {
      if (!_applicationAssistantOpen) return;
      setState(() {
        _applicationAssistantOpen = false;
        _articleReturnToApplicationAssistant = true;
      });
    }

    for (final article in _knownArticles.values) {
      if (article.id == slug) {
        prepareApplicationReturn();
        await _openArticle(article);
        return;
      }
    }
    if (widget.enableRemoteData) {
      try {
        final detail = await _rankingRepository.loadArticle(
          slug,
          locale: Localizations.localeOf(context),
        );
        if (!mounted) return;
        _knownArticles[detail.article.id] = detail.article;
        prepareApplicationReturn();
        await _openArticle(detail.article);
        return;
      } catch (_) {
        // Show the normal unavailable notice below.
      }
    }
    if (!mounted) return;
    AppNotice.info(context, '该项目文章暂时不可用。', title: '资料来源');
  }

  void _openProfileSection(ProfileSection section) {
    if (section == ProfileSection.pro) {
      _openPro();
      return;
    }
    if (section == ProfileSection.bills) {
      _openBillHistory();
      return;
    }
    setState(() {
      _profileSectionHistory.clear();
      _profileSection = section;
    });
    if (section == ProfileSection.notifications) {
      unawaited(_refreshNotificationCenter().catchError((_) {}));
    }
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
    if (section == ProfileSection.notifications) {
      unawaited(_refreshNotificationCenter().catchError((_) {}));
    }
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
      _applicationAssistantOpen = false;
      _applicationAssistantInitialCard = null;
      _applicationAssistantReturnCard = null;
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
      _articleReturnToApplicationAssistant = false;
      _correctionCard = null;
    });
  }

  void _closeOverlay() {
    if (_profileSection == ProfileSection.tools &&
        _previewCard == null &&
        _article == null &&
        _authMode == null &&
        _toolsPageKey.currentState?.handleBack() == true) {
      return;
    }
    if (_authMode == AuthMode.passwordRecovery) {
      unawaited(_cancelPasswordRecoveryAndClose());
      return;
    }
    if (_marketPreviewActive &&
        !_proPageOpen &&
        !_proWorkspaceOpen &&
        !_billAnalysisOpen &&
        !_cardAdvisorOpen &&
        !_applicationAssistantOpen &&
        !_comparisonOpen &&
        _correctionCard == null &&
        _authMode == null) {
      unawaited(_closeMarketPreview());
      return;
    }
    _closeOverlayImmediately();
  }

  void _clearPasswordRecoveryOverlay() {
    if (!mounted || _authMode != AuthMode.passwordRecovery) return;
    _authController.clearMessage();
    setState(() {
      _authMode = null;
      _index = 3;
      _profileSection = null;
      _profileSectionHistory.clear();
    });
  }

  Future<void> _cancelPasswordRecoveryAndClose() async {
    await _authController.cancelPasswordRecovery();
    _clearPasswordRecoveryOverlay();
  }

  Future<void> _closeMarketPreview() async {
    if (_marketCardClosing) return;
    setState(() {
      _marketCardClosing = true;
      _closingPreviewScrollOffset = _previewScrollOffset;
      // Once the card has scrolled under the fixed header, fade the current
      // reading position back to the retained list instead of inventing a
      // full card at its original, now invisible, detail position.
      _marketReturnUsesFade = _previewScrollOffset > 20;
    });
    await _marketCardTransitionController.reverse();
    if (!mounted) return;
    setState(() {
      _previewCard = null;
      _previewReturnToWorkspace = false;
      _marketCardSourceGeometry = null;
      _marketTransitionCard = null;
      _transitionIncludesSourceTitle = true;
      _reconstructPreviewOnEntrance = false;
      _marketCardClosing = false;
      _previewScrollOffset = 0;
      _closingPreviewScrollOffset = 0;
      _marketReturnUsesFade = false;
      _preserveNavigationAfterMarketClose = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preserveNavigationAfterMarketClose = false;
    });
  }

  void _closeOverlayImmediately() {
    final closingAuth = _authMode != null;
    if (closingAuth) _authController.clearMessage();
    setState(() {
      if (_authMode != null) {
        _authMode = null;
      } else if (_proPageOpen) {
        _proPageOpen = false;
      } else if (_billAnalysisOpen) {
        _billAnalysisOpen = false;
        _proWorkspaceOpen = _billAnalysisReturnToWorkspace && _isPro;
        _billAnalysisReturnToWorkspace = false;
      } else if (_tipSubmissionOpen) {
        _tipSubmissionOpen = false;
      } else if (_previewCard != null) {
        _previewCard = null;
        _proWorkspaceOpen = _previewReturnToWorkspace && _isPro;
        _previewReturnToWorkspace = false;
        _clearMarketCardTransition();
      } else if (_cardAdvisorOpen) {
        _cardAdvisorOpen = false;
      } else if (_applicationAssistantOpen) {
        _applicationAssistantOpen = false;
        _previewCard = _applicationAssistantReturnCard;
        _applicationAssistantInitialCard = null;
        _applicationAssistantReturnCard = null;
        _articleReturnToApplicationAssistant = false;
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
      } else if (_article != null) {
        _article = null;
        if (_articleReturnToApplicationAssistant) {
          _articleReturnToApplicationAssistant = false;
          _applicationAssistantOpen = true;
        }
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
      _applicationAssistantOpen = false;
      _applicationAssistantInitialCard = null;
      _applicationAssistantReturnCard = null;
      _proPageOpen = false;
      _proWorkspaceOpen = false;
      _billAnalysisOpen = false;
      _billAnalysisReturnToWorkspace = false;
      _tipSubmissionOpen = false;
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
      _articleReturnToApplicationAssistant = false;
      _correctionCard = null;
      _authMode = null;
    });
  }

  void _toggleNavigationForScreenshot() {
    final hidden = !_navigationHidden;
    setState(() => _navigationHidden = hidden);
    final message = hidden ? '底部导航已隐藏，再次点击当前分栏恢复。' : '底部导航已恢复。';

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('navigation-visibility-hint'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: hidden ? 2400 : 1500),
          margin: EdgeInsets.fromLTRB(20, 0, 20, hidden ? 16 : 88),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          elevation: 0,
          backgroundColor: AppColors.isDark
              ? const Color(0xF02A3048)
              : const Color(0xF2F8F9FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.line),
          ),
          content: Row(
            children: [
              Icon(
                hidden ? Icons.photo_camera_outlined : Icons.navigation_rounded,
                color: AppColors.violet,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(message),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final marketPreviewActive = _marketPreviewActive;
    final hasOverlay =
        _cardCanvasOpen ||
        _cardAdvisorOpen ||
        _applicationAssistantOpen ||
        _proPageOpen ||
        _proWorkspaceOpen ||
        _billAnalysisOpen ||
        _tipSubmissionOpen ||
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
                      child: TickerMode(
                        enabled: !hasOverlay || marketPreviewActive,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: marketPreviewActive
                                ? MediaQuery.paddingOf(context).top
                                : 0,
                          ),
                          child: _mainBody(),
                        ),
                      ),
                      builder: (context, child) {
                        final fade =
                            marketPreviewActive && _marketReturnUsesFade
                            ? MotionTokens.standardEnter.transform(
                                _marketCardTransitionController.value,
                              )
                            : marketPreviewActive
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
                        ? EdgeSwipeBack(
                            key: ValueKey(_overlayIdentity),
                            enabled:
                                widget.edgeSwipeBackEnabled &&
                                !_cardCanvasOpen &&
                                !_marketCardClosing,
                            followGesture:
                                !marketPreviewActive &&
                                _authMode != AuthMode.passwordRecovery,
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
                                          child: Opacity(
                                            key: const Key(
                                              'detail-return-opacity',
                                            ),
                                            opacity: _marketReturnUsesFade
                                                ? MotionTokens.standardEnter
                                                      .transform(
                                                        _marketCardTransitionController
                                                            .value,
                                                      )
                                                : 1,
                                            child: child,
                                          ),
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
                if (_authCelebrationVersion != 0)
                  Positioned.fill(
                    child: CardBurstCelebration(
                      key: ValueKey(
                        'auth-success-card-burst-$_authCelebrationVersion',
                      ),
                      trigger: _authCelebrationVersion,
                      cards: _uCardsForCelebration,
                      onFinished: _clearAuthCelebration,
                    ),
                  ),
                if (marketPreviewActive && !_marketReturnUsesFade)
                  if (_marketCardSourceGeometry case final sourceGeometry?)
                    MarketCardTransition(
                      key: const Key('market-card-transition'),
                      card: _marketTransitionCard!,
                      animation: _marketCardTransitionController,
                      sourceRect: sourceGeometry.artworkRect,
                      targetRect: _marketDetailArtworkRect(
                        context,
                      ).shift(Offset(0, -_closingPreviewScrollOffset)),
                      sourceTitleRect: sourceGeometry.titleRect,
                      targetTitleRect: _marketDetailTitleRect(
                        context,
                      ).shift(Offset(0, -_closingPreviewScrollOffset)),
                      animateTitle: _transitionIncludesSourceTitle,
                      hideArtworkOnForward: _reconstructPreviewOnEntrance,
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
    if (_tipSubmissionOpen) return 'tip-submission';
    if (_billAnalysisOpen) return 'bill-analysis';
    if (_cardAdvisorOpen) return 'card-advisor';
    if (_applicationAssistantOpen) {
      return 'application-assistant-${_applicationAssistantInitialCard?.id ?? 'catalog'}';
    }
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

  void _openAdvisorRecommendation(CardSummary card) {
    _previewReturnToWorkspace = false;
    _showCard(card);
  }

  Widget _buildCardAdvisorOverlay() {
    final previewCard = _previewCard;
    final previewOpen = previewCard != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !previewOpen,
          child: Offstage(
            key: const Key('card-advisor-retained-layer'),
            offstage: previewOpen,
            child: CardAdvisorPage(
              repository: _cardAdvisorRepository,
              cards: _catalogCards,
              onBack: _closeOverlay,
              onOpenCard: _openAdvisorRecommendation,
              onLoginRequired: () => setState(() {
                _cardAdvisorOpen = false;
                _authMode = AuthMode.login;
              }),
            ),
          ),
        ),
        if (previewCard != null)
          Positioned.fill(child: _buildCardPreview(previewCard)),
      ],
    );
  }

  Widget _buildCardPreview(CardSummary previewCard) {
    final entranceAnimation = _marketPreviewActive
        ? _marketCardTransitionController
        : null;
    final sourceImageCacheWidth =
        _marketPreviewActive && !_reconstructPreviewOnEntrance
        ? (_marketCardSourceGeometry!.artworkRect.width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(1, 1280)
        : null;
    if (!widget.enableRemoteData) {
      return CardPreviewPage(
        card: previewCard,
        detail: _detailRepository.detailFor(previewCard),
        added: _visibleAddedCardIds.contains(previewCard.id),
        favorite: _visibleFavoriteCardIds.contains(previewCard.id),
        onBack: _closeOverlay,
        onAddedChanged: (added) => _changeCard(previewCard, added),
        onFavoriteChanged: (favorite) =>
            _changeCardFavorite(previewCard, favorite),
        onCorrection: () => _openCorrection(previewCard),
        onCompare: () => _openComparison(previewCard),
        onManagePersonalCard: LedgerConfig.enabled
            ? () => _openLedger(product: previewCard)
            : null,
        onOpenApplicationAssistant: () =>
            _openApplicationAssistant(previewCard),
        watched: _proWorkspaceController.isWatched(previewCard.id),
        onWatchChanged: (watched) => _changeCardWatch(previewCard, watched),
        onViewSimilar: _viewSimilarCards,
        isPro: _isPro,
        entranceAnimation: entranceAnimation,
        sourceImageCacheWidth: sourceImageCacheWidth,
        fadeOnExit: _marketReturnUsesFade,
        onScrollOffsetChanged: (offset) => _previewScrollOffset = offset,
        reconstructOnEntrance:
            _marketPreviewActive && _reconstructPreviewOnEntrance,
      );
    }
    return FutureBuilder(
      future: _remoteDetailRepository.detailFor(
        previewCard,
        locale: Localizations.localeOf(context),
      ),
      builder: (context, snapshot) {
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
          added: _visibleAddedCardIds.contains(previewCard.id),
          favorite: _visibleFavoriteCardIds.contains(previewCard.id),
          onBack: _closeOverlay,
          onAddedChanged: (added) => _changeCard(previewCard, added),
          onFavoriteChanged: (favorite) =>
              _changeCardFavorite(previewCard, favorite),
          onCorrection: () => _openCorrection(previewCard),
          onCompare: () => _openComparison(previewCard),
          onManagePersonalCard: LedgerConfig.enabled
              ? () => _openLedger(product: previewCard)
              : null,
          onOpenApplicationAssistant: () =>
              _openApplicationAssistant(previewCard),
          watched: _proWorkspaceController.isWatched(previewCard.id),
          onWatchChanged: (watched) => _changeCardWatch(previewCard, watched),
          onViewSimilar: _viewSimilarCards,
          isPro: _isPro,
          commentRepository: widget.enableRemoteData
              ? _cardCommentRepository
              : null,
          signedIn: _authController.isVerified,
          onCommentLoginRequired: () => setState(() {
            _authMode = AuthMode.login;
          }),
          usingOfflineFallback: snapshot.hasError,
          entranceAnimation: entranceAnimation,
          sourceImageCacheWidth: sourceImageCacheWidth,
          fadeOnExit: _marketReturnUsesFade,
          onScrollOffsetChanged: (offset) => _previewScrollOffset = offset,
          reconstructOnEntrance:
              _marketPreviewActive && _reconstructPreviewOnEntrance,
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

  Widget? _overlayBody() {
    if (_tipSubmissionOpen) {
      return TipSubmissionPage(
        cards: _catalogCards,
        onBack: _closeOverlay,
        onSubmit: _saveSubmission,
        onOpenContributions: _openTipContributions,
      );
    }
    if (_billAnalysisOpen) {
      return BillAnalysisPage(
        repository: _billAnalysisRepository,
        onAddToLedger: LedgerConfig.enabled
            ? (bill) => _openLedger(bill: bill)
            : null,
        benchmarkRepository: _billBenchmarkRepository,
        enableRemoteData: widget.enableRemoteData,
        onBack: _closeOverlay,
        cards: _catalogCards,
        historyRepository: ProConfig.billHistoryEnabled
            ? _billHistoryRepository
            : null,
        onOpenHistory: ProConfig.billHistoryEnabled ? _openBillHistory : null,
      );
    }
    if (_cardAdvisorOpen) {
      return _buildCardAdvisorOverlay();
    }
    if (_applicationAssistantOpen) {
      return CardApplicationAssistantPage(
        repository: _applicationAssistantRepository,
        cards: _catalogCards,
        enableRemoteData: widget.enableRemoteData,
        initialCard: _applicationAssistantInitialCard,
        onBack: _closeOverlay,
        onLoginRequired: () => setState(() {
          _applicationAssistantOpen = false;
          _applicationAssistantInitialCard = null;
          _applicationAssistantReturnCard = null;
          _authMode = AuthMode.login;
        }),
        onProRequired: () => setState(() {
          _applicationAssistantOpen = false;
          _applicationAssistantInitialCard = null;
          _applicationAssistantReturnCard = null;
          _proPageOpen = true;
        }),
        onOpenArticle: _openArticleBySlug,
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
      if (authMode == AuthMode.passwordRecovery) {
        return PasswordRecoveryPage(
          controller: _authController,
          onBack: _clearPasswordRecoveryOverlay,
        );
      }
      return AuthPage(
        controller: _authController,
        onBack: _closeOverlay,
        celebrationCards: _uCardsForCelebration,
        referralEnabled: _referralEnabled,
        onReferralCodeAccepted: _savePendingReferralCode,
      );
    }
    if (_comparisonOpen) {
      return CardComparisonPage(
        cards: _catalogCards
            .where((card) => !card.isGlobalAccount)
            .toList(growable: false),
        initialCard: _comparisonInitialCard,
        initialCards: _comparisonInitialCards,
        workspaceController: _isPro ? _proWorkspaceController : null,
        maxCards: _isPro ? 4 : 2,
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
      return _buildCardPreview(previewCard);
    }
    final article = _article;
    if (article != null) {
      return ArticleDetailPage(
        article: article,
        cards: _catalogCards,
        favorite: _visibleFavoriteArticleIds.contains(article.id),
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onFavoriteChanged: (favorite) =>
            _changeArticleFavorite(article, favorite),
        onLike: widget.enableRemoteData
            ? () => _rankingRepository.likeArticle(article.id)
            : null,
        onCorrection: article.isCommunityTip ? _openArticleCorrection : null,
      );
    }
    final profileSection = _profileSection;
    if (profileSection != null) {
      if (profileSection == ProfileSection.tools) {
        return ToolsPage(
          key: _toolsPageKey,
          repository: _toolsRepository,
          cards: _catalogCards,
          onBack: _closeOverlay,
        );
      }
      if (profileSection == ProfileSection.motionLab) {
        return MotionLabPage(onBack: _closeOverlay, cards: _catalogCards);
      }
      if (profileSection == ProfileSection.referral) {
        return ReferralPage(
          repository: _referralRepository,
          onBack: _closeOverlay,
          profileName: _authController.user?.profileName ?? 'CardFi 用户',
          avatarUrl: _authController.user?.avatarUrl,
        );
      }
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
        onRefreshNotifications: _refreshNotificationCenter,
        onOpenAppMessage: (message) => _openNotificationRoute(message.route),
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        pushEnabled: _pushEnabled,
        notificationPermissionStatus: _notificationPermissionStatus,
        onPushEnabledChanged: _changePushEnabled,
        hapticsEnabled: _hapticsEnabled,
        cardSwipeHapticsEnabled: _cardSwipeHapticsEnabled,
        hapticStrength: _hapticStrength,
        hasVerifiedAccount: _authController.isVerified,
        referralEnabled: _referralEnabled,
        onHapticsEnabledChanged: _changeHapticsEnabled,
        onCardSwipeHapticsEnabledChanged: _changeCardSwipeHapticsEnabled,
        onHapticStrengthChanged: _changeHapticStrength,
        appVersionRepository: widget.enableRemoteData
            ? _appVersionRepository
            : null,
        profileName: _authController.user?.profileName,
        profileUserId: _authController.user?.id,
        profileEmail: _authController.user?.email,
        avatarUrl: _authController.user?.avatarUrl,
        onProfileNameChanged: _authController.user == null
            ? null
            : _authController.updateDisplayName,
        onAvatarChanged: _authController.user == null
            ? null
            : _authController.updateAvatar,
        onLogout: _authController.user == null ? null : _logoutFromSettings,
        onDeleteAccount: _authController.isVerified
            ? _deleteCurrentAccount
            : null,
        loginProviders:
            _authController.user?.loginProviders ?? const <AuthLoginProvider>{},
        googleAuthAvailable: _authController.googleConfigured,
        appleAuthAvailable: _authController.appleConfigured,
        onLinkGoogle: _authController.googleConfigured
            ? _authController.linkGoogleIdentity
            : null,
        onLinkApple: _authController.appleConfigured
            ? _authController.linkAppleIdentity
            : null,
        onUnlinkGoogle: _authController.googleConfigured
            ? _authController.unlinkGoogleIdentity
            : null,
        onUnlinkApple: _authController.appleConfigured
            ? _authController.unlinkAppleIdentity
            : null,
      );
    }
    final searchMode = _searchMode;
    if (searchMode != null) {
      return CardSearchPage(
        mode: searchMode,
        cards: _catalogCards,
        addedCardIds: _visibleAddedCardIds,
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
          cards: _cardsForIds(
            _canManagePersonalData ? _addedCardIds : _demoCardIds,
          ),
          cardHeightScale: _homeCardHeightScale,
          displayMode: _homeCardDisplayMode,
          onAddCard: _addCard,
          onOpenCard: _openCard,
          onOpenCardTransition: _openHomeCard,
          transitioningCardId: _marketPreviewActive && !_marketReturnUsesFade
              ? _marketTransitionCard?.id
              : null,
          onCardHeightScaleChanged: _changeHomeCardHeightScale,
          onReorderCards: _reorderHomeCards,
          onDisplayModeChanged: _changeHomeCardDisplayMode,
          isPro: _canUseHomeCardDisplayModes,
          onOpenPro: _openPro,
          onToggleNavigation: () =>
              setState(() => _navigationHidden = !_navigationHidden),
          navigationVisible: !_navigationHidden,
        ),
        MarketPage(
          repository: _catalogRepository,
          onSearch: () => _showSearch(CardSearchMode.market),
          onCompare: _openComparison,
          onOpenCanvas: _openCardCanvas,
          onOpenAiAdvisor: _openAiAssistantHub,
          onOpenCard: _openCard,
          onOpenCardTransition: _openMarketCard,
          transitioningCardId: _marketPreviewActive && !_marketReturnUsesFade
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
          onOpenTipSubmission: _openTipSubmission,
          onCurrentTabReselected: _toggleNavigationForScreenshot,
        ),
        ProfilePage(
          onOpenSection: _openProfileSection,
          onLogin: _openAuth,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          isPro: _isPro,
          authUser: _authController.user,
          cardCount: _canManagePersonalData ? _addedCardIds.length : 0,
          favoriteCount: _canManagePersonalData
              ? _favoriteCardIds.length + _favoriteArticleIds.length
              : 0,
          billHistoryEnabled: ProConfig.billHistoryEnabled,
        ),
        AddCardPage(
          cards: _catalogCards,
          addedCardIds: _visibleAddedCardIds,
          onCardChanged: _changeCard,
          onOpenCard: _openCard,
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

class _AnimatedTabStageState extends State<_AnimatedTabStage>
    with SingleTickerProviderStateMixin {
  late final Set<int> _visited = {widget.index};
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.tabSwitch,
      value: 1,
    );
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
                    key: ValueKey('main-tab-offstage-$childIndex'),
                    offstage: childIndex != widget.index,
                    child: IgnorePointer(
                      ignoring: childIndex != widget.index,
                      child: ExcludeSemantics(
                        excluding: childIndex != widget.index,
                        child: TickerMode(
                          enabled: childIndex == widget.index,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              (1 - value) * MotionTokens.smallOffset,
                            ),
                            child: Transform.scale(
                              scale:
                                  MotionTokens.incomingScale +
                                  (1 - MotionTokens.incomingScale) * value,
                              alignment: Alignment.center,
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
