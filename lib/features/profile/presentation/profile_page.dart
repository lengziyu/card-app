import 'dart:math' as math;

import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum ProfileSection {
  cards('我的卡片', Icons.credit_card_outlined),
  services('订阅与服务', Icons.auto_awesome_outlined),
  favorites('我的收藏', Icons.star_border_rounded),
  history('浏览记录', Icons.history_rounded),
  settings('设置', Icons.settings_outlined),
  language('显示语言', Icons.language_rounded),
  help('帮助中心', Icons.help_outline_rounded),
  about('关于我们', Icons.info_outline_rounded),
  version('版本管理', Icons.system_update_alt_rounded),
  recommend('推荐卡片', Icons.credit_card_outlined),
  notifications('消息与反馈', Icons.notifications_none_rounded),
  feedback('反馈', Icons.feedback_outlined);

  const ProfileSection(this.title, this.icon);

  final String title;
  final IconData icon;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.cardCount,
    required this.favoriteCount,
    required this.historyCount,
    required this.submissionCount,
    required this.onOpenSection,
    required this.onLogin,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final int cardCount;
  final int favoriteCount;
  final int historyCount;
  final int submissionCount;
  final ValueChanged<ProfileSection> onOpenSection;
  final VoidCallback onLogin;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      key: const Key('profile-page'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 21, 24, 132 + bottomInset),
          sliver: SliverList.list(
            children: [
              _ProfileTopbar(
                isDarkMode: isDarkMode,
                onToggleTheme: onToggleTheme,
                onLogin: onLogin,
              ),
              const SizedBox(height: 18),
              _MembershipCard(
                cardCount: cardCount,
                favoriteCount: favoriteCount,
                onTap: onLogin,
              ),
              const SizedBox(height: 18),
              _MenuGroup(
                sections: const [
                  ProfileSection.language,
                  ProfileSection.help,
                  ProfileSection.about,
                ],
                onOpenSection: onOpenSection,
              ),
              const SizedBox(height: 12),
              _MenuGroup(
                sections: const [ProfileSection.settings],
                onOpenSection: onOpenSection,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTopbar extends StatelessWidget {
  const _ProfileTopbar({
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogin,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            key: const Key('profile-guest-account'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const _ProfileAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '未登录用户',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '登录后可自定义卡片并同步数据',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  key: const Key('profile-login'),
                  onPressed: onLogin,
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: isDarkMode ? '切换到浅色主题' : '切换到深色主题',
          child: IconButton(
            key: const Key('profile-theme-toggle'),
            onPressed: onToggleTheme,
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: AppColors.text,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar();

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = .32;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final wave = math.sin(_controller.value * math.pi * 2);
          return Transform.scale(
            scale: 1 + wave * .012,
            child: Container(
              key: const Key('profile-avatar'),
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.isDark
                      ? const [Color(0xA8FFFFFF), Color(0x3D9DAAFF)]
                      : const [Color(0xFFFFFFFF), Color(0x807786BB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(
                      alpha: AppColors.isDark ? .20 + wave * .025 : .14,
                    ),
                    blurRadius: 21 + wave * 2,
                    offset: const Offset(0, 9),
                  ),
                  const BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-.48 + wave * .07, -.62),
                      radius: 1.18,
                      colors: AppColors.isDark
                          ? const [
                              Color(0xFFAEB3C6),
                              Color(0xFF545B72),
                              Color(0xFF242A40),
                            ]
                          : const [
                              Color(0xFFFFFFFF),
                              Color(0xFFD7DDF2),
                              Color(0xFF8792B6),
                            ],
                      stops: const [0, .40, 1],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment(-.34 + wave * .08, -.48),
                        child: Container(
                          width: 21,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '本',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                            shadows: const [
                              Shadow(color: Color(0x38000000), blurRadius: 7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MembershipCard extends StatefulWidget {
  const _MembershipCard({
    required this.cardCount,
    required this.favoriteCount,
    required this.onTap,
  });

  final int cardCount;
  final int favoriteCount;
  final VoidCallback onTap;

  @override
  State<_MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends State<_MembershipCard>
    with TickerProviderStateMixin {
  late final AnimationController _gradientController;
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _gradientController
        ..stop()
        ..value = .38;
    } else if (!_gradientController.isAnimating &&
        !_gradientController.isCompleted) {
      _gradientController.forward();
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _press() {
    if (!MediaQuery.disableAnimationsOf(context)) _pressController.forward();
  }

  void _release() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_gradientController, _pressController]),
        builder: (context, _) {
          final progress = _gradientController.value;
          final wave = math.sin(progress * math.pi * 2);
          final press = Curves.easeOutCubic.transform(_pressController.value);
          return Transform.translate(
            offset: Offset(0, press * 2.5),
            child: Transform.scale(
              scale: 1 - press * .012,
              child: Semantics(
                button: true,
                label: '演示卡片概览，共 ${widget.cardCount} 张卡片',
                child: GestureDetector(
                  key: const Key('profile-membership-card'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onTapDown: (_) => _press(),
                  onTapUp: (_) => _release(),
                  onTapCancel: _release,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1, -.8 + wave * .12),
                        end: Alignment(1, .8 - wave * .10),
                        colors: AppColors.isDark
                            ? [
                                Color.lerp(
                                  const Color(0xFF6A7185),
                                  const Color(0xFF555E7A),
                                  (wave + 1) / 2,
                                )!,
                                const Color(0xFF303A5B),
                                const Color(0xFF1D2544),
                              ]
                            : [
                                Color.lerp(
                                  const Color(0xFFF9FBFF),
                                  const Color(0xFFE9EDFF),
                                  (wave + 1) / 2,
                                )!,
                                const Color(0xFFE4EAFF),
                                const Color(0xFFD9E1FF),
                              ],
                        stops: const [0, .52, 1],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.isDark
                              ? Color.fromRGBO(1, 5, 20, .34 - press * .12)
                              : Color.fromRGBO(78, 91, 150, .18 - press * .07),
                          blurRadius: 30 - press * 8,
                          offset: Offset(0, 15 - press * 7),
                        ),
                        BoxShadow(
                          color: AppColors.violet.withValues(alpha: .08),
                          blurRadius: 32,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const Key('profile-membership-gradient'),
                                painter: _MembershipAuroraPainter(
                                  progress: progress,
                                  dark: AppColors.isDark,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: _MembershipSweep(progress: progress),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                15,
                                20,
                                15,
                              ),
                              child: _MembershipContent(
                                cardCount: widget.cardCount,
                                favoriteCount: widget.favoriteCount,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MembershipContent extends StatelessWidget {
  const _MembershipContent({
    required this.cardCount,
    required this.favoriteCount,
  });

  final int cardCount;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.isDark ? Colors.white : const Color(0xFF1A2034);
    final muted = AppColors.isDark
        ? const Color(0xFFB7BED1)
        : const Color(0xFF64708F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '演示卡片',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '登录后管理',
                    style: TextStyle(
                      color: primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '卡片数',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$cardCount',
                  style: TextStyle(
                    color: primary,
                    fontSize: 39,
                    height: .92,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          '登录后可收藏、管理并同步你的卡片',
          style: TextStyle(
            color: muted,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        Semantics(
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: AppColors.isDark ? .08 : .56,
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: AppColors.isDark ? .23 : .72,
                ),
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: .12),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Text(
              '查看卡片',
              style: TextStyle(
                color: AppColors.isDark
                    ? const Color(0xFFE4E8FF)
                    : const Color(0xFF5367F4),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipSweep extends StatelessWidget {
  const _MembershipSweep({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1.65 + progress * 3.3, 0),
        child: Transform.rotate(
          angle: -.28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 78,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(
                        alpha: AppColors.isDark ? .10 : .26,
                      ),
                      Colors.white.withValues(alpha: 0),
                    ],
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

class _MembershipAuroraPainter extends CustomPainter {
  const _MembershipAuroraPainter({required this.progress, required this.dark});

  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final firstCenter = Offset(
      size.width * (.20 + math.sin(phase) * .10),
      size.height * (.12 + math.cos(phase) * .08),
    );
    final secondCenter = Offset(
      size.width * (.82 + math.cos(phase) * .08),
      size.height * (.78 + math.sin(phase) * .09),
    );

    void glow(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    glow(
      firstCenter,
      size.width * .58,
      dark ? const Color(0x284F79FF) : const Color(0x507C9CFF),
    );
    glow(
      secondCenter,
      size.width * .50,
      dark ? const Color(0x224D3D9F) : const Color(0x3AA996FF),
    );

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: dark ? .28 : .78),
          const Color(0x004F65FF),
          const Color(0x665A6FFF),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1),
        const Radius.circular(18.5),
      ),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MembershipAuroraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.sections, required this.onOpenSection});

  final List<ProfileSection> sections;
  final ValueChanged<ProfileSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            for (var index = 0; index < sections.length; index++)
              InkWell(
                key: Key('profile-menu-${sections[index].name}'),
                onTap: () => onOpenSection(sections[index]),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    border: index == sections.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sections[index].icon,
                        color: AppColors.text,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sections[index].title,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
