import 'dart:convert';

import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/data/local_card_catalog.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/ranking/presentation/tip_submission_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('tip submission sends one free-form experience with a card', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    LocalSubmissionDraft? submitted;
    var pickerLimit = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TipSubmissionPage(
            cards: [localCardCatalog.first],
            onBack: () {},
            onSubmit: (draft) async => submitted = draft,
            onOpenContributions: () {},
            pickImages: (limit) async {
              pickerLimit = limit;
              return [
                XFile.fromData(
                  base64Decode(_onePixelPng),
                  path: 'step-1.png',
                  name: 'step-1.png',
                  mimeType: 'image/png',
                ),
                XFile.fromData(
                  base64Decode(_onePixelPng),
                  path: 'step-2.png',
                  name: 'step-2.png',
                  mimeType: 'image/png',
                ),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('tip-experience')),
              matching: find.byType(TextField),
            ),
          )
          .maxLength,
      2000,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('tip-title')),
              matching: find.byType(TextField),
            ),
          )
          .maxLength,
      80,
    );
    await tester.tap(find.byKey(const Key('tip-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tip-card-picker-sheet')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('tip-card-picker-search')),
      localCardCatalog.first.issuer,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tip-title')), '跨境消费前如何核对完整费用');
    await tester.enterText(
      find.byKey(const Key('tip-experience')),
      '我在跨境消费前会先打开官方费用页面，把充值、换汇、消费和退款可能产生的费用放在一起核对。'
      '实际使用时也会在付款前再次确认页面显示的币种和金额，避免只看某一项免费说明。',
    );
    expect(find.byKey(const Key('tip-title')), findsOneWidget);
    expect(find.byKey(const Key('tip-steps')), findsNothing);
    expect(find.byKey(const Key('tip-conditions')), findsNothing);
    expect(find.byKey(const Key('tip-risks')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('tip-add-images')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tip-add-images')));
    await tester.pumpAndSettle();
    expect(pickerLimit, 3);
    expect(find.byKey(const ValueKey('tip-image-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tip-image-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tip-remove-image-0')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tip-safe-confirmation')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tip-submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.category, LocalSubmissionCategory.tip);
    expect(submitted!.cardId, localCardCatalog.first.id);
    expect(submitted!.subject, '跨境消费前如何核对完整费用');
    expect(submitted!.description, contains('充值、换汇、消费和退款'));
    expect(submitted!.images, hasLength(1));
    expect(submitted!.images.single.fileName, 'step-2.png');
    expect(submitted!.publishAnonymously, isTrue);
    expect(find.text('技巧已提交审核'), findsOneWidget);
    expect(find.byKey(const Key('tip-open-contributions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tip submission supports narrow screens and large text', (
    tester,
  ) async {
    AppColors.configure(Brightness.light);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.4),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: TipSubmissionPage(
              cards: [localCardCatalog.first],
              onBack: () {},
              onSubmit: (_) async {},
              onOpenContributions: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();

    expect(find.byKey(const Key('tip-submission-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '/x8AAusB9Y9Z4WQAAAAASUVORK5CYII=';
