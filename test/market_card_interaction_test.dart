import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/theme/app_theme.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/market/presentation/market_page.dart';
import 'package:card_app/features/market/widgets/market_card_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppColors.configure(Brightness.light));

  testWidgets('market row presses subtly and reports its artwork rect', (
    tester,
  ) async {
    CardSummary? openedCard;
    Rect? sourceRect;
    Rect? sourceTitleRect;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (card, geometry) {
            openedCard = card;
            sourceRect = geometry.artworkRect;
            sourceTitleRect = geometry.titleRect;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(Key('catalog-card-${localCardCatalog.first.id}'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('pressable-scale-transform')),
          )
          .scale,
      .985,
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(openedCard?.id, localCardCatalog.first.id);
    expect(sourceRect?.size, const Size(112, 70));
    expect(sourceRect, isNotNull);
    expect(sourceTitleRect, isNotNull);
  });

  testWidgets('vertical scrolling cancels the market card tap', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog.take(8).toList()),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (_, _) => openCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(openCount, 0);
  });

  testWidgets('global accounts have an article-style market group', (
    tester,
  ) async {
    CatalogCardSourceGeometry? geometry;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenCardTransition: (_, value) => geometry = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final globalTab = find.byKey(const Key('market-group-global-account'));
    await tester.tap(globalTab);
    await tester.pumpAndSettle();

    final account = find.byKey(const Key('global-account-card-wise-account'));
    expect(account, findsOneWidget);
    expect(
      tester.getTopLeft(account).dy - tester.getBottomLeft(globalTab).dy,
      greaterThanOrEqualTo(12),
    );
    expect(
      find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      findsNothing,
    );
    final cover = find.descendant(
      of: account,
      matching: find.byType(AspectRatio),
    );
    expect(cover, findsOneWidget);
    final coverSize = tester.getSize(cover);
    expect(coverSize.width / coverSize.height, closeTo(16 / 9, .01));

    await tester.tap(account);
    await tester.pump(const Duration(milliseconds: 120));
    expect(geometry, isNotNull);
    expect(
      geometry!.artworkRect.width / geometry!.artworkRect.height,
      closeTo(16 / 9, .01),
    );
  });

  testWidgets('global account article card supports the dark theme', (
    tester,
  ) async {
    AppColors.configure(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MarketPage(
          repository: _CardsRepository(localCardCatalog),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-group-global-account')));
    await tester.pumpAndSettle();

    final account = find.byKey(const Key('global-account-card-wise-account'));
    expect(account, findsOneWidget);
    expect(find.text('仅供资料浏览 · 不加入本机卡包'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the market row at full scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(Key('catalog-card-${localCardCatalog.first.id}')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('pressable-scale-transform')),
          )
          .scale,
      1,
    );
    await gesture.cancel();
  });

  testWidgets('market AI action is available and opens the supplied flow', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketPage(
          repository: _CardsRepository([localCardCatalog.first]),
          onSearch: () {},
          onOpenCard: (_) {},
          onOpenAiAdvisor: () => openCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-ai-advisor-button')));
    expect(openCount, 1);
  });

  testWidgets('shared card flight reaches the detail artwork bounds', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 360),
    );
    addTearDown(controller.dispose);
    const source = Rect.fromLTWH(24, 210, 112, 70);
    const target = Rect.fromLTWH(24, 150, 342, 216);
    const sourceTitle = Rect.fromLTWH(153, 230, 90, 18);
    const targetTitle = Rect.fromLTWH(24, 391, 342, 32);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MarketCardTransition(
                card: localCardCatalog.first,
                animation: controller,
                sourceRect: source,
                targetRect: target,
                sourceTitleRect: sourceTitle,
                targetTitleRect: targetTitle,
              ),
            ],
          ),
        ),
      ),
    );
    controller.value = 1;
    await tester.pump();

    final positioned = tester.widget<Positioned>(
      find.byKey(const Key('market-card-flight-position')),
    );
    expect(positioned.left, target.left);
    expect(positioned.top, target.top);
    expect(positioned.width, target.width);
    expect(positioned.height, target.height);
    final titlePositioned = tester.widget<Positioned>(
      find.byKey(const Key('market-card-flight-title-position')),
    );
    expect(titlePositioned.left, targetTitle.left);
    expect(titlePositioned.top, targetTitle.top);
  });
}

class _CardsRepository implements CardCatalogRepository {
  const _CardsRepository(this.cards);

  final List<CardSummary> cards;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async => cards;
}
