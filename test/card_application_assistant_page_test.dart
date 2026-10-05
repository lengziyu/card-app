import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/market/data/card_application_assistant_repository.dart';
import 'package:cardfi/features/market/presentation/card_application_assistant_page.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('AI card step uses the searchable card artwork picker', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    final client = ApiClient(baseUrl: 'https://example.test');
    addTearDown(client.close);
    final target = localCardCatalog[1];

    await tester.pumpWidget(
      MaterialApp(
        home: CardApplicationAssistantPage(
          repository: CardApplicationAssistantRepository(
            client,
            accessTokenProvider: () async => 'session-token',
          ),
          cards: localCardCatalog,
          enableRemoteData: true,
          onBack: () {},
          onLoginRequired: () {},
          onProRequired: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('application-assistant-card-picker')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('application-card-picker-sheet')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('application-card-picker-search')),
      target.name,
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('catalog-card-${target.id}')));
    await tester.pumpAndSettle();

    expect(find.text(target.name), findsWidgets);
    expect(
      find.byKey(const Key('application-card-picker-sheet')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('guided flow renders a sourced one-shot checklist', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    late http.Request submittedRequest;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        submittedRequest = request;
        return http.Response(
          jsonEncode({
            'assistant': {
              'summary': '已按项目文章整理准备信息。',
              'sourceMode': 'project_articles',
              'checklist': [
                {
                  'title': '确认地区',
                  'detail': '申请前核对当前开放地区。',
                  'sourceIds': ['guide-one'],
                },
              ],
              'warnings': ['公开规则可能变化。'],
              'unknowns': ['实时审核时间。'],
              'nextSteps': ['阅读完整文章。'],
              'sources': [
                {
                  'id': 'guide-one',
                  'type': 'project_article',
                  'title': '项目开卡指南',
                  'url': '',
                },
              ],
              'disclaimer': '不代办，不保证开卡成功。',
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
        localizationsDelegates: const [CountryLocalizations.delegate],
        home: CardApplicationAssistantPage(
          repository: CardApplicationAssistantRepository(
            client,
            accessTokenProvider: () async => 'session-token',
          ),
          cards: localCardCatalog,
          initialCard: localCardCatalog.first,
          enableRemoteData: true,
          onBack: () {},
          onLoginRequired: () {},
          onProRequired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('application-option-企业申请')));
    await tester.tap(find.byKey(const Key('application-assistant-submit')));
    await tester.pumpAndSettle();
    expect(find.text('企业注册国家或地区是？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-residence-other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Singapore');
    await tester.pump();
    await tester.tap(find.text('Singapore').last);
    await tester.pumpAndSettle();

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const Key('application-assistant-submit')));
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const Key('application-assistant-question')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('application-assistant-question')),
      '请整理成准备清单',
    );
    final consent = find.byKey(const Key('application-assistant-ai-consent'));
    final consentCheckbox = find.descendant(
      of: consent,
      matching: find.byType(Checkbox),
    );
    tester.widget<Checkbox>(consentCheckbox).onChanged!(true);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('application-assistant-question')),
      'changed after consent',
    );
    await tester.pump();
    expect(tester.widget<Checkbox>(consentCheckbox).value, isFalse);
    tester.widget<Checkbox>(consentCheckbox).onChanged!(true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('application-assistant-submit')));
    await tester.pumpAndSettle();

    final resultTop = tester
        .getTopLeft(find.byKey(const Key('application-assistant-result')))
        .dy;
    expect(resultTop, greaterThanOrEqualTo(80));
    expect(resultTop, lessThanOrEqualTo(86));

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('application-assistant-result')),
      findsOneWidget,
    );
    expect(find.text('项目文章'), findsWidgets);
    expect(find.text('项目开卡指南'), findsOneWidget);
    expect(find.text('不代办，不保证开卡成功。'), findsOneWidget);
    final submittedBody =
        jsonDecode(submittedRequest.body) as Map<String, dynamic>;
    expect(submittedBody['profile']['applicantType'], '企业申请');
    expect(submittedBody['profile']['residence'], 'Singapore');
    expect(submittedBody['profile']['residenceCountryCode'], 'SG');
    expect(submittedBody['aiDataConsent'], {
      'granted': true,
      'version': '2026-08-18',
      'provider': 'alibaba-cloud-bailian',
    });
    expect(tester.takeException(), isNull);
  });
}
