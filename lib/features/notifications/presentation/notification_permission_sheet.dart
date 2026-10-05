import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:flutter/material.dart' hide Text;

class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      namesRoute: true,
      label: AppLocalizations.of(context).text('开启通知'),
      child: Container(
        key: const Key('notification-permission-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
        decoration: BoxDecoration(
          color: AppColors.isDark
              ? const Color(0xF21C2030)
              : const Color(0xF7F8FAFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A70FF), Color(0xFF52C8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: .28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '及时获取重要变化',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '开启通知后，CardFi 会在新卡上线和重要资讯更新时提醒你，不发送营销轰炸。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _PermissionBenefit(
                icon: Icons.add_card_rounded,
                title: '新卡上线',
                description: '收录新卡时及时了解主要特点',
              ),
              const SizedBox(height: 10),
              _PermissionBenefit(
                icon: Icons.article_outlined,
                title: '重要资讯',
                description: '已确认的内容更新才会发送',
              ),
              const SizedBox(height: 10),
              _PermissionBenefit(
                icon: Icons.tune_rounded,
                title: '随时管理',
                description: '可在 App 或系统设置中随时关闭',
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const Key('notification-permission-enable'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.notifications_rounded, size: 19),
                label: const Text('开启通知'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('notification-permission-later'),
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('暂时不要'),
              ),
              const SizedBox(height: 2),
              Text(
                '你可以随时在“我的 → 设置 → 提醒配置”中修改。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionBenefit extends StatelessWidget {
  const _PermissionBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.violet, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
