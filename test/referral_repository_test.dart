import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/referrals/data/referral_repository.dart';
import 'package:cardfi/features/referrals/presentation/referral_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('invite poster includes the CardFi logo and short description', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'referral': {
              'code': 'CARD2026',
              'usedInviteCode': false,
              'activated': true,
              'effectiveInvites': 3,
              'nextRewardAt': 10,
              'rewardedMonths': 1,
              'pendingRewardMonths': 0,
              'maxRewardMonths': 12,
              'firstRewardInviteCount': 3,
              'standardRewardInviteCount': 10,
              'rewardTier': 'month',
              'pendingInvites': 0,
              'activationStatus': 'effective',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReferralPage(
          repository: ReferralRepository(
            client,
            accessTokenProvider: () async => 'account-token',
          ),
          onBack: () {},
          profileName: 'CardFi 用户',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('invite-brand-logo')),
        matching: find.byType(Image),
      ),
    );
    final resizedLogo = logo.image as ResizeImage;
    expect(
      (resizedLogo.imageProvider as AssetImage).assetName,
      'assets/branding/cardfi-icon-master.png',
    );
    expect(find.text('CardFi'), findsOneWidget);
    expect(find.text('浏览、整理与比较卡片公开信息'), findsOneWidget);
    expect(find.byKey(const Key('invite-brand-description')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'maps milestone and pending eligibility fields from the server',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/referrals/me');
          expect(request.headers['authorization'], 'Bearer account-token');
          return http.Response(
            jsonEncode({
              'referral': {
                'code': 'CARD2026',
                'usedInviteCode': true,
                'activated': true,
                'effectiveInvites': 10,
                'nextRewardAt': 20,
                'rewardedMonths': 12,
                'pendingRewardMonths': 0,
                'maxRewardMonths': 12,
                'firstRewardInviteCount': 3,
                'standardRewardInviteCount': 10,
                'rewardTier': 'year',
                'pendingInvites': 2,
                'activationStatus': 'effective',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final profile = await ReferralRepository(
        client,
        accessTokenProvider: () async => 'account-token',
      ).loadProfile();

      expect(profile.effectiveInvites, 10);
      expect(profile.nextRewardAt, 20);
      expect(profile.rewardTier, 'year');
      expect(profile.pendingInvites, 2);
      expect(profile.activated, isTrue);
    },
  );
}
