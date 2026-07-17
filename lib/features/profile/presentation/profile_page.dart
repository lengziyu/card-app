import 'package:card_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum ProfileSection {
  cards('我的卡片', Icons.credit_card_outlined),
  services('订阅与服务', Icons.auto_awesome_outlined),
  favorites('我的收藏', Icons.star_border_rounded),
  history('浏览记录', Icons.history_rounded),
  settings('设置', Icons.settings_outlined),
  language('中英切换', Icons.language_rounded),
  help('帮助中心', Icons.help_outline_rounded),
  about('关于我们', Icons.info_outline_rounded),
  recommend('推荐卡片', Icons.credit_card_outlined),
  notifications('消息与反馈', Icons.notifications_none_rounded),
  message('在线留言', Icons.send_outlined);

  const ProfileSection(this.title, this.icon);

  final String title;
  final IconData icon;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.cardCount,
    required this.favoriteCount,
    required this.historyCount,
    required this.onLogin,
    required this.onOpenSection,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final int cardCount;
  final int favoriteCount;
  final int historyCount;
  final VoidCallback onLogin;
  final ValueChanged<ProfileSection> onOpenSection;
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
                onLogin: onLogin,
                onToggleTheme: onToggleTheme,
              ),
              const SizedBox(height: 18),
              _MembershipCard(onTap: onLogin),
              const SizedBox(height: 18),
              _MenuGroup(
                sections: const [
                  ProfileSection.notifications,
                  ProfileSection.favorites,
                  ProfileSection.history,
                ],
                counts: {
                  ProfileSection.favorites: favoriteCount,
                  ProfileSection.history: historyCount,
                },
                onOpenSection: onOpenSection,
              ),
              const SizedBox(height: 12),
              _MenuGroup(
                sections: const [
                  ProfileSection.help,
                  ProfileSection.about,
                  ProfileSection.recommend,
                  ProfileSection.language,
                  ProfileSection.settings,
                ],
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
    required this.onLogin,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onLogin;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            key: const Key('profile-login'),
            onTap: onLogin,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassStrong,
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.isDark
                              ? const Color(0x33000000)
                              : const Color(0x1A626EAE),
                          blurRadius: AppColors.isDark ? 28 : 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      '游',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '游客模式',
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
                          '当前未登录 · 登录后同步卡片与收藏',
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
                ],
              ),
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

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.isDark
                  ? const [Color(0xD9303448), Color(0xC8202435)]
                  : const [Color(0xF7FFFFFF), Color(0xF0ECF0FF)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.isDark
                    ? const Color(0x47000000)
                    : const Color(0x24687AB2),
                blurRadius: AppColors.isDark ? 42 : 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
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
                          '卡片等级',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '未登录',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '质量分',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '0',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '登录后计算卡片等级',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '去登录',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.sections,
    required this.onOpenSection,
    this.counts = const {},
  });

  final List<ProfileSection> sections;
  final ValueChanged<ProfileSection> onOpenSection;
  final Map<ProfileSection, int> counts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDark
                  ? const Color(0x33000000)
                  : const Color(0x145B67A0),
              blurRadius: AppColors.isDark ? 28 : 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            for (var index = 0; index < sections.length; index++)
              InkWell(
                key: Key('profile-menu-${sections[index].name}'),
                onTap: () => onOpenSection(sections[index]),
                borderRadius: BorderRadius.circular(14),
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
                      if ((counts[sections[index]] ?? 0) > 0) ...[
                        Text(
                          '${counts[sections[index]]}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ] else if (sections[index] == ProfileSection.language)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.violet.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Text(
                            'English',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
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
