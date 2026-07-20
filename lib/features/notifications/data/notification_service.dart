import 'dart:async';
import 'dart:math';

import 'package:card_app/features/notifications/data/notification_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService(this._repository);

  static const _enabledKey = 'content-push-enabled-v1';
  static const _installationKey = 'content-push-installation-id-v1';

  final NotificationRepository _repository;
  final _routes = StreamController<String>.broadcast();
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
      await _ensureFirebase();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return NotificationEnableResult.denied;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return NotificationEnableResult.unavailable;
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
      await _ensureFirebase();
      final token = await FirebaseMessaging.instance.getToken();
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
