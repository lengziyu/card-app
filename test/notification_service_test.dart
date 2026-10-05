import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/notifications/data/notification_repository.dart';
import 'package:cardfi/features/notifications/data/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cardfi/notifications');
  var platformStatus = 'denied';

  NotificationService service() =>
      NotificationService(NotificationRepository(ApiClient()));

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'authorizationStatus' => platformStatus,
            'openSettings' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('fresh Android denial is treated as not requested yet', () async {
    platformStatus = 'denied';
    final status = await service().status();

    expect(status.permission, NotificationPermissionStatus.notDetermined);
    expect(status.canDeliver, isFalse);
  });

  test(
    'fresh pre-Android 13 authorization still receives onboarding',
    () async {
      platformStatus = 'authorized';
      final status = await service().status();

      expect(status.permission, NotificationPermissionStatus.notDetermined);
      expect(status.canDeliver, isFalse);
    },
  );

  test('records an actual Android denial after a permission request', () async {
    platformStatus = 'denied';
    SharedPreferences.setMockInitialValues({
      'notification-permission-requested-v1': true,
    });
    final status = await service().status();

    expect(status.permission, NotificationPermissionStatus.denied);
  });

  test(
    'requires both system permission and subscription for delivery',
    () async {
      platformStatus = 'authorized';
      SharedPreferences.setMockInitialValues({'content-push-enabled-v1': true});
      final status = await service().status();

      expect(status.permission, NotificationPermissionStatus.authorized);
      expect(status.subscriptionEnabled, isTrue);
      expect(status.canDeliver, isTrue);
    },
  );

  test('opens the platform notification settings', () async {
    expect(await service().openSystemSettings(), isTrue);
  });
}
