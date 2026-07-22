import 'package:card_app/core/motion/app_haptics.dart';
import 'package:card_app/core/motion/motion_tokens.dart';
import 'package:card_app/core/motion/motion_widgets.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/pro/data/pro_config.dart';
import 'package:card_app/features/pro/data/pro_controller.dart';
import 'package:card_app/features/pro/domain/pro_models.dart';
import 'package:card_app/features/pro/widgets/pro_crown_badge.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class ProPage extends StatelessWidget {
  const ProPage({
    required this.controller,
    required this.onBack,
    required this.onPurchase,
    required this.onRestore,
    required this.onManageSubscription,
    this.onOpenWorkspace,
    this.onOpenComparison,
    this.onOpenTerms,
    this.onOpenPrivacy,
    super.key,
  });

  final ProController controller;
  final VoidCallback onBack;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onOpenComparison;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Stack(
        key: const Key('pro-page'),
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              topInset + 82,
              20,
              28 + bottomInset,
            ),
            children: [
              _ProHero(controller: controller, onPurchase: onPurchase),
              const SizedBox(height: 18),
              const Text(
                'Pro 权益',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const _FeatureCard(),
              if (controller.isActive &&
                  (onOpenWorkspace != null || onOpenComparison != null)) ...[
                const SizedBox(height: 14),
                _ProQuickActions(
                  onOpenWorkspace: onOpenWorkspace,
                  onOpenComparison: onOpenComparison,
                ),
              ],
              if (ProConfig.showDiagnostics) ...[
                const SizedBox(height: 14),
                _ConnectionCard(controller: controller),
              ],
              const SizedBox(height: 18),
              const Text(
                '订阅服务',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _MembershipActions(
                controller: controller,
                onRestore: onRestore,
                onManageSubscription: onManageSubscription,
              ),
              const SizedBox(height: 16),
              Text(
                '公开卡片资料、来源、风险提示和基础浏览不会设置付费墙。价格以 App Store 或 Google Play 显示为准。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onOpenTerms != null || onOpenPrivacy != null) ...[
                const SizedBox(height: 8),
                _LegalLinks(
                  onOpenTerms: onOpenTerms,
                  onOpenPrivacy: onOpenPrivacy,
                ),
              ],
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '购买由系统应用商店安全处理',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: .82),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StickyPageHeader(
              height: 72,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('pro-back'),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '集卡 Pro',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  ProCrownBadge(showLabel: controller.isActive),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProHero extends StatelessWidget {
  const _ProHero({required this.controller, required this.onPurchase});

  final ProController controller;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.isDark
              ? const [Color(0xFF303752), Color(0xFF1C223A)]
              : const [Color(0xFFFFFBF0), Color(0xFFF0F3FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.isDark
              ? Colors.white.withValues(alpha: .12)
              : const Color(0x45F4A51C),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF4A51C).withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProCrownBadge(showLabel: true),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            child: Text(
              controller.isActive ? 'Pro 已开通' : '让卡包更好用',
              key: ValueKey(controller.isActive),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.isActive
                ? _activeCopy(controller.entitlement)
                : '解锁高级卡包布局、多卡对比、费用测算、长周期数据、离线资料、变更关注与工作区备份。',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!controller.isActive) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (final offer in controller.offers) ...[
                  Expanded(
                    child: _PlanCard(
                      offer: offer,
                      selected: controller.selectedPlan == offer.plan,
                      onTap: () => controller.selectPlan(offer.plan),
                    ),
                  ),
                  if (offer != controller.offers.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: controller.message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InlineMessage(message: controller.message!),
                    ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pro-preview-purchase'),
                onPressed: controller.canPurchase ? onPurchase : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  elevation: controller.canPurchase ? 3 : 0,
                  shadowColor: const Color(0xFFF4A51C).withValues(alpha: .3),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    controller.purchasePending
                        ? '等待商店确认…'
                        : _purchaseLabel(controller),
                    key: ValueKey(
                      '${controller.purchasePending}-${controller.selectedPlan.name}-${controller.canPurchase}',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _purchaseHint(controller),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '订阅会按所选周期自动续费；可随时前往系统订阅管理页取消。实际价格、扣款时间与续费规则以商店确认页为准。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (controller.message != null) ...[
            const SizedBox(height: 12),
            _InlineMessage(message: controller.message!),
          ],
        ],
      ),
    );
  }

  String _activeCopy(ProEntitlement entitlement) {
    final expiresAt = entitlement.expiresAt?.toLocal();
    final status = entitlement.status.label;
    if (expiresAt == null) return '$status · 高级展示模式与全部 Pro 权益已解锁。';
    return '$status · 有效期至 ${expiresAt.year}-${expiresAt.month.toString().padLeft(2, '0')}-${expiresAt.day.toString().padLeft(2, '0')}';
  }

  String _purchaseLabel(ProController controller) {
    final offer = controller.offerFor(controller.selectedPlan);
    if (offer.price != null) return '${offer.price} · 开通 ${offer.title}';
    if (!controller.billingEnabled) return '开通 Pro · 等待商店配置';
    return '开通 ${offer.title}';
  }

  String _purchaseHint(ProController controller) {
    if (controller.loading) return '正在确认会员与商店状态…';
    if (!controller.billingEnabled) return '正式商店配置完成后开放购买';
    if (!controller.serviceAvailable) return 'Pro 服务正在准备中，当前不会发起扣款';
    if (!controller.accountConnected) return '登录后才可购买并在多设备恢复权益';
    if (!controller.accountPurchaseLinked) return '账号购买关联尚未安全配置';
    if (!controller.storeAvailable) return '当前设备暂时无法连接应用商店';
    if (!controller.offerFor(controller.selectedPlan).available) {
      return '所选订阅商品暂未在当前商店生效';
    }
    return '点击后将由系统商店显示最终价格并确认购买';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final ProOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: InkWell(
        key: Key('pro-plan-${offer.plan.name}'),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: MotionTokens.stateChange,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF4A51C).withValues(alpha: .12)
                : AppColors.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFF4A51C) : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  MotionStateIcon(
                    stateKey: selected,
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: Color(0xFFF4A51C),
                          )
                        : const SizedBox(width: 17, height: 17),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                offer.price ?? '价格待商店返回',
                style: const TextStyle(
                  color: Color(0xFFF4A51C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                offer.periodLabel,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});

  final ProController controller;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        '账号服务',
        controller.accountConnected ? '已连接' : '待接入正式登录',
        controller.accountConnected,
      ),
      (
        '商店商品',
        controller.storeAvailable ? '已连接' : '待配置或当前不可用',
        controller.storeAvailable,
      ),
      (
        '服务端验单',
        controller.serviceAvailable ? '已连接' : '待启用',
        controller.serviceAvailable,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '接入状态',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    row.$3
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: row.$3 ? AppColors.mint : AppColors.textMuted,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
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

class _MembershipActions extends StatelessWidget {
  const _MembershipActions({
    required this.controller,
    required this.onRestore,
    required this.onManageSubscription,
  });

  final ProController controller;
  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;

  @override
  Widget build(BuildContext context) {
    final canRestore =
        controller.billingEnabled &&
        controller.serviceAvailable &&
        controller.accountConnected &&
        controller.accountPurchaseLinked &&
        controller.storeAvailable &&
        !controller.restoring;
    final canRefresh =
        controller.serviceAvailable &&
        controller.accountConnected &&
        !controller.loading;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark ? .16 : .045,
            ),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ActionRow(
            key: const Key('pro-restore-purchase'),
            icon: Icons.restore_rounded,
            title: controller.restoring ? '正在恢复…' : '恢复购买',
            subtitle: '找回同一商店账号下的有效订阅',
            onTap: canRestore ? onRestore : null,
          ),
          Divider(height: 1, indent: 54, color: AppColors.line),
          _ActionRow(
            key: const Key('pro-refresh-entitlement'),
            icon: Icons.sync_rounded,
            title: '刷新会员状态',
            subtitle: '重新核对账号与商店权益',
            onTap: canRefresh ? controller.refreshEntitlement : null,
          ),
          Divider(height: 1, indent: 54, color: AppColors.line),
          _ActionRow(
            key: const Key('pro-manage-subscription'),
            icon: Icons.open_in_new_rounded,
            title: '管理或取消订阅',
            subtitle: '前往系统应用商店管理续费',
            onTap: onManageSubscription,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: AnimatedOpacity(
        opacity: onTap == null ? .48 : 1,
        duration: MotionTokens.fast,
        child: MotionPressEffect(
          enabled: onTap != null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 13, 10),
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.text, size: 21),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 21,
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
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({this.onOpenTerms, this.onOpenPrivacy});

  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        if (onOpenTerms != null)
          TextButton(onPressed: onOpenTerms, child: const Text('会员服务条款')),
        if (onOpenPrivacy != null)
          TextButton(onPressed: onOpenPrivacy, child: const Text('隐私政策')),
      ],
    );
  }
}

class _ProQuickActions extends StatelessWidget {
  const _ProQuickActions({this.onOpenWorkspace, this.onOpenComparison});

  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onOpenComparison;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onOpenWorkspace != null)
          Expanded(
            child: FilledButton.icon(
              key: const Key('pro-open-workspace'),
              onPressed: onOpenWorkspace,
              icon: const Icon(Icons.dashboard_customize_outlined, size: 19),
              label: const Text('Pro 工作区'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        if (onOpenWorkspace != null && onOpenComparison != null)
          const SizedBox(width: 10),
        if (onOpenComparison != null)
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('pro-open-comparison'),
              onPressed: onOpenComparison,
              icon: const Icon(Icons.compare_arrows_rounded, size: 19),
              label: const Text('开始对比'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  static const features = [
    (Icons.layers_outlined, '堆叠模式', '用纵向层叠展示多张卡片，快速浏览整个卡包'),
    (Icons.view_day_outlined, '聚焦模式', '突出当前卡片，获得更强的层次与浏览体验'),
    (Icons.compare_arrows_rounded, '多卡对比', '最多同时对比四张卡片的地区、入金、KYC、费用与支付渠道'),
    (Icons.calculate_outlined, '费用场景与导出', '透明展示可识别费用的场景测算，并导出 CSV 报告'),
    (Icons.timeline_rounded, '长周期数据', '查看 90 天与全部历史区间，免费版继续保留 7 天和 30 天'),
    (Icons.notifications_active_outlined, '规则变更关注', '管理卡片关注列表；正式推送接入后同步接收变化提醒'),
    (Icons.offline_pin_outlined, '离线资料与卡包报告', '缓存公开资料，并查看卡包结构与资料完整度分项'),
    (Icons.cloud_sync_outlined, 'Pro 工作区同步', '安全账号接入后同步关注项与保存的对比方案'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var index = 0; index < features.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(features[index].$1, color: AppColors.text, size: 22),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          features[index].$2,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          features[index].$3,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ProCrownBadge(),
                ],
              ),
            ),
            if (index != features.length - 1)
              Divider(height: 1, indent: 51, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}
