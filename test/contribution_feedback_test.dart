import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/profile/presentation/profile_page.dart';
import 'package:cardfi/features/profile/presentation/profile_subpage.dart';
import 'package:cardfi/features/notifications/data/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings gates the referral entry with the client flag', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    ProfileSection? openedSection;

    Future<void> pumpSettings({
      required bool referralEnabled,
      required bool hasVerifiedAccount,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSubpage(
              section: ProfileSection.settings,
              favoriteCards: const [],
              recentCards: const [],
              favoriteArticles: const [],
              submissions: const [],
              appMessages: const [],
              onBack: () {},
              onOpenCard: (_) {},
              onOpenArticle: (_) {},
              onOpenSection: (section) => openedSection = section,
              onSubmit: (_) async {},
              onRefreshNotifications: () async {},
              onOpenAppMessage: (_) {},
              selectedLanguage: AppLanguage.system,
              onLanguageChanged: (_) {},
              pushEnabled: false,
              notificationPermissionStatus:
                  NotificationPermissionStatus.notDetermined,
              onPushEnabledChanged: (_) async {},
              hapticsEnabled: true,
              cardSwipeHapticsEnabled: true,
              hapticStrength: AppHapticStrength.medium,
              hasVerifiedAccount: hasVerifiedAccount,
              referralEnabled: referralEnabled,
              onHapticsEnabledChanged: (_) {},
              onCardSwipeHapticsEnabledChanged: (_) {},
              onHapticStrengthChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpSettings(referralEnabled: true, hasVerifiedAccount: true);

    final referral = find.byKey(const Key('settings-referral'));
    expect(referral, findsOneWidget);
    expect(find.text('会员与邀请'), findsOneWidget);
    expect(find.text('邀请好友并查看 Pro 奖励进度'), findsOneWidget);

    tester
        .widget<InkWell>(
          find.descendant(of: referral, matching: find.byType(InkWell)),
        )
        .onTap!();
    expect(openedSection, ProfileSection.referral);

    await pumpSettings(referralEnabled: false, hasVerifiedAccount: true);
    expect(referral, findsNothing);

    await pumpSettings(referralEnabled: true, hasVerifiedAccount: false);
    expect(referral, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contribution center shows progress, adoption and admin reply', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final submission = LocalSubmission(
      id: 'correction-1',
      category: LocalSubmissionCategory.correction,
      description: '这张卡片的官方费用页面已经更新。',
      cardName: '示例卡',
      createdAt: DateTime.utc(2026, 7, 25, 8),
      updatedAt: DateTime.utc(2026, 7, 26, 8),
      status: LocalSubmissionStatus.resolved,
      statusNote: '卡片资料和核验时间已经更新。',
      adminReply: '感谢你的纠错，相关费用已按官方资料修正。',
      repliedAt: DateTime.utc(2026, 7, 26, 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.4),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: ProfileSubpage(
              section: ProfileSection.notifications,
              favoriteCards: const [],
              recentCards: const [],
              favoriteArticles: const [],
              submissions: [submission],
              appMessages: const [],
              onBack: () {},
              onOpenCard: (_) {},
              onOpenArticle: (_) {},
              onOpenSection: (_) {},
              onSubmit: (_) async {},
              onRefreshNotifications: () async {},
              onOpenAppMessage: (_) {},
              selectedLanguage: AppLanguage.system,
              onLanguageChanged: (_) {},
              pushEnabled: false,
              notificationPermissionStatus:
                  NotificationPermissionStatus.notDetermined,
              onPushEnabledChanged: (_) async {},
              hapticsEnabled: true,
              cardSwipeHapticsEnabled: true,
              hapticStrength: AppHapticStrength.medium,
              hasVerifiedAccount: true,
              onHapticsEnabledChanged: (_) {},
              onCardSwipeHapticsEnabledChanged: (_) {},
              onHapticStrengthChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('我的贡献'), findsOneWidget);
    expect(find.text('已提交'), findsOneWidget);
    expect(find.text('处理中'), findsOneWidget);
    expect(find.text('已采纳'), findsOneWidget);
    expect(find.text('已更新'), findsWidgets);
    expect(find.text('卡片资料和核验时间已经更新。'), findsOneWidget);
    expect(find.text('处理回复'), findsOneWidget);
    expect(find.text('感谢你的纠错，相关费用已按官方资料修正。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
