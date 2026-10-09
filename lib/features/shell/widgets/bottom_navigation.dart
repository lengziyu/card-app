import 'dart:ui';

import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({
    required this.selectedIndex,
    required this.addSelected,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.onAnalyzeBill,
    super.key,
  });

  final int selectedIndex;
  final bool addSelected;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAdd;
  final VoidCallback onAnalyzeBill;

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  bool _quickMenuOpen = false;

  static const _items = <({AppIconPair icons, String label})>[
    (
      icons: AppIconPair(regular: AppIcons.cards, fill: AppIcons.cardsSelected),
      label: '我的卡片',
    ),
    (
      icons: AppIconPair(
        regular: AppIcons.market,
        fill: AppIcons.marketSelected,
      ),
      label: '市场',
    ),
    (
      icons: AppIconPair(
        regular: AppIcons.ranking,
        fill: AppIcons.rankingSelected,
      ),
      label: '排行',
    ),
    (
      icons: AppIconPair(
        regular: AppIcons.profile,
        fill: AppIcons.profileSelected,
      ),
      label: '我的',
    ),
  ];

  void _closeQuickMenu() {
    if (_quickMenuOpen) {
      setState(() => _quickMenuOpen = false);
    }
  }

  void _selectDestination(int index) {
    _closeQuickMenu();
    widget.onDestinationSelected(index);
  }

  void _runQuickAction(VoidCallback action) {
    _closeQuickMenu();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final addActive = widget.addSelected || _quickMenuOpen;
    return SizedBox(
      // The extra transparent area keeps the expanding shortcuts tappable
      // instead of only painting them outside the navigation hit-test bounds.
      height: 154 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8 + bottomInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _GlassNavigationSurface(
                      child: Row(
                        children: [
                          _NavItem(
                            item: _items[0],
                            selected: widget.selectedIndex == 0,
                            onTap: () => _selectDestination(0),
                          ),
                          _NavItem(
                            item: _items[1],
                            selected: widget.selectedIndex == 1,
                            onTap: () => _selectDestination(1),
                          ),
                          _NavItem(
                            item: _items[2],
                            selected: widget.selectedIndex == 2,
                            onTap: () => _selectDestination(2),
                          ),
                          _NavItem(
                            item: _items[3],
                            selected: widget.selectedIndex == 3,
                            onTap: () => _selectDestination(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Semantics(
                    button: true,
                    selected: addActive,
                    label: context.tr('添加卡片'),
                    child: MotionPressEffect(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('nav-add'),
                          onTap: () =>
                              setState(() => _quickMenuOpen = !_quickMenuOpen),
                          customBorder: CircleBorder(),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                              child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : MotionTokens.stateChange,
                                curve: MotionTokens.standardEnter,
                                width: 58,
                                height: 58,
                                decoration: _glassDecoration(
                                  selected: addActive,
                                ),
                                child: Center(
                                  child: AnimatedRotation(
                                    turns: _quickMenuOpen ? .125 : 0,
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : MotionTokens.stateChange,
                                    curve: MotionTokens.standardEnter,
                                    child: Icon(
                                      AppIcons.add,
                                      color: AppColors.isDark
                                          ? Colors.white
                                          : (addActive
                                                ? const Color(0xFF4F67FF)
                                                : AppColors.navIcon),
                                      size: 30,
                                    ),
                                  ),
                                ),
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
          ),
          Positioned(
            right: 18,
            bottom: 57 + bottomInset,
            child: _QuickActionMenu(
              open: _quickMenuOpen,
              onAddCard: () => _runQuickAction(widget.onAdd),
              onAnalyzeBill: () => _runQuickAction(widget.onAnalyzeBill),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionMenu extends StatelessWidget {
  const _QuickActionMenu({
    required this.open,
    required this.onAddCard,
    required this.onAnalyzeBill,
  });

  final bool open;
  final VoidCallback onAddCard;
  final VoidCallback onAnalyzeBill;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        child: ExcludeFocus(
          excluding: !open,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: open ? 1 : 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : (open ? MotionTokens.tabSwitch : MotionTokens.stateChange),
            builder: (context, progress, _) => SizedBox(
              width: 128,
              height: 95,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 70,
                    bottom: 0,
                    child: _QuickMenuButton(
                      actionKey: const Key('nav-quick-bill'),
                      progress: Interval(
                        .12,
                        1,
                        curve: Curves.easeInOutCubic,
                      ).transform(progress),
                      closedOffset: const Offset(70, 49),
                      tooltip: context.tr('拍照识别账单'),
                      icon: AppIcons.bill,
                      onTap: onAnalyzeBill,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 37,
                    child: _QuickMenuButton(
                      actionKey: const Key('nav-quick-add-card'),
                      progress: Curves.easeInOutCubic.transform(progress),
                      closedOffset: const Offset(0, 86),
                      tooltip: context.tr('添加卡片'),
                      icon: AppIcons.cardsSelected,
                      onTap: onAddCard,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickMenuButton extends StatelessWidget {
  const _QuickMenuButton({
    required this.actionKey,
    required this.progress,
    required this.closedOffset,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final Key actionKey;
  final double progress;
  final Offset closedOffset;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Transform.translate(
        offset: closedOffset * (1 - progress),
        child: Transform.scale(
          scale: .86 + .14 * progress,
          child: Opacity(
            opacity: progress,
            child: MotionPressEffect(
              child: Tooltip(
                message: tooltip,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: actionKey,
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: _quickMenuDecoration(),
                      child: Icon(
                        icon,
                        size: 23,
                        color: AppColors.isDark
                            ? Colors.white
                            : const Color(0xFF4F67FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _quickMenuDecoration() => BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xF21C2438), Color(0xE6111728)]
        : const [Color(0xF7FFFFFF), Color(0xEAF6F8FF)],
  ),
  border: Border.all(
    color: AppColors.isDark ? const Color(0x26FFFFFF) : Colors.white,
  ),
  boxShadow: [
    BoxShadow(
      color: AppColors.isDark
          ? const Color(0x82000000)
          : const Color(0x505A64A0),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: AppColors.isDark
          ? const Color(0x36000000)
          : const Color(0x2A5A64A0),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ],
);

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
          key: const Key('bottom-navigation-surface'),
          height: 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.isDark
                  ? [Color(0xB8141A2A), Color(0xA30B101E)]
                  : [Color(0x9EFFFFFF), Color(0x6BF4F7FF)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.isDark ? Color(0x3DFFFFFF) : Color(0xBDFFFFFF),
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

  final ({AppIconPair icons, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.isDark
        ? Colors.white
        : (selected ? AppColors.cyan : const Color(0xFF46536E));
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: context.tr(item.label),
        child: MotionPressEffect(
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
                      : MotionTokens.stateChange,
                  curve: MotionTokens.standardEnter,
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
                  child: Center(
                    child: _NavigationStateIcon(
                      icon: selected ? item.icons.fill : item.icons.regular,
                      color: color,
                      selected: selected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationStateIcon extends StatefulWidget {
  const _NavigationStateIcon({
    required this.icon,
    required this.color,
    required this.selected,
  });

  final IconData icon;
  final Color color;
  final bool selected;

  @override
  State<_NavigationStateIcon> createState() => _NavigationStateIconState();
}

class _NavigationStateIconState extends State<_NavigationStateIcon>
    with SingleTickerProviderStateMixin {
  static const _motionDuration = Duration(milliseconds: 360);

  late final AnimationController _controller;
  IconData? _previousIcon;
  Color? _previousColor;
  bool _previousSelected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _motionDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _NavigationStateIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;

    _previousIcon = oldWidget.icon;
    _previousColor = oldWidget.color;
    _previousSelected = oldWidget.selected;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return _NavigationGlyph(
        icon: widget.icon,
        color: widget.color,
        selected: widget.selected,
      );
    }

    return SizedBox(
      width: 30,
      height: 30,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final enter = Curves.easeOutBack.transform(progress);
          final fadeIn = Curves.easeOut.transform(progress).clamp(0.0, 1.0);
          final fadeOut = (1 - Curves.easeIn.transform(progress)).clamp(
            0.0,
            1.0,
          );
          final previousOffset = _previousSelected ? -6.0 : 6.0;
          final currentOffset = widget.selected ? 6.0 : -6.0;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_previousIcon != null && progress < 1)
                Opacity(
                  opacity: fadeOut,
                  child: Transform.translate(
                    offset: Offset(0, previousOffset * progress),
                    child: Transform.scale(
                      scale: lerpDouble(1, .46, progress)!,
                      child: _NavigationGlyph(
                        icon: _previousIcon!,
                        color: _previousColor!,
                        selected: _previousSelected,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: fadeIn,
                child: Transform.translate(
                  offset: Offset(0, currentOffset * (1 - fadeIn)),
                  child: Transform.scale(
                    scale: lerpDouble(.46, 1, enter)!,
                    child: _NavigationGlyph(
                      icon: widget.icon,
                      color: widget.color,
                      selected: widget.selected,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavigationGlyph extends StatelessWidget {
  const _NavigationGlyph({
    required this.icon,
    required this.color,
    required this.selected,
  });

  final IconData icon;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    key: ValueKey('navigation-glyph-$selected-${icon.codePoint}'),
    color: color,
    size: selected ? 26 : 24,
  );
}
