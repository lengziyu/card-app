import 'dart:ui';

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
      height: 94 + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _GlassNavigationSurface(
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
            SizedBox(width: 10),
            Semantics(
              button: true,
              selected: addSelected,
              label: '添加卡片',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('nav-add'),
                  onTap: onAdd,
                  customBorder: CircleBorder(),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: 58,
                        height: 58,
                        decoration: _glassDecoration(selected: addSelected),
                        child: Icon(
                          Icons.add_rounded,
                          color: addSelected
                              ? (AppColors.isDark
                                    ? Color(0xFFDFE5FF)
                                    : Color(0xFF4F67FF))
                              : AppColors.navIcon,
                          size: 30,
                        ),
                      ),
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

BoxDecoration _glassDecoration({bool selected = false}) {
  final selectedGradient = AppColors.isDark
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x705B6BFF), Color(0x474CA9FF)],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF5E6ECFF), Color(0xD1BED7FF)],
        );
  return BoxDecoration(
    shape: BoxShape.circle,
    gradient: selected
        ? selectedGradient
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.isDark
                ? [Color(0x24FFFFFF), Color(0x0AFFFFFF)]
                : [Color(0x9EFFFFFF), Color(0x6BF4F7FF)],
          ),
    border: Border.all(
      color: AppColors.isDark ? Color(0x1FFFFFFF) : Color(0xBDFFFFFF),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.isDark ? Color(0x3D000000) : Color(0x245A64A0),
        blurRadius: AppColors.isDark ? 32 : 38,
        offset: Offset(0, AppColors.isDark ? 16 : 20),
      ),
    ],
  );
}

class _GlassNavigationSurface extends StatelessWidget {
  const _GlassNavigationSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.isDark
                  ? [Color(0x24FFFFFF), Color(0x0AFFFFFF)]
                  : [Color(0x9EFFFFFF), Color(0x6BF4F7FF)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.isDark ? Color(0x1FFFFFFF) : Color(0xBDFFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.isDark ? Color(0x3D000000) : Color(0x245A64A0),
                blurRadius: AppColors.isDark ? 32 : 38,
                offset: Offset(0, AppColors.isDark ? 16 : 20),
              ),
            ],
          ),
          child: child,
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
    final color = selected ? AppColors.cyan : AppColors.navIcon;
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
                    : Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.isDark
                              ? [Color(0x705B6BFF), Color(0x474CA9FF)]
                              : [Color(0xF5E6ECFF), Color(0xD1BED7FF)],
                        )
                      : null,
                  boxShadow: selected && !AppColors.isDark
                      ? [
                          BoxShadow(
                            color: Color(0x1F5C73FF),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${item.label}-$selected'),
                  tween: Tween(begin: selected ? 0.86 : 1, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Duration(milliseconds: selected ? 580 : 180),
                  curve: selected ? Curves.elasticOut : Curves.easeOutCubic,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: color,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
