import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/pro/data/pro_controller.dart';
import 'package:card_app/features/pro/domain/pro_models.dart';
import 'package:card_app/features/pro/presentation/pro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Pro page fits a narrow screen and exposes subscription actions',
    (tester) async {
      AppColors.configure(Brightness.light);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final apiClient = ApiClient(baseUrl: 'https://example.test');
      final controller = ProController(
        apiClient: apiClient,
        accessTokenProvider: () async => null,
      );
      await controller.initialize();
      addTearDown(() {
        controller.dispose();
        apiClient.close();
      });
      var manageCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.35),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: ProPage(
                controller: controller,
                onBack: () {},
                onPurchase: () {},
                onRestore: () {},
                onManageSubscription: () => manageCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pro-page')), findsOneWidget);
      expect(find.text('月度 Pro'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pro-plan-monthly')));
      expect(controller.selectedPlan, ProPlan.monthly);

      await tester.scrollUntilVisible(
        find.byKey(const Key('pro-manage-subscription')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('pro-manage-subscription')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pro-manage-subscription')));
      expect(manageCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
