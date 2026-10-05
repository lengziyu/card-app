import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/market/data/card_advisor_repository.dart';
import 'package:cardfi/features/market/presentation/card_advisor_page.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('English localizes the AI Card Match question and options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppColors.configure(Brightness.dark);
    final apiClient = ApiClient(baseUrl: 'https://example.test');
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          CountryLocalizations.delegate,
        ],
        home: CardAdvisorPage(
          repository: CardAdvisorRepository(
            apiClient,
            accessTokenProvider: () async => null,
          ),
          cards: localCardCatalog,
          onBack: () {},
          onOpenCard: (_) {},
          onLoginRequired: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI Card Match Assistant'), findsOneWidget);
    expect(find.text('Where do you currently live?'), findsOneWidget);
    expect(find.text('Mainland China'), findsOneWidget);
    expect(find.text('Other country or region'), findsOneWidget);
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );
    expect(find.text('中国大陆'), findsNothing);
    expect(find.text('港澳台'), findsNothing);
    expect(find.text('海外'), findsNothing);

    await tester.tap(find.byKey(const Key('ai-residence-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-residence-country-sheet')), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Singapore');
    await tester.pump();
    await tester.tap(find.text('Singapore').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-residence-country')), findsOneWidget);
    expect(find.text('Singapore'), findsOneWidget);

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('card-advisor-submit')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Review your information'), findsOneWidget);
    expect(find.text('Here is what I understood'), findsOneWidget);
    expect(find.text('Place of residence'), findsOneWidget);
    expect(find.text('Available documents'), findsOneWidget);
    expect(find.text('Primary use'), findsOneWidget);
    expect(find.text('Verification preference'), findsOneWidget);
    expect(find.text('Singapore'), findsOneWidget);
    expect(find.text('Additional details (optional)'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Get AI card matches'), findsOneWidget);
    expect(
      find.textContaining('Alibaba Cloud Model Studio (Bailian)'),
      findsWidgets,
    );
    expect(
      find.text('Details are not available in English yet.'),
      findsNothing,
    );

    final consent = find.byKey(const Key('card-advisor-ai-consent'));
    final consentCheckbox = find.descendant(
      of: consent,
      matching: find.byType(Checkbox),
    );
    tester.widget<Checkbox>(consentCheckbox).onChanged!(true);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('card-advisor-note')),
      'updated after consent',
    );
    await tester.pump();
    expect(tester.widget<Checkbox>(consentCheckbox).value, isFalse);
    tester.widget<Checkbox>(consentCheckbox).onChanged!(true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('card-advisor-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to use AI Card Match.'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Get AI card matches'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('country source covers ISO countries and key regions', () {
    final countries = CountryService().getAll();
    expect(countries.length, greaterThanOrEqualTo(240));
    expect(
      countries.map((country) => country.countryCode).toSet(),
      hasLength(countries.length),
    );
    expect(
      countries.map((country) => country.countryCode),
      containsAll(const ['CN', 'HK', 'MO', 'TW', 'SG', 'US', 'GB']),
    );
  });

  testWidgets('review field and secondary actions keep clear visual spacing', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final apiClient = ApiClient(baseUrl: 'https://example.test');
    addTearDown(apiClient.close);
    var loginCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CardAdvisorPage(
          repository: CardAdvisorRepository(
            apiClient,
            accessTokenProvider: () async => null,
          ),
          cards: localCardCatalog,
          onBack: () {},
          onOpenCard: (_) {},
          onLoginRequired: () => loginCount++,
        ),
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('card-advisor-submit')));
      await tester.pumpAndSettle();
    }

    final note = find.byKey(const Key('card-advisor-note'));
    final lastTag = find.text('可接受 KYC');
    expect(note, findsOneWidget);
    expect(lastTag, findsOneWidget);
    expect(
      tester.getTopLeft(note).dy - tester.getBottomLeft(lastTag).dy,
      greaterThanOrEqualTo(20),
    );

    final previous = tester.widget<OutlinedButton>(
      find.byKey(const Key('card-advisor-previous')),
    );
    expect(
      previous.style?.backgroundColor?.resolve(<WidgetState>{}),
      isNot(Colors.transparent),
    );

    final consent = find.byKey(const Key('card-advisor-ai-consent'));
    final consentCheckbox = find.descendant(
      of: consent,
      matching: find.byType(Checkbox),
    );
    tester.widget<Checkbox>(consentCheckbox).onChanged!(true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('card-advisor-submit')));
    await tester.pumpAndSettle();
    final login = tester.widget<OutlinedButton>(
      find.byKey(const Key('card-advisor-login')),
    );
    expect(
      login.style?.backgroundColor?.resolve(<WidgetState>{}),
      isNot(Colors.transparent),
    );

    await tester.tap(find.byKey(const Key('card-advisor-login')));
    expect(loginCount, 1);
  });

  testWidgets('AI result starts below the sticky header', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppColors.configure(Brightness.light);
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'advisor': {
              'summary': '已找到符合条件的公开资料。',
              'recommendations': [
                {
                  'cardId': localCardCatalog.first.id,
                  'reason': '符合主要用途。',
                  'cautions': '申请前确认官方规则。',
                },
              ],
              'nextSteps': ['查看官方申请要求。'],
              'disclaimer': '仅供信息参考。',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: CardAdvisorPage(
          repository: CardAdvisorRepository(
            apiClient,
            accessTokenProvider: () async => 'session-token',
          ),
          cards: localCardCatalog,
          onBack: () {},
          onOpenCard: (_) {},
          onLoginRequired: () {},
        ),
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('card-advisor-submit')));
      await tester.pumpAndSettle();
    }
    final consent = find.byKey(const Key('card-advisor-ai-consent'));
    tester
        .widget<Checkbox>(
          find.descendant(of: consent, matching: find.byType(Checkbox)),
        )
        .onChanged!(true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('card-advisor-submit')));
    await tester.pumpAndSettle();

    final result = find.byKey(const Key('card-advisor-result'));
    expect(result, findsOneWidget);
    final resultTop = tester.getTopLeft(result).dy;
    expect(resultTop, greaterThanOrEqualTo(80));
    expect(resultTop, lessThanOrEqualTo(86));
  });
}
