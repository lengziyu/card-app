import 'dart:math' as math;
import 'dart:ui';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/home/controllers/card_stack_controller.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/home/widgets/card_stack_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.cards,
    required this.cardHeightScale,
    required this.displayMode,
    required this.onAddCard,
    required this.onOpenCard,
    required this.onCardHeightScaleChanged,
    required this.onReorderCards,
    required this.onDisplayModeChanged,
    required this.onToggleNavigation,
    super.key,
  });

  final List<CardSummary> cards;
  final double cardHeightScale;
  final HomeCardDisplayMode displayMode;
  final VoidCallback onAddCard;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<double> onCardHeightScaleChanged;
  final ValueChanged<List<String>> onReorderCards;
  final ValueChanged<HomeCardDisplayMode> onDisplayModeChanged;
  final VoidCallback onToggleNavigation;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final CardStackController _cardController;
  bool _modeMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _cardController = CardStackController(
      vsync: this,
      cardIds: widget.cards.map((card) => card.id).toList(growable: false),
      initialMode: widget.displayMode,
      initialRevealScale: widget.cardHeightScale / homeCardStackDefaultScale,
    );
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cardController.syncCards(
      widget.cards.map((card) => card.id).toList(growable: false),
    );
    _cardController.setMode(widget.displayMode);
    if (oldWidget.cardHeightScale != widget.cardHeightScale) {
      _cardController.setRevealScale(
        widget.cardHeightScale / homeCardStackDefaultScale,
        animate: true,
      );
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        const headerExtent = 94.0;
        // Every display mode remains inside the regular home surface. Keep a
        // generous gap below the fixed header and always reserve the shell's
        // bottom navigation area.
        const cardSceneTop = 116.0;
        final navigationClearance = 96.0 + bottomInset;
        final availableHeight = math.max(
          280.0,
          constraints.maxHeight - headerExtent - navigationClearance,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                key: const Key('home-card-scroll-view'),
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      cardSceneTop,
                      0,
                      navigationClearance,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: widget.cards.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: _EmptyState(key: ValueKey('empty-state')),
                            )
                          : CardStackView(
                              cards: widget.cards,
                              controller: _cardController,
                              availableHeight: availableHeight,
                              heightScale: widget.cardHeightScale,
                              onHeightScaleChanged:
                                  widget.onCardHeightScaleChanged,
                              onReorderCards: widget.onReorderCards,
                              onOpenCard: widget.onOpenCard,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              left: 18,
              right: 18,
              child: _HomeHeader(
                displayMode: _cardController.mode,
                menuOpen: _modeMenuOpen,
                onModePressed: () =>
                    setState(() => _modeMenuOpen = !_modeMenuOpen),
                onAddCard: widget.onAddCard,
                onToggleNavigation: widget.onToggleNavigation,
              ),
            ),
            if (_modeMenuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('home-mode-menu-barrier'),
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _modeMenuOpen = false),
                ),
              ),
              Positioned(
                top: 74,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 196,
                    child: _ModeMenu(
                      selected: _cardController.mode,
                      onSelected: _selectMode,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _selectMode(HomeCardDisplayMode mode) {
    setState(() => _modeMenuOpen = false);
    if (mode == _cardController.mode) return;
    _cardController.setMode(mode);
    HapticFeedback.mediumImpact();
    widget.onDisplayModeChanged(mode);
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayMode,
    required this.menuOpen,
    required this.onModePressed,
    required this.onAddCard,
    required this.onToggleNavigation,
  });

  final HomeCardDisplayMode displayMode;
  final bool menuOpen;
  final VoidCallback onModePressed;
  final VoidCallback onAddCard;
  final VoidCallback onToggleNavigation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final actionSize = compact ? 40.0 : 44.0;
        final gap = compact ? 5.0 : 7.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '切换底部导航显示',
                child: GestureDetector(
                  key: const Key('home-title-toggle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleNavigation,
                  child: Text(
                    '卡包',
                    key: const Key('home-title'),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _HeaderAction(
              key: const Key('home-mode-button'),
              tooltip: '切换卡片模式，当前${displayMode.label}',
              selected: menuOpen,
              onTap: onModePressed,
              size: actionSize,
              icon: Icon(_modeIcon(displayMode)),
            ),
            SizedBox(width: gap),
            _HeaderAction(
              key: const Key('home-add-button'),
              tooltip: '添加卡片',
              onTap: onAddCard,
              size: actionSize,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        );
      },
    );
  }
}

IconData _modeIcon(CardStackMode mode) => switch (mode) {
  CardStackMode.stack => Icons.layers_outlined,
  CardStackMode.focus => Icons.center_focus_strong_rounded,
  CardStackMode.wallet => Icons.account_balance_wallet_outlined,
};

class _HeaderAction extends StatefulWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.size,
    this.selected = false,
    super.key,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;
  final double size;
  final bool selected;

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? .92 : 1,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? AppColors.selectedWash
                        : AppColors.glassStrong.withValues(alpha: .86),
                    border: Border.all(
                      color: widget.selected
                          ? AppColors.cyan.withValues(alpha: .34)
                          : Colors.white.withValues(
                              alpha: AppColors.isDark ? .14 : .72,
                            ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.isDark
                            ? const Color(0x26091028)
                            : const Color(0x1763729F),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      color: AppColors.text,
                      size: widget.size * .53,
                    ),
                    child: Center(child: widget.icon),
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

class _ModeMenu extends StatelessWidget {
  const _ModeMenu({required this.selected, required this.onSelected});

  final HomeCardDisplayMode selected;
  final ValueChanged<HomeCardDisplayMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(
          scale: .92 + .08 * value,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: DecoratedBox(
        key: const Key('home-mode-menu'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDark
                  ? const Color(0x30030918)
                  : const Color(0x1E56658D),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.isDark
                    ? const Color(0x7330384C)
                    : const Color(0x8CFFFFFF),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: AppColors.isDark ? .2 : .68,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in CardStackMode.values) ...[
                      _ModeMenuRow(
                        mode: mode,
                        selected: selected == mode,
                        onTap: () => onSelected(mode),
                      ),
                      if (mode != CardStackMode.values.last)
                        Divider(
                          height: 1,
                          indent: 43,
                          endIndent: 8,
                          color: Colors.white.withValues(
                            alpha: AppColors.isDark ? .09 : .42,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeMenuRow extends StatelessWidget {
  const _ModeMenuRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final HomeCardDisplayMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: mode.label,
      child: InkWell(
        key: Key('home-mode-${mode.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          height: 48,
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.selectedWash.withValues(
                    alpha: AppColors.isDark ? .28 : .2,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.cyan.withValues(alpha: .16)
                      : Colors.white.withValues(
                          alpha: AppColors.isDark ? .055 : .4,
                        ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _modeIcon(mode),
                  color: selected ? AppColors.cyan : AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  mode.label,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.mint,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark
                ? const Color(0x35081124)
                : const Color(0x166270A4),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.wallet_outlined, color: AppColors.textMuted, size: 30),
          const SizedBox(height: 12),
          Text(
            '还没有卡片',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '去市场或添加页选择第一张卡片',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
