import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    required this.selectedIndex,
    required this.addSelected,
    required this.onDestinationSelected,
    required this.onAdd,
    super.key,
  });

  final int selectedIndex;
  final bool addSelected;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAdd;

  static const _items =
      <({IconData icon, IconData selectedIcon, String label})>[
        (
          icon: Icons.credit_card_outlined,
          selectedIcon: Icons.credit_card_rounded,
          label: '我的卡片',
        ),
        (
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront_rounded,
          label: '市场',
        ),
        (
          icon: Icons.emoji_events_outlined,
          selectedIcon: Icons.emoji_events_rounded,
          label: '排行',
        ),
        (
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: '我的',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 84 + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xE6131B2D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      item: _items[0],
                      selected: selectedIndex == 0,
                      onTap: () => onDestinationSelected(0),
                    ),
                    _NavItem(
                      item: _items[1],
                      selected: selectedIndex == 1,
                      onTap: () => onDestinationSelected(1),
                    ),
                    _NavItem(
                      item: _items[2],
                      selected: selectedIndex == 2,
                      onTap: () => onDestinationSelected(2),
                    ),
                    _NavItem(
                      item: _items[3],
                      selected: selectedIndex == 3,
                      onTap: () => onDestinationSelected(3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              selected: addSelected,
              label: '添加卡片',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('nav-add'),
                  onTap: onAdd,
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: addSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.cyan, AppColors.violet],
                            )
                          : const LinearGradient(
                              colors: [Color(0xE61A2336), Color(0xE6131B2D)],
                            ),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x6653D8FF),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: addSelected ? Colors.white : AppColors.textMuted,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selectedIcon, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.cyan : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkWell(
          key: Key('nav-${item.label}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0x706B78FF), Color(0x5053D8FF)],
                        )
                      : null,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
