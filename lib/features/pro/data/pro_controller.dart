import 'dart:async';

import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/data/pro_verification_repository.dart';
import 'package:cardfi/features/pro/domain/pro_models.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

typedef ProAccessTokenProvider = Future<String?> Function();
typedef ProApplicationUserNameProvider = Future<String?> Function();

class ProController extends ChangeNotifier {
  ProController({
    required ApiClient apiClient,
    required this.accessTokenProvider,
    this.applicationUserNameProvider,
    this.previewUnlocked = false,
    InAppPurchase? billing,
  }) : _verification = ProVerificationRepository(apiClient),
       _billingOverride = billing;

  final ProAccessTokenProvider accessTokenProvider;
  final ProVerificationRepository _verification;
  final ProApplicationUserNameProvider? applicationUserNameProvider;
  final InAppPurchase? _billingOverride;
  final bool previewUnlocked;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _entitlementExpiryTimer;
  InAppPurchase? _billing;
  final Map<String, ProductDetails> _products = {};
  final List<PurchaseDetails> _queuedPurchases = [];
  Future<void> _purchaseWork = Future<void>.value();
  String? _accessToken;
  String? _applicationUserName;
  bool _purchaseHandlingReady = false;
  bool _initializing = false;
  bool _disposed = false;

  ProPlan selectedPlan = ProPlan.yearly;
  ProEntitlement entitlement = const ProEntitlement.free();
  List<ProOffer> offers = ProConfig.offers;
  bool loading = true;
  bool purchasePending = false;
  bool restoring = false;
  bool storeAvailable = false;
  bool serviceAvailable = false;
  bool entitlementServiceAvailable = false;
  String? message;
  int activationCelebrationVersion = 0;

  bool get billingEnabled => ProConfig.billingEnabled;
  bool get accountConnected => _accessToken?.isNotEmpty == true;
  bool get accountPurchaseLinked => _isValidPurchaseLink(_applicationUserName);
  bool get isActive => previewUnlocked || entitlement.isActive;
  bool get canPurchase =>
      billingEnabled &&
      serviceAvailable &&
      storeAvailable &&
      accountConnected &&
      accountPurchaseLinked &&
      offerFor(selectedPlan).available &&
      !loading &&
      !purchasePending;

  ProOffer offerFor(ProPlan plan) =>
      offers.firstWhere((offer) => offer.plan == plan);

  Future<void> initialize() async {
    if (_initializing) return;
    _initializing = true;
    loading = true;
    message = null;
    notifyListeners();
    try {
      if (ProConfig.billingEnabled) {
        try {
          // The purchase stream must be observed before any network or store
          // await, otherwise an unfinished transaction can be missed at launch.
          _billing = _billingOverride ?? InAppPurchase.instance;
          _purchaseSubscription ??= _billing!.purchaseStream.listen(
            _receivePurchases,
            onError: (_) {
              purchasePending = false;
              message = '商店购买状态读取失败，请稍后重试。';
              notifyListeners();
            },
          );
        } catch (_) {
          _billing = null;
          storeAvailable = false;
          message = '当前设备暂时无法连接应用商店。';
        }
      }

      if (previewUnlocked) {
        _setEntitlement(
          ProEntitlement(
            status: ProEntitlementStatus.active,
            plan: ProPlan.yearly,
            expiresAt: DateTime.now().add(const Duration(days: 365)),
            autoRenewing: true,
            accessGranted: true,
          ),
        );
      }

      // Entitlements are authoritative server state even when this build does
      // not expose store billing (for example, internal admin-granted access).
      await _refreshAccountContext();
      if (accountConnected) {
        await _loadServiceConfiguration();
      }
      if (entitlementServiceAvailable && accountConnected) {
        try {
          _setEntitlement(
            await _verification.loadEntitlement(accessToken: _accessToken!),
          );
        } on ApiException catch (error) {
          message = error.message;
        } catch (_) {
          message = '暂时无法刷新 Pro 权益，请稍后重试。';
        }
      }

      if (ProConfig.billingEnabled) {
        // Drain everything received while account and backend state were
        // loading. New events remain queued until this loop is empty.
        while (_queuedPurchases.isNotEmpty) {
          final queued = List<PurchaseDetails>.of(_queuedPurchases);
          _queuedPurchases.clear();
          await _handlePurchases(queued);
        }
        _purchaseHandlingReady = true;

        final billing = _billing;
        if (billing != null) {
          try {
            storeAvailable = await billing.isAvailable();
            if (storeAvailable) await _loadProducts();
          } catch (_) {
            storeAvailable = false;
            message = '当前设备暂时无法连接应用商店。';
          }
        }
      }
    } finally {
      loading = false;
      _initializing = false;
      notifyListeners();
    }
  }

  void selectPlan(ProPlan plan) {
    if (selectedPlan == plan) return;
    selectedPlan = plan;
    message = null;
    notifyListeners();
  }

  Future<String?> purchase() async {
    await _refreshAccountContext();
    await _loadServiceConfiguration();
    if (!ProConfig.billingEnabled) {
      return '请先配置 ENABLE_PRO_BILLING 与商店订阅商品。';
    }
    if (!serviceAvailable) return 'Pro 服务端尚未开放，暂时不能购买。';
    if (!accountConnected) return '请先完成正式账号服务接入并登录。';
    if (!accountPurchaseLinked) return '当前账号尚未配置安全的购买关联 ID。';
    if (!storeAvailable) return '当前设备暂时无法连接应用商店。';
    final product = _products[offerFor(selectedPlan).productId];
    if (product == null) return '商店还没有返回所选订阅商品。';

    purchasePending = true;
    message = null;
    notifyListeners();
    try {
      final started = await _billing!.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: _applicationUserName,
        ),
      );
      if (!started) {
        purchasePending = false;
        notifyListeners();
        return '没有启动购买流程，请稍后重试。';
      }
      return null;
    } catch (_) {
      purchasePending = false;
      notifyListeners();
      return '购买流程启动失败，请稍后重试。';
    }
  }

  Future<String?> restore() async {
    await _refreshAccountContext();
    await _loadServiceConfiguration();
    if (!ProConfig.billingEnabled) return '请先配置商店订阅商品。';
    if (!serviceAvailable) return 'Pro 服务端尚未开放，暂时不能恢复购买。';
    if (!accountConnected) return '请先完成正式账号服务接入并登录。';
    if (!accountPurchaseLinked) return '当前账号尚未配置安全的购买关联 ID。';
    if (!storeAvailable) return '当前设备暂时无法连接应用商店。';
    restoring = true;
    message = null;
    notifyListeners();
    try {
      await _billing!.restorePurchases(
        applicationUserName: _applicationUserName,
      );
      if (restoring) {
        restoring = false;
        message = '恢复请求已完成；如有有效订阅，权益会在商店返回后自动更新。';
        notifyListeners();
      }
      return null;
    } catch (_) {
      restoring = false;
      notifyListeners();
      return '恢复购买失败，请稍后重试。';
    }
  }

  Future<void> refreshEntitlement() async {
    await _refreshAccountContext();
    if (!accountConnected) {
      _setEntitlement(const ProEntitlement.free());
      message = '请先登录后刷新 Pro 权益。';
      notifyListeners();
      return;
    }
    await _loadServiceConfiguration();
    if (!entitlementServiceAvailable) {
      message = 'Pro 服务端尚未开放。';
      notifyListeners();
      return;
    }
    loading = true;
    message = null;
    notifyListeners();
    try {
      _setEntitlement(
        await _verification.loadEntitlement(accessToken: _accessToken!),
      );
    } on ApiException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Pro 权益刷新失败，请稍后重试。';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    final response = await _billing!.queryProductDetails(
      ProConfig.offers.map((offer) => offer.productId).toSet(),
    );
    if (response.error != null) {
      message = '订阅商品读取失败：${response.error!.message}';
    } else if (response.notFoundIDs.isNotEmpty) {
      message = '部分订阅商品尚未在当前商店环境生效。';
    }
    _products
      ..clear()
      ..addEntries(
        response.productDetails.map((product) => MapEntry(product.id, product)),
      );
    offers = [
      for (final offer in ProConfig.offers)
        if (_products[offer.productId] case final product?)
          offer.copyWith(
            // Keep the app-owned plan label as the source of truth. StoreKit
            // can temporarily return a title in the storefront's fallback
            // language (or an availability placeholder) while subscription
            // localizations are propagating. Price and currency must still
            // come from StoreKit, but showing that raw title would leak mixed
            // language or placeholder copy into the purchase UI.
            title: offer.title,
            price: product.price,
            currencyCode: product.currencyCode,
            available: true,
          )
        else
          offer,
    ];
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          message = '购买正在等待商店确认。';
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          restoring = false;
          message = '购买已取消。';
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          restoring = false;
          message = purchase.error?.message ?? '购买失败，请稍后重试。';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
      }
      notifyListeners();
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    if (!serviceAvailable) {
      purchasePending = false;
      restoring = false;
      message = '交易已返回，但 Pro 服务端尚未开放；请稍后恢复购买。';
      return;
    }
    if (!accountConnected) {
      purchasePending = false;
      restoring = false;
      message = '交易已返回，但账号尚未连接，暂不能发放 Pro 权益。';
      return;
    }
    try {
      final wasActive = isActive;
      final result = await _verification.verify(
        purchase: purchase,
        accessToken: _accessToken!,
      );
      if (result.valid) _setEntitlement(result.entitlement);
      if (result.valid && !wasActive && isActive) {
        activationCelebrationVersion++;
      }
      purchasePending = false;
      restoring = false;
      message = switch ((result.valid, entitlement.isActive)) {
        (true, true) => 'Pro 已成功开通。',
        (true, false) => '交易已通过校验，Pro 权益正在处理中。',
        (false, _) => '商店交易未通过服务端校验。',
      };
      if (purchase.pendingCompletePurchase) {
        await _billing!.completePurchase(purchase);
      }
    } on ApiException catch (error) {
      purchasePending = false;
      restoring = false;
      if (error.code == 'PRO_TRANSACTION_ALREADY_BOUND') {
        message = '该商店订阅已绑定其他账号，请切换到原账号后恢复购买。';
        if (purchase.pendingCompletePurchase) {
          await _billing!.completePurchase(purchase);
        }
      } else {
        message = '交易已返回，服务端验单暂时失败；请稍后点击恢复购买。';
      }
    } catch (_) {
      purchasePending = false;
      restoring = false;
      message = '交易已返回，服务端验单暂时失败；请稍后点击恢复购买。';
    }
  }

  Future<void> _refreshAccountContext() async {
    try {
      _accessToken = await accessTokenProvider();
    } catch (_) {
      _accessToken = null;
    }
    try {
      _applicationUserName = await applicationUserNameProvider?.call();
    } catch (_) {
      _applicationUserName = null;
    }
  }

  void _setEntitlement(ProEntitlement next) {
    _entitlementExpiryTimer?.cancel();
    entitlement = next;
    final expiresAt = next.expiresAt;
    if (!next.isActive || expiresAt == null || previewUnlocked) return;
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      entitlement = ProEntitlement(
        status: ProEntitlementStatus.expired,
        plan: next.plan,
        expiresAt: expiresAt,
        autoRenewing: next.autoRenewing,
        accessGranted: false,
      );
      return;
    }
    _entitlementExpiryTimer = Timer(remaining, () {
      _setEntitlement(
        ProEntitlement(
          status: ProEntitlementStatus.expired,
          plan: next.plan,
          expiresAt: expiresAt,
          autoRenewing: next.autoRenewing,
          accessGranted: false,
        ),
      );
      notifyListeners();
      if (entitlementServiceAvailable && accountConnected) {
        unawaited(refreshEntitlement());
      }
    });
  }

  bool _isValidPurchaseLink(String? value) {
    final candidate = value?.trim() ?? '';
    // StoreKit 2 only applies appAccountToken when it is a UUID. Requiring the
    // same opaque shape on both stores avoids silently unbound transactions.
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(candidate);
  }

  Future<void> _loadServiceConfiguration() async {
    try {
      final configuration = await _verification.loadConfiguration();
      final productsMatch = configuration.matchesProducts(
        monthly: ProConfig.monthlyProductId,
        yearly: ProConfig.yearlyProductId,
      );
      entitlementServiceAvailable = configuration.canLoadEntitlements(
        monthly: ProConfig.monthlyProductId,
        yearly: ProConfig.yearlyProductId,
      );
      final currentStoreAvailable = switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS => configuration.appStoreEnabled,
        TargetPlatform.android => configuration.googlePlayEnabled,
        _ => false,
      };
      serviceAvailable =
          configuration.enabled &&
          productsMatch &&
          (!ProConfig.billingEnabled || currentStoreAvailable);
      if (configuration.enabled && !productsMatch) {
        message = '客户端与服务端的 Pro 商品配置不一致。';
      } else if (ProConfig.billingEnabled &&
          configuration.enabled &&
          !currentStoreAvailable) {
        message = '当前平台的 Pro 验单服务尚未配置。';
      }
    } catch (_) {
      serviceAvailable = false;
      entitlementServiceAvailable = false;
      message = '暂时无法确认 Pro 服务状态。';
    }
  }

  void _receivePurchases(List<PurchaseDetails> purchases) {
    if (!_purchaseHandlingReady) {
      _queuedPurchases.addAll(purchases);
      return;
    }
    _purchaseWork = _purchaseWork
        .then((_) => _handlePurchases(purchases))
        .catchError((Object _) {
          purchasePending = false;
          restoring = false;
          message = '商店交易处理失败，请稍后重试或恢复购买。';
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _disposed = true;
    _entitlementExpiryTimer?.cancel();
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
