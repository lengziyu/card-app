import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/pro/data/pro_controller.dart';
import 'package:cardfi/features/pro/domain/pro_models.dart';
import 'package:cardfi/features/pro/presentation/pro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Pro purchase page is complete in English', (tester) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(390, 844);
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

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [AppLocalizations.delegate],
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProPage(
              controller: controller,
              onBack: () {},
              onPurchase: () {},
              onRestore: () {},
              onManageSubscription: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Get more from your card wallet'), findsOneWidget);
    expect(find.text('Monthly Pro'), findsOneWidget);
    expect(find.text('Yearly Pro'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Pro Benefits'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Pro Benefits'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('pro-manage-subscription')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Refresh membership status'), findsOneWidget);
    expect(find.text('Manage or cancel subscription'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

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
