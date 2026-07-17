import 'dart:async';

import 'package:card_app/features/add/presentation/add_card_page.dart';
import 'package:card_app/features/auth/presentation/auth_page.dart';
import 'package:card_app/core/network/api_client.dart';
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
import 'package:card_app/features/market/presentation/card_search_page.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:card_app/features/profile/presentation/profile_subpage.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/ranking/data/remote_ranking_repository.dart';
import 'package:card_app/features/ranking/presentation/article_detail_page.dart';
import 'package:card_app/features/ranking/presentation/ranking_page.dart';
import 'package:card_app/features/shell/widgets/aurora_background.dart';
import 'package:card_app/features/shell/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.enableRemoteData,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final bool enableRemoteData;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _homeCardHeightKey = 'card-app-home-card-height-scale-v1';
  static const _initialMockState = String.fromEnvironment(
    'MOCK_STATE',
    defaultValue: 'cards',
  );

  int _index = 0;
  bool _navigationHidden = false;
  CardSearchMode? _searchMode;
  CardSummary? _previewCard;
  AuthMode? _authMode;
  ProfileSection? _profileSection;
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
  double _homeCardHeightScale = 1;
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
    unawaited(_loadHomeCardHeightScale());
    if (widget.enableRemoteData) {
      _loadRemoteCatalog();
    }
  }

  Future<void> _loadHomeCardHeightScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble(_homeCardHeightKey);
    if (!mounted || value == null) return;
    setState(() => _homeCardHeightScale = clampHomeCardHeightScale(value));
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

  Future<void> _loadRemoteCatalog() async {
    try {
      final homeFuture = _loadCardIdsOrEmpty(
        _catalogSettingsRepository.loadHomeDefaultCardIds(),
      );
      final orderFuture = _loadCardIdsOrEmpty(
        _catalogSettingsRepository.loadListCardOrder(),
      );
      final cards = await _catalogRepository.loadCards();
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
          if (_initialMockState != 'empty') {
            _addedCardIds
              ..clear()
              ..addAll(homeIds);
          }
        });
      }
    } catch (_) {
      // 市场展示正式失败态；搜索继续使用随包目录作为离线兜底。
    }
  }

  Future<List<String>> _loadCardIdsOrEmpty(Future<List<String>> request) async {
    try {
      return await request;
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  void _addCard() {
    setState(() {
      _index = 4;
      _navigationHidden = false;
      _searchMode = null;
      _previewCard = null;
      _authMode = null;
      _profileSection = null;
      _article = null;
      _correctionCard = null;
    });
  }

  void _changeCard(CardSummary card, bool added) {
    setState(() {
      if (added) {
        _addedCardIds.add(card.id);
      } else {
        _addedCardIds.remove(card.id);
      }
    });
  }

  void _reorderHomeCards(List<String> orderedIds) {
    final existingIds = _addedCardIds.toSet();
    setState(() {
      _addedCardIds
        ..clear()
        ..addAll(orderedIds.where(existingIds.contains))
        ..addAll(existingIds.where((id) => !orderedIds.contains(id)));
    });
  }

  void _showSearch(CardSearchMode mode) {
    setState(() {
      _searchMode = mode;
      _previewCard = null;
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
    setState(() {
      if (favorite) {
        _favoriteCardIds.add(card.id);
      } else {
        _favoriteCardIds.remove(card.id);
      }
    });
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

  void _openProfileSection(ProfileSection section) =>
      setState(() => _profileSection = section);

  void _openCorrection(CardSummary card) {
    setState(() => _correctionCard = card);
  }

  void _showAuth(AuthMode mode) {
    setState(() {
      _authMode = mode;
      _searchMode = null;
      _previewCard = null;
    });
  }

  void _closeOverlay() {
    setState(() {
      if (_correctionCard != null) {
        _correctionCard = null;
      } else if (_previewCard != null) {
        _previewCard = null;
      } else if (_authMode != null) {
        _authMode = null;
      } else if (_article != null) {
        _article = null;
      } else if (_profileSection != null) {
        _profileSection = null;
      } else {
        _searchMode = null;
      }
    });
  }

  void _selectDestination(int index) {
    setState(() {
      _index = index;
      _navigationHidden = false;
      _searchMode = null;
      _previewCard = null;
      _authMode = null;
      _profileSection = null;
      _article = null;
      _correctionCard = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay =
        _searchMode != null ||
        _previewCard != null ||
        _authMode != null ||
        _profileSection != null ||
        _article != null ||
        _correctionCard != null;
    return PopScope(
      canPop: !hasOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeOverlay();
      },
      child: AuroraBackground(
        authBackground: _authMode != null,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(child: _body()),
                if (!hasOverlay && !_navigationHidden)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: BottomNavigation(
                      selectedIndex: _index,
                      addSelected: _index == 4,
                      onDestinationSelected: _selectDestination,
                      onAdd: _addCard,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final correctionCard = _correctionCard;
    if (correctionCard != null) {
      return CardCorrectionPage(card: correctionCard, onBack: _closeOverlay);
    }
    final authMode = _authMode;
    if (authMode != null) {
      return AuthPage(
        key: ValueKey(authMode),
        mode: authMode,
        onBack: _closeOverlay,
        onModeChanged: _showAuth,
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
        );
      }
      return FutureBuilder(
        future: _remoteDetailRepository.detailFor(previewCard),
        builder: (context, snapshot) {
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
        cardHeightScale: _homeCardHeightScale,
        onCardHeightScaleChanged: _changeHomeCardHeightScale,
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onOpenArticle: _openArticle,
      );
    }
    final searchMode = _searchMode;
    if (searchMode != null) {
      return CardSearchPage(
        mode: searchMode,
        cards: _catalogCards,
        addedCardIds: _addedCardIds,
        onBack: _closeOverlay,
        onOpenCard: _openCard,
        onCardChanged: _changeCard,
      );
    }
    if (_index == 0) {
      return HomePage(
        cards: _cardsForIds(_addedCardIds),
        cardHeightScale: _homeCardHeightScale,
        onAddCard: _addCard,
        onOpenCard: _openCard,
        onCardHeightScaleChanged: _changeHomeCardHeightScale,
        onReorderCards: _reorderHomeCards,
        onToggleNavigation: () =>
            setState(() => _navigationHidden = !_navigationHidden),
      );
    }
    if (_index == 1) {
      return MarketPage(
        repository: _catalogRepository,
        onSearch: () => _showSearch(CardSearchMode.market),
        onOpenCard: _openCard,
      );
    }
    if (_index == 4) {
      return AddCardPage(
        cards: _catalogCards,
        addedCardIds: _addedCardIds,
        onCardChanged: _changeCard,
        onSearch: () => _showSearch(CardSearchMode.add),
      );
    }
    if (_index == 2) {
      return RankingPage(
        cards: _catalogCards,
        onOpenCard: _openCard,
        onOpenArticle: _openArticle,
        repository: _rankingRepository,
        enableRemoteData: widget.enableRemoteData,
      );
    }
    if (_index == 3) {
      return ProfilePage(
        cardCount: _addedCardIds.length,
        favoriteCount: _favoriteCardIds.length + _favoriteArticleIds.length,
        historyCount: _recentCardIds.length,
        onLogin: () => _showAuth(AuthMode.login),
        onOpenSection: _openProfileSection,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      );
    }
    return const SizedBox.shrink();
  }
}

class _TestCatalogRepository implements CardCatalogRepository {
  const _TestCatalogRepository();

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async =>
      const <CardSummary>[];
}
