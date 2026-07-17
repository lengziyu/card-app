import 'package:card_app/features/add/presentation/add_card_page.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/home/presentation/mock_card.dart';
import 'package:card_app/features/home/presentation/home_page.dart';
import 'package:card_app/features/shell/widgets/aurora_background.dart';
import 'package:card_app/features/shell/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _initialMockState = String.fromEnvironment(
    'MOCK_STATE',
    defaultValue: 'cards',
  );

  int _index = 0;
  late final Set<String> _addedCardIds = _initialMockState == 'empty'
      ? <String>{}
      : mockCards.map((card) => card.id).toSet();

  void _addCard() {
    setState(() => _index = 4);
  }

  void _changeCard(MockCard card, bool added) {
    setState(() {
      if (added) {
        _addedCardIds.add(card.id);
      } else {
        _addedCardIds.remove(card.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: _body()),
              Align(
                alignment: Alignment.bottomCenter,
                child: BottomNavigation(
                  selectedIndex: _index,
                  addSelected: _index == 4,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  onAdd: _addCard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_index == 0) {
      return HomePage(
        cards: mockCards
            .where((card) => _addedCardIds.contains(card.id))
            .toList(growable: false),
        onAddCard: _addCard,
      );
    }
    if (_index == 4) {
      return AddCardPage(
        addedCardIds: _addedCardIds,
        onCardChanged: _changeCard,
      );
    }
    return _PlaceholderPage(index: _index);
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.index});

  final int index;

  static const _content = <({String title, String description, IconData icon})>[
    (title: '', description: '', icon: Icons.credit_card_rounded),
    (
      title: '市场',
      description: '第一版仅保留导航占位。\n市场列表将在下一阶段实现。',
      icon: Icons.storefront_rounded,
    ),
    (
      title: '排行榜',
      description: '第一版仅保留导航占位。\n排行内容将在下一阶段实现。',
      icon: Icons.emoji_events_rounded,
    ),
    (
      title: '我的',
      description: '第一版仅保留导航占位。\n个人中心将在后续接入账号后实现。',
      icon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = _content[index];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(content.icon, color: AppColors.cyan, size: 34),
            ),
            const SizedBox(height: 20),
            Text(content.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              content.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
