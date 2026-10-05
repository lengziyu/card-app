import 'dart:math' as math;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/pro/widgets/pro_crown_badge.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' hide Text;

enum ProfileSection {
  pro('Pro 会员', Icons.workspace_premium_outlined),
  services('订阅与服务', Icons.auto_awesome_outlined),
  favorites('我的收藏', Icons.star_border_rounded),
  bills('我的账单', Icons.receipt_long_outlined),
  history('浏览记录', Icons.history_rounded),
  settings('设置', Icons.settings_outlined),
  language('显示语言', Icons.language_rounded),
  usageGuide('使用说明', Icons.menu_book_outlined),
  help('帮助中心', Icons.help_outline_rounded),
  about('关于我们', Icons.info_outline_rounded),
  privacy('隐私政策', Icons.privacy_tip_outlined),
  terms('用户协议', Icons.gavel_outlined),
  accountDeletion('账号删除说明', Icons.no_accounts_outlined),
  support('联系支持', Icons.support_agent_outlined),
  version('版本管理', Icons.system_update_alt_rounded),
  recommend('推荐卡片', Icons.credit_card_outlined),
  notifications('消息与反馈', Icons.notifications_none_rounded),
  reminders('提醒配置', Icons.notifications_active_outlined),
  feedback('反馈', Icons.feedback_outlined),
  referral('邀请好友得会员', Icons.card_giftcard_outlined),
  motionLab('动效调试', Icons.auto_awesome_motion_rounded);

  const ProfileSection(this.title, this.icon);

  final String title;
  final IconData icon;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.onOpenSection,
    required this.onLogin,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.isPro = false,
    this.authUser,
    this.cardCount = 0,
    this.favoriteCount = 0,
    this.billHistoryEnabled = false,
    super.key,
  });

  final ValueChanged<ProfileSection> onOpenSection;
  final VoidCallback onLogin;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool isPro;
  final AuthUser? authUser;
  final int cardCount;
  final int favoriteCount;
  final bool billHistoryEnabled;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Preview entitlement is useful for exercising Pro flows, but a guest
    // must never be presented as a paid member. Membership visuals require a
    // verified account, just like the entitlement itself.
    final hasProMembership = isPro && authUser?.emailVerified == true;
    void openSection(ProfileSection section) {
      const accountSections = {
        ProfileSection.favorites,
        ProfileSection.bills,
        ProfileSection.history,
        ProfileSection.notifications,
        ProfileSection.referral,
      };
      if (accountSections.contains(section) &&
          authUser?.emailVerified != true) {
        onLogin();
        return;
      }
      onOpenSection(section);
    }

    return CustomScrollView(
      key: const Key('profile-page'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 132 + bottomInset),
          sliver: SliverList.list(
            children: [
              _ProfileTopbar(
                isDarkMode: isDarkMode,
                onToggleTheme: onToggleTheme,
                authUser: authUser,
                isPro: hasProMembership,
              ),
              const SizedBox(height: 18),
              _MembershipCard(
                authUser: authUser,
                onTap: authUser?.emailVerified == true ? null : onLogin,
                cardCount: cardCount,
                favoriteCount: favoriteCount,
                isPro: hasProMembership,
              ),
              const SizedBox(height: 14),
              _MenuGroup(
                sections: [
                  ProfileSection.pro,
                  ProfileSection.favorites,
                  if (billHistoryEnabled) ProfileSection.bills,
                  ProfileSection.history,
                  if (authUser?.emailVerified == true)
                    ProfileSection.notifications,
                ],
                onOpenSection: openSection,
                proActive: hasProMembership,
              ),
              const SizedBox(height: 12),
              _MenuGroup(
                sections: const [
                  ProfileSection.language,
                  ProfileSection.settings,
                ],
                onOpenSection: openSection,
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
    required this.authUser,
    required this.isPro,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AuthUser? authUser;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Padding(
            key: const Key('profile-guest-account'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                _ProfileAvatar(
                  initial: authUser?.initial ?? 'B',
                  avatarUrl: authUser?.avatarUrl,
                  isPro: isPro,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: material.Text(
                              authUser?.profileName ?? '未登录用户',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPro
                                    ? (dark
                                          ? const Color(0xFFFFD580)
                                          : const Color(0xFFB66A0C))
                                    : AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      material.Text(
                        authUser == null
                            ? context.tr('当前未登录 · 登录后同步卡片与收藏')
                            : authUser!.emailVerified
                            ? '${authUser!.handle} · ${context.tr('可管理卡片与收藏')}'
                            : '${authUser!.handle} · ${context.tr('邮箱待验证')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? const Color(0xFFAEB7CB)
                              : const Color(0xFF8A92A5),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: isDarkMode ? '切换到浅色主题' : '切换到深色主题',
          child: MotionPressEffect(
            child: IconButton(
              key: const Key('profile-theme-toggle'),
              onPressed: () {
                AppHaptics.selection();
                onToggleTheme();
              },
              icon: MotionStateIcon(
                stateKey: isDarkMode,
                child: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: dark
                      ? const Color(0xFFF5F7FF)
                      : const Color(0xFF10131D),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initial,
    required this.isPro,
    this.avatarUrl,
  });

  final String initial;
  final bool isPro;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Container(
        key: const Key('profile-avatar'),
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPro
                ? (dark
                      ? const [Color(0xFF76501D), Color(0xFF302437)]
                      : const [Color(0xFFFFE9AC), Color(0xFFF7C967)])
                : dark
                ? const [Color(0xFF454B61), Color(0xFF252A40)]
                : const [Color(0xF7FFFFFF), Color(0xEBF5FAFF)],
          ),
          border: Border.all(
            color: isPro
                ? const Color(0xFFF4A51C).withValues(alpha: dark ? .72 : .88)
                : dark
                ? const Color(0x885B637B)
                : const Color(0xE6FFFFFF),
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? const Color.fromRGBO(0, 0, 0, .20)
                  : const Color.fromRGBO(98, 110, 174, .08),
              blurRadius: dark ? 22 : 18,
              offset: Offset(0, dark ? 9 : 7),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            _AvatarInitial(initial: initial, isPro: isPro, dark: dark),
            if (avatarUrl?.isNotEmpty == true)
              ClipOval(
                child: Image.network(
                  avatarUrl!,
                  key: ValueKey('profile-avatar-image-$avatarUrl'),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            if (isPro)
              Positioned(
                top: -10,
                right: -6,
                child: Transform.rotate(
                  angle: .18,
                  child: Container(
                    width: 25,
                    height: 23,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF211B35) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF4A51C).withValues(alpha: .74),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF4A51C).withValues(alpha: .34),
                          blurRadius: 9,
                        ),
                      ],
                    ),
                    child: const ProCrownBadge(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({
    required this.initial,
    required this.isPro,
    required this.dark,
  });

  final String initial;
  final bool isPro;
  final bool dark;

  @override
  Widget build(BuildContext context) => Center(
    child: material.Text(
      initial,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isPro
            ? const Color(0xFF39240D)
            : dark
            ? const Color(0xFFF2F5FF)
            : const Color(0xFF10131B),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -.4,
      ),
    ),
  );
}

class _MembershipCard extends StatefulWidget {
  const _MembershipCard({
    required this.authUser,
    required this.onTap,
    required this.cardCount,
    required this.favoriteCount,
    required this.isPro,
  });

  final AuthUser? authUser;
  final VoidCallback? onTap;
  final int cardCount;
  final int favoriteCount;
  final bool isPro;

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
      duration: MotionTokens.press,
      reverseDuration: MotionTokens.stateChange,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                button: widget.onTap != null,
                label: widget.authUser == null ? '登录后计算卡片等级' : '账号卡片等级',
                child: GestureDetector(
                  key: const Key('profile-membership-card'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onTapDown: (_) => _press(),
                  onTapUp: (_) => _release(),
                  onTapCancel: _release,
                  child: DecoratedBox(
                    key: const Key('profile-membership-surface'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1, -.8 + wave * .08),
                        end: Alignment(1, .8 - wave * .07),
                        colors: widget.isPro
                            ? (dark
                                  ? const [
                                      Color(0xFF5A3B17),
                                      Color(0xFF30243B),
                                      Color(0xFF201F37),
                                    ]
                                  : const [
                                      Color(0xFFFFF1C9),
                                      Color(0xFFF9E3AF),
                                      Color(0xFFF3E8FF),
                                    ])
                            : dark
                            ? [
                                Color.lerp(
                                  const Color(0xFF303B55),
                                  const Color(0xFF2A3550),
                                  (wave + 1) / 2,
                                )!,
                                const Color(0xFF252F49),
                                const Color(0xFF1D2544),
                              ]
                            : [
                                Color.lerp(
                                  const Color(0xEBFFFFFF),
                                  const Color(0xEBF1F6FF),
                                  (wave + 1) / 2,
                                )!,
                                const Color(0xEBF1F6FF),
                                const Color(0xEFF0F0FF),
                              ],
                        stops: const [0, .58, 1],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.isPro
                            ? const Color(
                                0xFFF4A51C,
                              ).withValues(alpha: dark ? .58 : .72)
                            : dark
                            ? const Color(0xFF3A4567)
                            : const Color.fromRGBO(255, 255, 255, .86),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dark
                              ? Color.fromRGBO(1, 5, 20, .34 - press * .12)
                              : Color.fromRGBO(
                                  104,
                                  122,
                                  178,
                                  .14 - press * .05,
                                ),
                          blurRadius: 34 - press * 9,
                          offset: Offset(0, 18 - press * 7),
                        ),
                        if (widget.isPro)
                          BoxShadow(
                            color: const Color(
                              0xFFF4A51C,
                            ).withValues(alpha: dark ? .30 - press * .10 : .22),
                            blurRadius: 24 - press * 7,
                            spreadRadius: .5,
                          ),
                        if (!dark)
                          const BoxShadow(
                            color: Color(0x70FFFFFF),
                            blurRadius: 2,
                            offset: Offset(0, -1),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              key: const Key('profile-membership-gradient'),
                              painter: _MembershipAuroraPainter(
                                progress: progress,
                                dark: dark,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: _MembershipSweep(
                              progress: progress,
                              dark: dark,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: _MembershipContent(
                              dark: dark,
                              authUser: widget.authUser,
                              cardCount: widget.cardCount,
                              favoriteCount: widget.favoriteCount,
                              isPro: widget.isPro,
                            ),
                          ),
                        ],
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
    required this.dark,
    required this.authUser,
    required this.cardCount,
    required this.favoriteCount,
    required this.isPro,
  });

  final bool dark;
  final AuthUser? authUser;
  final int cardCount;
  final int favoriteCount;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF131C2F);
    final muted = dark ? const Color(0xFFB7BED1) : const Color(0xFF6F7D97);
    final hasVerifiedAccount = authUser?.emailVerified == true;
    final summary = _MembershipSummary.fromCounts(cardCount, favoriteCount);
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
                    isPro ? 'Pro 卡片等级' : '卡片等级',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    authUser == null
                        ? '未登录'
                        : hasVerifiedAccount
                        ? summary.title
                        : '待验证',
                    key: const Key('profile-membership-status'),
                    style: TextStyle(
                      color: isPro ? const Color(0xFFF4A51C) : primary,
                      fontSize: 18,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '质量分',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: 4),
                      const ProCrownBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasVerifiedAccount ? '${summary.score}' : '0',
                  style: TextStyle(
                    color: isPro
                        ? const Color(0xFFF4A51C)
                        : dark
                        ? Colors.white
                        : const Color(0xFF101726),
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasVerifiedAccount)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.description,
                style: TextStyle(
                  color: dark
                      ? const Color(0xC7E2E8F0)
                      : const Color(0xFF51607C),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  _MembershipFactPill(label: '已持有 $cardCount 张卡片', dark: dark),
                  _MembershipFactPill(label: '收藏 $favoriteCount 张', dark: dark),
                ],
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  authUser == null ? '登录后计算卡片等级' : '完成邮箱验证后开放账号同步',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xC7E2E8F0)
                        : const Color(0xFF51607C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Semantics(
                excludeSemantics: true,
                child: _MembershipStatePill(
                  dark: dark,
                  label: authUser == null ? '去登录' : '去验证',
                  icon: authUser == null
                      ? Icons.login_rounded
                      : Icons.mark_email_unread_outlined,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MembershipFactPill extends StatelessWidget {
  const _MembershipFactPill({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dark ? .05 : .56),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dark ? const Color(0x805F6A88) : const Color(0xD1D5DEF7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: dark ? const Color(0xFFDCE2F6) : const Color(0xFF6A7895),
            fontSize: 11.5,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MembershipStatePill extends StatelessWidget {
  const _MembershipStatePill({
    required this.dark,
    required this.label,
    required this.icon,
  });

  final bool dark;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('profile-login-chip'),
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 116),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF5665BD), Color(0xFF424C9A)]
                : const [Color(0xFFF9FAFF), Color(0xFFE8EBFF)],
          ),
          border: Border.all(
            color: dark
                ? const Color(0xA28F9BFF)
                : const Color.fromRGBO(115, 128, 255, .36),
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6575FF).withValues(alpha: .16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: dark ? Colors.white : const Color(0xFF5262D8),
              size: 15,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF5262D8),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipSummary {
  const _MembershipSummary({
    required this.title,
    required this.description,
    required this.score,
  });

  final String title;
  final String description;
  final int score;

  factory _MembershipSummary.fromCounts(int cardCount, int favoriteCount) {
    final normalizedCards = cardCount.clamp(0, 9999);
    final normalizedFavorites = favoriteCount.clamp(0, 9999);
    final score = normalizedCards * 16 + normalizedFavorites * 4;
    if (score >= 96) {
      return _MembershipSummary(
        title: 'Diamond',
        description: '高质量卡片组合，覆盖面和梯队都很完整',
        score: score,
      );
    }
    if (score >= 66) {
      return _MembershipSummary(
        title: 'Platinum',
        description: '主力卡已成型，消费和场景覆盖都比较能打',
        score: score,
      );
    }
    if (score >= 36) {
      return _MembershipSummary(
        title: 'Gold',
        description: '已经有不错的核心卡组合，还能继续优化梯队',
        score: score,
      );
    }
    if (score >= 16) {
      return _MembershipSummary(
        title: 'Silver',
        description: '卡片基础已经搭起来了，继续补强高权重卡',
        score: score,
      );
    }
    return _MembershipSummary(
      title: 'Bronze',
      description: '先把第一批主力卡加进来，等级会很快提升',
      score: score,
    );
  }
}

class _MembershipSweep extends StatelessWidget {
  const _MembershipSweep({required this.progress, required this.dark});

  final double progress;
  final bool dark;

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
                      Colors.white.withValues(alpha: dark ? .055 : .16),
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
      size.width * (dark ? .58 : .40),
      dark ? const Color(0x284F79FF) : const Color(0x107391FF),
    );
    glow(
      secondCenter,
      size.width * (dark ? .50 : .36),
      dark ? const Color(0x224D3D9F) : const Color(0x0DBCB0FF),
    );
    if (!dark) {
      glow(
        Offset(size.width * .55, size.height * .18),
        size.width * .28,
        const Color(0x0A78D0FF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MembershipAuroraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.sections,
    required this.onOpenSection,
    this.proActive = false,
  });

  final List<ProfileSection> sections;
  final ValueChanged<ProfileSection> onOpenSection;
  final bool proActive;

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
              MotionPressEffect(
                scale: MotionTokens.pressedScale,
                child: InkWell(
                  key: Key('profile-menu-${sections[index].name}'),
                  splashColor: AppColors.violet.withValues(alpha: .08),
                  highlightColor: AppColors.violet.withValues(alpha: .035),
                  hoverColor: AppColors.violet.withValues(alpha: .025),
                  onTap: () {
                    AppHaptics.selection();
                    onOpenSection(sections[index]);
                  },
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sections[index] == ProfileSection.pro &&
                                          proActive
                                      ? 'Pro 已开通'
                                      : sections[index].title,
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (sections[index] == ProfileSection.pro) ...[
                                const SizedBox(width: 8),
                                ProCrownBadge(showLabel: proActive),
                              ],
                            ],
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
              ),
          ],
        ),
      ),
    );
  }
}
