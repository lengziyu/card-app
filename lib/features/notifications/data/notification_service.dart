import 'dart:async';
import 'dart:math';

import 'package:cardfi/features/notifications/data/notification_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService(this._repository);

  static const _enabledKey = 'content-push-enabled-v1';
  static const _installationKey = 'content-push-installation-id-v1';

  final NotificationRepository _repository;
  final _routes = StreamController<String>.broadcast();
  final _apns = _ApnsNotificationClient();
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _firebaseReady = false;

  Stream<String> get routes => _routes.stream;

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<String> installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_installationKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final random = Random.secure();
    final next =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-'
        '${List.generate(20, (_) => random.nextInt(16).toRadixString(16)).join()}';
    await preferences.setString(_installationKey, next);
    return next;
  }

  Future<NotificationEnableResult> enable({required String locale}) async {
    try {
      final token = await _requestToken();
      if (token == null || token.isEmpty) {
        return NotificationEnableResult.denied;
      }
      await _repository.subscribe(
        installationId: await installationId(),
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        locale: locale,
      );
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, true);
      return NotificationEnableResult.enabled;
    } catch (_) {
      return NotificationEnableResult.unavailable;
    }
  }

  Future<void> disable() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    try {
      await _repository.unsubscribe(installationId: await installationId());
    } catch (_) {
      // Local opt-out takes effect immediately; the next launch retries server opt-out.
    }
  }

  Future<void> start({required String locale}) async {
    if (!await isEnabled()) return;
    try {
      final token = await _currentToken();
      if (token != null && token.isNotEmpty) {
        await _repository.subscribe(
          installationId: await installationId(),
          token: token,
          platform: defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          locale: locale,
        );
      }
    } catch (_) {
      // Configuration or network failures do not disable the user's preference.
    }
  }

  Future<void> _ensureFirebase() async {
    if (_usesApns) {
      await _apns.initialize(_emitRoute);
      return;
    }
    if (!_firebaseReady) {
      await Firebase.initializeApp();
      FirebaseMessaging.onMessageOpenedApp.listen(_emitRouteFromMessage);
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((token) async {
            if (await isEnabled()) {
              await _repository.subscribe(
                installationId: await installationId(),
                token: token,
                platform: defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ios'
                    : 'android',
                locale: 'system',
              );
            }
          });
      _firebaseReady = true;
    }
    final launchMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (launchMessage != null) _emitRouteFromMessage(launchMessage);
  }

  bool get _usesApns => defaultTargetPlatform == TargetPlatform.iOS;

  Future<String?> _requestToken() async {
    if (_usesApns) {
      await _apns.initialize(_emitRoute);
      if (!await _apns.requestPermission()) return null;
      return _apns.waitForToken();
    }
    await _ensureFirebase();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<String?> _currentToken() async {
    await _ensureFirebase();
    if (_usesApns) return _apns.token();
    return FirebaseMessaging.instance.getToken();
  }

  void _emitRouteFromMessage(RemoteMessage message) =>
      _emitRoute(message.data['route']?.toString() ?? '');

  void _emitRoute(String route) {
    if (route.startsWith('/') && !route.startsWith('//')) _routes.add(route);
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _routes.close();
  }
}

enum NotificationEnableResult { enabled, denied, unavailable }

/// Native APNs bridge used only on iOS. Android continues to use FCM.
class _ApnsNotificationClient {
  static const _channel = MethodChannel('cardfi/apns');
  var _initialized = false;

  Future<void> initialize(ValueChanged<String> onRoute) async {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationOpened') {
        final route = call.arguments?.toString() ?? '';
        if (route.isNotEmpty) onRoute(route);
      }
    });
    _initialized = true;
    final route = await _channel.invokeMethod<String>('initialRoute');
    if (route != null && route.isNotEmpty) onRoute(route);
  }

  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  Future<String?> token() => _channel.invokeMethod<String>('token');

  Future<String?> waitForToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final value = await token();
      if (value != null && value.isNotEmpty) return value;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }
}
