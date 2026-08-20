import 'dart:ui' as ui;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/referrals/data/referral_repository.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({
    required this.repository,
    required this.onBack,
    required this.profileName,
    this.avatarUrl,
    super.key,
  });

  final ReferralRepository repository;
  final VoidCallback onBack;
  final String profileName;
  final String? avatarUrl;

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  ReferralProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _savingPoster = false;
  final GlobalKey _posterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.loadProfile();
      if (mounted) setState(() => _profile = profile);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCode() async {
    final code = _profile?.code;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) AppNotice.success(context, '邀请码已复制。', title: '邀请好友');
  }

  String get _inviteUrl {
    final code = _profile?.code.trim() ?? '';
    if (code.isEmpty) return '';
    return Uri.https('card.lengziyu.cn', '/register', {
      'ref': code,
      'redirect': '/profile',
    }).toString();
  }

  Future<void> _copyInviteLink() async {
    final link = _inviteUrl;
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) AppNotice.success(context, '邀请链接已复制。', title: '邀请好友');
  }

  Future<void> _saveInvitePoster() async {
    if (_savingPoster) return;
    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _savingPoster = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) throw StateError('生成邀请封面失败');
      final permitted = await Gal.hasAccess();
      if (!permitted && !await Gal.requestAccess()) {
        throw StateError('未获得保存到相册的权限');
      }
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: 'jika-invite-${_profile?.code.toLowerCase() ?? 'card'}',
      );
      if (mounted) {
        AppNotice.success(context, '邀请封面已保存到相册。', title: '保存成功');
      }
    } on GalException catch (error) {
      if (mounted) AppNotice.error(context, error.type.message, title: '保存失败');
    } catch (error) {
      if (mounted) AppNotice.error(context, '$error', title: '保存失败');
    } finally {
      if (mounted) setState(() => _savingPoster = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const Key('referral-page'),
      children: [
        AppPullToRefresh(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              topInset + 88,
              20,
              28 + bottomInset,
            ),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 84),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _load)
              else if (profile != null) ...[
                _InviteCodeCard(
                  posterKey: _posterKey,
                  profile: profile,
                  profileName: widget.profileName,
                  avatarUrl: widget.avatarUrl,
                  inviteUrl: _inviteUrl,
                  savingPoster: _savingPoster,
                  onCopyCode: _copyCode,
                  onCopyLink: _copyInviteLink,
                  onSavePoster: _saveInvitePoster,
                ),
                const SizedBox(height: 14),
                _ProgressCard(profile: profile),
                const SizedBox(height: 18),
                const _RulesCard(),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            child: Row(
              children: [
                IconButton(
                  key: const Key('referral-back'),
                  tooltip: '返回',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '邀请好友',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.posterKey,
    required this.profile,
    required this.profileName,
    required this.inviteUrl,
    required this.savingPoster,
    required this.onCopyCode,
    required this.onCopyLink,
    required this.onSavePoster,
    this.avatarUrl,
  });

  final GlobalKey posterKey;
  final ReferralProfile profile;
  final String profileName;
  final String? avatarUrl;
  final String inviteUrl;
  final bool savingPoster;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;
  final VoidCallback onSavePoster;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RepaintBoundary(
        key: posterKey,
        child: _InvitePoster(
          profile: profile,
          profileName: profileName,
          avatarUrl: avatarUrl,
          inviteUrl: inviteUrl,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCopyLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(context.tr('复制邀请链接')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: savingPoster ? null : onSavePoster,
              icon: savingPoster
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(context.tr(savingPoster ? '正在保存' : '保存邀请封面')),
            ),
          ),
        ],
      ),
    ],
  );
}

class _InvitePoster extends StatelessWidget {
  const _InvitePoster({
    required this.profile,
    required this.profileName,
    required this.inviteUrl,
    this.avatarUrl,
  });

  final ReferralProfile profile;
  final String profileName;
  final String? avatarUrl;
  final String inviteUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF725CF7), Color(0xFF3384F3)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x553C6FF8),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InviteAvatar(name: profileName, avatarUrl: avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('邀请好友加入 CardFi'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$profileName ${context.tr('邀请你加入 CardFi')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          '我的邀请码',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          profile.code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: inviteUrl,
                size: 106,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF24214A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF24214A),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.tr('扫码注册\n完成邮箱验证并首次登录后，即可计入有效邀请。'),
                style: TextStyle(color: Colors.white, height: 1.55),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InviteAvatar extends StatelessWidget {
  const _InviteAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .48)),
    ),
    child: ClipOval(
      child: avatarUrl?.isNotEmpty == true
          ? Image.network(
              avatarUrl!,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initial(name: name),
            )
          : _Initial(name: name),
    ),
  );
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      name.trim().isEmpty ? '集' : name.trim().substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.profile});
  final ReferralProfile profile;

  @override
  Widget build(BuildContext context) {
    final next = profile.nextRewardAt;
    final progress = next == null
        ? 1.0
        : (profile.effectiveInvites / next).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '邀请进度',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${profile.effectiveInvites} ${context.tr('位有效邀请')}',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.line,
              color: const Color(0xFF806DFA),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            next == null
                ? '已达到邀请奖励上限。'
                : context
                      .tr('再邀请 {count} 人，可获得 1 个月 Pro。')
                      .replaceAll(
                        '{count}',
                        '${next - profile.effectiveInvites}',
                      ),
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const Divider(height: 30),
          Text(
            context
                .tr('已获得 {earned}/{max} 个月 Pro')
                .replaceAll('{earned}', '${profile.rewardedMonths}')
                .replaceAll('{max}', '${profile.maxRewardMonths}'),
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (profile.pendingRewardMonths > 0) ...[
            const SizedBox(height: 6),
            Text(
              context
                  .tr('{months} 个月奖励待商店订阅结束后使用。')
                  .replaceAll('{months}', '${profile.pendingRewardMonths}'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '奖励规则',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 10),
        Text('''• 普通账号每 10 位有效邀请获得 1 个月 Pro。
• 使用邀请码注册的账号，首次只需邀请 7 位；之后每增加 10 位获得 1 个月。
• 邀请奖励最多累计 6 个月；不可自邀、不可重复绑定。
• 不提供返现、佣金或外链推广奖励。''', style: TextStyle(height: 1.72)),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
