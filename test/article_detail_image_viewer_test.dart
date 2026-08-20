import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/ranking/domain/local_article.dart';
import 'package:cardfi/features/ranking/presentation/article_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'community tip images open, zoom, and move to previous or next image',
    (tester) async {
      AppColors.configure(Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArticleDetailPage(
              article: _article,
              cards: const [],
              favorite: false,
              onBack: () {},
              onOpenCard: (_) {},
              onFavoriteChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('article-cover-image')), findsOneWidget);

      await tester.tap(find.byKey(const Key('article-cover-image')));
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.byKey(const Key('article-image-viewer')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      final interactive = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first,
      );
      expect(interactive.minScale, 1);
      expect(interactive.maxScale, 4);

      final imageCenter = tester.getCenter(
        find.byType(InteractiveViewer).first,
      );
      final firstFinger = await tester.createGesture(pointer: 1);
      final secondFinger = await tester.createGesture(pointer: 2);
      await firstFinger.down(imageCenter - const Offset(35, 0));
      await secondFinger.down(imageCenter + const Offset(35, 0));
      await tester.pump();
      await firstFinger.moveTo(imageCenter - const Offset(100, 0));
      await secondFinger.moveTo(imageCenter + const Offset(100, 0));
      await tester.pump();
      await firstFinger.up();
      await secondFinger.up();
      await tester.pump();
      expect(
        interactive.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );

      await tester.tap(find.byKey(const Key('article-image-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('article-image-previous')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('article-image-pages')),
        const Offset(-500, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('article-image-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const Key('article-image-viewer')), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('article-inline-image-1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('article-inline-image-1')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('article-inline-image-1')));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('image viewer controls fit a narrow screen with large text', (
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
            body: ArticleDetailPage(
              article: _article,
              cards: const [],
              favorite: false,
              onBack: () {},
              onOpenCard: (_) {},
              onFavoriteChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('article-cover-image')));
    await tester.pump();

    expect(find.byKey(const Key('article-image-viewer')), findsOneWidget);
    expect(find.byKey(const Key('article-image-previous')), findsOneWidget);
    expect(find.byKey(const Key('article-image-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _article = LocalArticle(
  id: 'tip-with-images',
  category: '卡友技巧',
  title: '带图技巧',
  summary: '通过图片说明操作步骤。',
  body: [],
  markdown: '''
## 操作步骤

![第一步](https://example.test/tip-step-1.webp)

![第二步](https://example.test/tip-step-2.webp)
''',
  tags: ['卡友经验'],
  publishedLabel: '2026-07-26',
  relatedCardIds: [],
  coverImageUrl: 'https://example.test/tip-cover.webp',
  isCommunityTip: true,
);
