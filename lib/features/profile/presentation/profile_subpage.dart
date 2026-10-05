import 'dart:async';

import 'package:cardfi/core/localization/app_language.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/motion/motion_tokens.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:cardfi/features/profile/data/app_version_repository.dart';
import 'package:cardfi/features/profile/data/legal_config.dart';
import 'package:cardfi/features/profile/presentation/profile_page.dart';
import 'package:cardfi/features/notifications/data/notification_repository.dart';
import 'package:cardfi/features/notifications/data/notification_service.dart';
import 'package:cardfi/features/ranking/domain/local_article.dart';
import 'package:cardfi/features/shell/widgets/animated_glass_segment.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSubpage extends StatefulWidget {
  const ProfileSubpage({
    required this.section,
    required this.favoriteCards,
    required this.recentCards,
    required this.favoriteArticles,
    required this.submissions,
    required this.appMessages,
    required this.onBack,
    required this.onOpenCard,
    required this.onOpenArticle,
    required this.onOpenSection,
    required this.onSubmit,
    required this.onRefreshNotifications,
    required this.onOpenAppMessage,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.pushEnabled,
    required this.notificationPermissionStatus,
    required this.onPushEnabledChanged,
    required this.hapticsEnabled,
    required this.cardSwipeHapticsEnabled,
    required this.hapticStrength,
    required this.hasVerifiedAccount,
    required this.onHapticsEnabledChanged,
    required this.onCardSwipeHapticsEnabledChanged,
    required this.onHapticStrengthChanged,
    this.referralEnabled = false,
    this.appVersionRepository,
    this.profileName,
    this.profileUserId,
    this.profileEmail,
    this.avatarUrl,
    this.onProfileNameChanged,
    this.onAvatarChanged,
    this.onLogout,
    this.onDeleteAccount,
    this.loginProviders = const <AuthLoginProvider>{},
    this.googleAuthAvailable = false,
    this.appleAuthAvailable = false,
    this.onLinkGoogle,
    this.onLinkApple,
    this.onUnlinkGoogle,
    this.onUnlinkApple,
    super.key,
  });

  final ProfileSection section;
  final List<CardSummary> favoriteCards;
  final List<CardSummary> recentCards;
  final List<LocalArticle> favoriteArticles;
  final List<LocalSubmission> submissions;
  final List<AppMessage> appMessages;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<LocalArticle> onOpenArticle;
  final ValueChanged<ProfileSection> onOpenSection;
  final Future<void> Function(LocalSubmissionDraft) onSubmit;
  final Future<void> Function() onRefreshNotifications;
  final ValueChanged<AppMessage> onOpenAppMessage;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final bool pushEnabled;
  final NotificationPermissionStatus notificationPermissionStatus;
  final Future<void> Function(bool enabled) onPushEnabledChanged;
  final bool hapticsEnabled;
  final bool cardSwipeHapticsEnabled;
  final AppHapticStrength hapticStrength;
  final bool hasVerifiedAccount;
  final bool referralEnabled;
  final ValueChanged<bool> onHapticsEnabledChanged;
  final ValueChanged<bool> onCardSwipeHapticsEnabledChanged;
  final ValueChanged<AppHapticStrength> onHapticStrengthChanged;
  final AppVersionRepository? appVersionRepository;
  final String? profileName;
  final String? profileUserId;
  final String? profileEmail;
  final String? avatarUrl;
  final Future<bool> Function(String name)? onProfileNameChanged;
  final Future<bool> Function(XFile image)? onAvatarChanged;
  final Future<void> Function()? onLogout;
  final Future<bool> Function()? onDeleteAccount;
  final Set<AuthLoginProvider> loginProviders;
  final bool googleAuthAvailable;
  final bool appleAuthAvailable;
  final Future<bool> Function()? onLinkGoogle;
  final Future<bool> Function()? onLinkApple;
  final Future<bool> Function()? onUnlinkGoogle;
  final Future<bool> Function()? onUnlinkApple;

  @override
  State<ProfileSubpage> createState() => _ProfileSubpageState();
}

class _ProfileSubpageState extends State<ProfileSubpage> {
  String _favoriteTab = '卡片';
  String _notificationTab = '贡献';
  PackageInfo? _packageInfo;
  bool _packageInfoFailed = false;
  AppVersionUpdate? _appVersionUpdate;
  bool _checkingAppVersion = false;
  bool _appVersionCheckFailed = false;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  String? _formMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.section == ProfileSection.version) {
      _loadPackageInfo();
    }
  }

  Future<void> _loadPackageInfo() async {
    setState(() {
      _packageInfoFailed = false;
      _appVersionCheckFailed = false;
    });
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _packageInfo = packageInfo);
      await _checkForAppUpdate(packageInfo);
    } catch (_) {
      if (!mounted) return;
      setState(() => _packageInfoFailed = true);
    }
  }

  Future<void> _checkForAppUpdate(PackageInfo packageInfo) async {
    final repository = widget.appVersionRepository;
    if (repository == null) return;
    setState(() {
      _checkingAppVersion = true;
      _appVersionCheckFailed = false;
    });
    try {
      final update = await repository.checkInstalledVersion(packageInfo);
      if (!mounted) return;
      setState(() => _appVersionUpdate = update);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersionCheckFailed = true);
    } finally {
      if (mounted) setState(() => _checkingAppVersion = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_descriptionController.text.trim().length < 8) {
      setState(() => _formMessage = '请至少输入 8 个字的说明');
      return;
    }
    final link = _linkController.text.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        setState(() => _formMessage = '参考链接需要是完整的 HTTPS 地址');
        return;
      }
    }
    final category = switch (widget.section) {
      ProfileSection.recommend => LocalSubmissionCategory.recommendation,
      ProfileSection.feedback => LocalSubmissionCategory.message,
      _ => throw StateError('当前页面不支持提交'),
    };
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        LocalSubmissionDraft(
          category: category,
          subject: _subjectController.text,
          description: _descriptionController.text,
          link: link,
        ),
      );
      if (!mounted) return;
      _subjectController.clear();
      _descriptionController.clear();
      _linkController.clear();
      FocusScope.of(context).unfocus();
      setState(() => _formMessage = '反馈已提交，感谢你的建议。');
    } on ApiException catch (error) {
      if (mounted) setState(() => _formMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openNotifications() {
    widget.onOpenSection(ProfileSection.notifications);
  }

  Future<void> _editProfileName() async {
    final controller = TextEditingController(text: widget.profileName ?? '');
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '输入新的用户名'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // Navigator completes before the dialog's exit animation has disposed its
    // TextField. Releasing the controller immediately trips Flutter's
    // dependent assertion while that field is still mounted.
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    final value = nextName?.trim();
    if (value == null || value.isEmpty || widget.onProfileNameChanged == null) {
      return;
    }
    final updated = await widget.onProfileNameChanged!(value);
    if (!mounted) return;
    if (updated) {
      AppNotice.success(context, '用户名已更新。', title: '保存成功');
    }
  }

  Future<void> _pickAvatar() async {
    final pick = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 88,
    );
    if (pick == null || widget.onAvatarChanged == null) return;
    final updated = await widget.onAvatarChanged!(pick);
    if (!mounted || !updated) return;
    AppNotice.success(context, '头像已更新，已同步到账号。', title: '保存成功');
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, 28 + bottomInset),
      children: [
        switch (widget.section) {
          ProfileSection.pro => _infoList([
            ('Pro 会员', '请从个人中心的 Pro 会员入口查看权益与订阅状态。'),
          ]),
          ProfileSection.favorites => _favorites(),
          ProfileSection.bills => const SizedBox.shrink(),
          ProfileSection.history => _collection(
            title: '最近浏览',
            emptyCopy: '浏览卡片详情后会显示在这里。',
            items: widget.recentCards,
          ),
          ProfileSection.settings => _settings(),
          ProfileSection.version => _versionPage(),
          ProfileSection.language => _languagePage(),
          ProfileSection.usageGuide => _infoList([
            (
              '使用前须知',
              'AI精选好卡、AI 协助开卡和账单识别需要已登录、完成邮箱验证；普通版与 Pro 的每月额度以页面提示为准，每月月初重置。请勿填写证件号码、完整卡号、密码、助记词或其他凭据。',
            ),
            (
              'AI精选好卡',
              '从市场页进入“AI精选好卡”，填写所在地区、可用证件类型、KYC 偏好和主要用途。普通版每月可用 6 次，Pro 每月可用 20 次；结果不构成申请、审批或金融建议。',
            ),
            (
              'AI 协助开卡',
              '在卡片详情点击“AI 协助开卡”，可查看公开材料清单、操作步骤、费用与风险提醒。普通版每月可用 6 次，Pro 每月可用 20 次；请以发卡方官方实时流程为准。',
            ),
            (
              'AI 识别账单',
              '从底部快捷入口选择账单截图，普通版每月可用 8 次，Pro 每月可用 30 次；图片只用于当次字段提取，费用结果由固定公式计算。',
            ),
            (
              '卡片对比与费用场景',
              '在卡片详情选择“加入卡片对比”，普通版可同时比较两张卡片，Pro 可比较 2–4 张卡片。费用场景只计算可识别的公开费用，可导出报告，不能替代发卡方报价。',
            ),
            (
              '规则变更关注',
              '在卡片详情开启“关注规则变更”后，可在 Pro 工作区管理关注项。当前以 App 内关注状态为准；实时提醒需以正式推送服务实际可用状态为准。',
            ),
          ]),
          ProfileSection.help => _infoList([
            ('如何添加卡片？', '进入市场或点击底部加号查看目录；登录并完成邮箱验证后才能加入“我的卡片”。'),
            ('卡片资料来自哪里？', '资料整理自公开来源；详情页会展示来源说明，最终规则以发卡方为准。'),
            (
              'KYC 与资讯的地区适用性',
              'KYC 资料与资讯文章主要按中国大陆用户的公开资料、申请语境和合规提示整理；其他国家或地区的资格、证件、费用与产品可用性可能不同，请以当地法规及发卡方最新官方流程为准。',
            ),
            ('游客的数据会保存吗？', '未登录状态仅用于浏览演示内容，不创建个人卡片、收藏或历史记录。'),
            ('会收集身份证或护照吗？', '不会。App 只展示公开的 KYC 要求标签，不接收或保存证件。'),
            ('排行是投资建议吗？', '不是。排行仅用于信息整理和界面演示，不构成金融建议。'),
          ]),
          ProfileSection.about => _infoList([
            ('关于 CardFi', 'CardFi 是一款用于浏览、整理和比较卡片公开资料的信息工具。'),
            ('独立项目', 'App 由个人开发者维护，不代表任何银行、卡组织或发卡平台。'),
            (
              '信息来源与权利',
              '卡片名称、图片、标识、费用和权益等资料整理自官方网站及其他公开信息，仅用于信息展示与比较；相关商标、图片和名称归其权利人所有。',
            ),
            ('更正与下架', '如相关展示存在错误、侵权或造成冒犯，请通过“反馈与纠错”联系；核实后将及时更正或下架。'),
            ('隐私原则', '不收集 KYC 材料，不接入广告，不出售用户数据。'),
            ('联系与反馈', '已验证账号可提交问题、建议和卡片信息纠错，并在“消息与反馈”中查看处理进度。'),
          ]),
          ProfileSection.privacy => _legalPage(
            items: const [
              (
                '我们处理哪些数据',
                '账号功能会处理邮箱、公开昵称、内部用户标识和登录会话；同步功能会处理卡包、收藏、浏览历史、规则关注、反馈与投稿。通知开启后会处理设备推送令牌和随机安装标识。',
              ),
              (
                '图片与账单',
                '只有你主动选择并逐次同意时，App 才会把消费账单截图经 CardFi 服务器发送给阿里云百炼 Qwen。上传前必须移除完整卡号、姓名、订单号、地址和二维码；CardFi 不把原图写入账单记录。',
              ),
              (
                '我们不会收集',
                '不收集或保存身份证、护照、人脸、完整银行卡号、有效期、CVV、PIN、网银密码、钱包助记词或交易所凭据；不接入广告画像或跨 App 追踪。',
              ),
              (
                '用途与共享',
                'AI精选好卡与 AI 协助开卡仅在你逐次同意后，将页面列明的地区、证件类型、用途、KYC 偏好、申请阶段和可选问题发送给阿里云百炼。数据仅用于所请求功能，不出售个人数据。',
              ),
              (
                '保留与安全',
                '登录令牌保存在系统安全存储中。账号数据保留至你删除账号或功能不再需要；提交内容按审核与争议处理需要保留，并支持依法提出删除请求。',
              ),
              (
                '你的权利',
                '你可以退出登录、关闭通知、修改公开昵称，并在 App 内永久删除账号。删除后会清除账号及服务端保存的卡包、收藏、历史、反馈和 Pro 工作区数据。',
              ),
              (
                '更新日期',
                '本隐私政策更新于 2026 年 8 月 18 日。公开版本应与网页版保持一致；如处理目的、数据类型或 AI 处理方发生实质变化，将在生效前更新说明并重新取得许可。',
              ),
            ],
            onlineUrl: LegalConfig.privacyPolicyUrl,
            onlineButtonKey: const Key('privacy-policy-online'),
          ),
          ProfileSection.terms => _legalPage(
            items: const [
              (
                '服务定位',
                'CardFi 是浏览、整理和比较卡片公开资料的信息工具，不发行卡片、不提供支付、交易、托管、贷款、信用评估或开卡代办服务。',
              ),
              (
                '信息与风险',
                '费用、地区、KYC、权益和申请条件可能变化，均以发卡方最新官方规则为准。App 的整理、排行、对比和 AI 输出不构成金融、投资、法律或申请成功保证。',
              ),
              (
                '账号责任',
                '你应提供本人可用的邮箱并妥善保护账号。不得共享密码、验证码或登录令牌，不得利用服务攻击接口、绕过权限或影响其他用户。',
              ),
              (
                '用户提交内容',
                '纠错、反馈和技巧投稿必须真实、合法且不含完整卡号、证件、密码、联系方式、邀请码、返佣或推广内容。提交内容在审核通过前不会公开。',
              ),
              (
                '知识产权',
                '卡片名称、图片、标识及第三方资料归各权利人所有，仅用于信息展示与比较。若内容存在错误、侵权或造成冒犯，可通过支持入口要求核查、更正或下架。',
              ),
              (
                '服务变更',
                '为安全、合规或维护需要，部分功能可能暂停、调整或下线。重要变化会通过 App 或公开页面说明；已安装版本仍可能因接口停用而需要升级。',
              ),
              (
                '协议日期',
                '本用户协议更新于 2026 年 7 月 27 日。Pro 购买未开放时不会发起扣款；未来开放订阅前会另行展示价格、自动续费规则、恢复购买与取消方式。',
              ),
            ],
            onlineUrl: LegalConfig.termsOfUseUrl,
            onlineButtonKey: const Key('terms-of-use-online'),
          ),
          ProfileSection.accountDeletion => _legalPage(
            items: const [
              ('App 内删除', '登录并完成邮箱验证后，进入“我的 → 设置”，滚动到底部，点击“删除账号”，阅读提示后确认永久删除。'),
              (
                '删除范围',
                '删除会清除 Supabase 账号，以及服务端保存的卡包、收藏、浏览历史、反馈、投稿和 Pro 工作区数据；操作完成后当前设备会退出登录。',
              ),
              (
                '无法恢复',
                '账号删除不可撤销。为避免误删，删除前可能要求重新登录。因安全、财务或法律义务必须保留的最少记录，会按适用期限隔离保留后删除。',
              ),
              ('商店订阅', '删除 CardFi 账号不会自动取消已有的应用商店订阅。如未来开通订阅，需同时前往系统订阅管理页取消。'),
              (
                '无法登录时',
                '如果无法进入账号，可通过“联系支持”提交删除请求。为保护账号，处理前需要验证邮箱所有权；请勿发送密码、验证码、完整卡号或身份证件。',
              ),
            ],
            onlineUrl: LegalConfig.accountDeletionUrl,
            onlineButtonKey: const Key('account-deletion-online'),
          ),
          ProfileSection.support => _supportPage(),
          ProfileSection.services => _infoList([
            ('账号同步', '卡片、收藏与历史的同步状态以账号页面提示为准。'),
            ('Pro 工作区同步', '关注项和对比方案的独立接口已预留，只有安全账号与有效 Pro 权益才能访问。'),
            (
              'Pro 会员',
              '将 AI精选好卡、AI 协助开卡、账单识别分别提升至每月 20、20、30 次，并包含 2–4 卡对比、费用情景估算、长期数据与 Pro 工作区。',
            ),
            ('离线与提醒', '公开卡片资料可保存到本机；规则关注已可管理，实时提醒仍需正式账号与推送任务接入。'),
          ]),
          ProfileSection.recommend => _submission(
            heading: '推荐一张值得收录的卡片',
            copy: '请说明卡片名称、发行方和推荐理由，链接可选。',
            includeSubject: false,
            includeLink: true,
          ),
          ProfileSection.feedback => _feedback(),
          ProfileSection.notifications => _notifications(),
          ProfileSection.reminders => _reminderSettings(),
          // The shell routes this transient debug surface directly to
          // MotionLabPage. Keep this branch for enum exhaustiveness if a
          // future caller reaches ProfileSubpage directly.
          ProfileSection.motionLab => const SizedBox.shrink(),
          ProfileSection.referral => const SizedBox.shrink(),
        },
      ],
    );
    return Stack(
      key: Key('profile-subpage-${widget.section.name}'),
      children: [
        if (widget.section == ProfileSection.notifications)
          AppPullToRefresh(
            onRefresh: widget.onRefreshNotifications,
            indicatorTop: topInset + 70,
            child: content,
          )
        else
          content,
        Align(
          alignment: Alignment.topCenter,
          child: StickyPageHeader(
            child: _Header(title: widget.section.title, onBack: widget.onBack),
          ),
        ),
      ],
    );
  }

  Widget _collection({
    required String title,
    required String emptyCopy,
    required List<CardSummary> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 14),
        if (items.isEmpty)
          _EmptyState(title: '暂无内容', copy: emptyCopy)
        else
          for (final card in items) ...[
            CatalogCardRow(card: card, onTap: () => widget.onOpenCard(card)),
            SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _favorites() {
    return Column(
      children: [
        _Segmented(
          values: ['卡片', '文章'],
          selected: _favoriteTab,
          onChanged: (value) => setState(() => _favoriteTab = value),
        ),
        SizedBox(height: 16),
        if (_favoriteTab == '卡片')
          _collection(
            title: '收藏的卡片',
            emptyCopy: '还没有收藏卡片。',
            items: widget.favoriteCards,
          )
        else
          widget.favoriteArticles.isEmpty
              ? const _EmptyState(
                  title: '还没有收藏文章',
                  copy: '可在排行榜的文章标签中打开文章并体验收藏。',
                )
              : Column(
                  children: [
                    for (final article in widget.favoriteArticles) ...[
                      Material(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          key: Key('favorite-article-${article.id}'),
                          onTap: () => widget.onOpenArticle(article),
                          title: Text(
                            article.title,
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            article.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ],
                ),
      ],
    );
  }

  Future<void> _manageIdentity({
    required AuthLoginProvider provider,
    required String label,
    required Future<bool> Function()? onLink,
    required Future<bool> Function()? onUnlink,
  }) async {
    final linked = widget.loginProviders.contains(provider);
    if (!linked) {
      final completed = await onLink?.call() ?? false;
      if (!mounted) return;
      if (completed) {
        AppNotice.success(context, '$label 账号已绑定。', title: '绑定成功');
      } else {
        AppNotice.error(context, '$label 账号绑定失败，请稍后重试。', title: '绑定失败');
      }
      return;
    }
    if (widget.loginProviders.length <= 1) {
      AppNotice.info(context, '请先绑定另一种登录方式，避免无法再次登录。', title: '不能解除绑定');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('解除 $label 绑定？'),
        content: Text('解除后将不能再用 $label 登录当前账号，但账号和已同步数据不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('解除绑定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final completed = await onUnlink?.call() ?? false;
    if (!mounted) return;
    if (completed) {
      AppNotice.success(context, '$label 账号已解除绑定。', title: '解绑成功');
    } else {
      AppNotice.error(context, '$label 账号解绑失败，请稍后重试。', title: '解绑失败');
    }
  }

  Widget _settings() {
    final hasUserId = widget.profileUserId?.trim().isNotEmpty == true;
    final hasEmail = widget.profileEmail?.trim().isNotEmpty == true;
    final canEditAvatar = widget.onAvatarChanged != null;
    final canEditName = widget.onProfileNameChanged != null;
    return Column(
      children: [
        if (hasUserId || hasEmail || canEditAvatar || canEditName) ...[
          _InfoCard(
            child: Column(
              children: [
                if (hasUserId) ...[
                  _SettingsActionRow(
                    key: const Key('settings-profile-uid'),
                    icon: Icons.fingerprint_rounded,
                    title: 'UID',
                    trailingText: _shortUserId(widget.profileUserId),
                    onTap: _copyUserId,
                    actionLabel: '复制',
                    showChevron: false,
                    minHeight: 54,
                  ),
                  if (hasEmail || canEditAvatar || canEditName)
                    Divider(height: 1, color: AppColors.line),
                ],
                if (hasEmail) ...[
                  _SettingsActionRow(
                    key: const Key('settings-profile-email'),
                    icon: Icons.alternate_email_rounded,
                    title: '注册邮箱',
                    trailingText: widget.profileEmail!.trim(),
                    trailingTextFlex: 3,
                    showChevron: false,
                    minHeight: 54,
                  ),
                  if (canEditAvatar || canEditName)
                    Divider(height: 1, color: AppColors.line),
                ],
                if (canEditAvatar) ...[
                  _SettingsActionRow(
                    key: const Key('settings-profile-avatar'),
                    icon: Icons.add_a_photo_outlined,
                    title: '修改头像',
                    trailing: _AvatarSettingPreview(url: widget.avatarUrl),
                    onTap: _pickAvatar,
                    minHeight: 54,
                  ),
                  if (canEditName) Divider(height: 1, color: AppColors.line),
                ],
                if (canEditName)
                  _SettingsActionRow(
                    key: const Key('settings-profile-name'),
                    icon: Icons.person_outline_rounded,
                    title: '用户名',
                    trailingText: widget.profileName,
                    onTap: _editProfileName,
                    minHeight: 54,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.hasVerifiedAccount &&
            (widget.googleAuthAvailable || widget.appleAuthAvailable)) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '登录方式',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _InfoCard(
            child: Column(
              children: [
                if (widget.appleAuthAvailable) ...[
                  _SettingsActionRow(
                    key: const Key('settings-link-apple'),
                    icon: Icons.apple,
                    title: 'Apple',
                    trailingText:
                        widget.loginProviders.contains(AuthLoginProvider.apple)
                        ? '已绑定'
                        : '未绑定',
                    onTap: () => _manageIdentity(
                      provider: AuthLoginProvider.apple,
                      label: 'Apple',
                      onLink: widget.onLinkApple,
                      onUnlink: widget.onUnlinkApple,
                    ),
                    actionLabel:
                        widget.loginProviders.contains(AuthLoginProvider.apple)
                        ? '解绑'
                        : '绑定',
                    showChevron: false,
                    minHeight: 54,
                  ),
                  if (widget.googleAuthAvailable)
                    Divider(height: 1, color: AppColors.line),
                ],
                if (widget.googleAuthAvailable)
                  _SettingsActionRow(
                    key: const Key('settings-link-google'),
                    icon: Icons.account_circle_outlined,
                    title: 'Google',
                    trailingText:
                        widget.loginProviders.contains(AuthLoginProvider.google)
                        ? '已绑定'
                        : '未绑定',
                    onTap: () => _manageIdentity(
                      provider: AuthLoginProvider.google,
                      label: 'Google',
                      onLink: widget.onLinkGoogle,
                      onUnlink: widget.onUnlinkGoogle,
                    ),
                    actionLabel:
                        widget.loginProviders.contains(AuthLoginProvider.google)
                        ? '解绑'
                        : '绑定',
                    showChevron: false,
                    minHeight: 54,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.hasVerifiedAccount && widget.referralEnabled) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '会员与邀请',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _InfoCard(
            child: _SettingsDestination(
              key: const Key('settings-referral'),
              section: ProfileSection.referral,
              subtitle: '邀请好友并查看 Pro 奖励进度',
              onTap: () => widget.onOpenSection(ProfileSection.referral),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '通知',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _InfoCard(
          child: Column(
            children: [
              _SettingsActionRow(
                key: const Key('settings-notification-permission'),
                icon: Icons.notifications_none_rounded,
                title: '通知权限',
                trailingText: _notificationStatusLabel,
                onTap: () => widget.onPushEnabledChanged(!widget.pushEnabled),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsActionRow(
                key: const Key('settings-reminder-config'),
                icon: Icons.notifications_active_outlined,
                title: '提醒配置',
                onTap: () => widget.onOpenSection(ProfileSection.reminders),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _InfoCard(
          child: Column(
            children: [
              _SettingsToggle(
                key: const Key('settings-haptics'),
                icon: Icons.vibration_rounded,
                title: '震动反馈',
                subtitle: '操作时提供轻微触觉反馈',
                value: widget.hapticsEnabled,
                onChanged: (value) async =>
                    widget.onHapticsEnabledChanged(value),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsToggle(
                key: const Key('settings-card-swipe-haptics'),
                icon: Icons.touch_app_outlined,
                title: '卡片滑动震动',
                subtitle: '切换当前卡片时提供触觉反馈',
                value: widget.hapticsEnabled && widget.cardSwipeHapticsEnabled,
                enabled: widget.hapticsEnabled,
                onChanged: widget.hapticsEnabled
                    ? (value) async =>
                          widget.onCardSwipeHapticsEnabledChanged(value)
                    : (_) async {},
              ),
              Divider(height: 1, color: AppColors.line),
              _HapticStrengthSetting(
                key: const Key('settings-card-swipe-strength'),
                value: widget.hapticStrength,
                enabled:
                    widget.hapticsEnabled && widget.cardSwipeHapticsEnabled,
                onChanged: widget.onHapticStrengthChanged,
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _InfoCard(
          child: Column(
            children: [
              _SettingsDestination(
                key: const Key('settings-usage-guide'),
                section: ProfileSection.usageGuide,
                subtitle: 'AI精选好卡、AI 协助开卡与 Pro 功能操作说明',
                onTap: () => widget.onOpenSection(ProfileSection.usageGuide),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-help'),
                section: ProfileSection.help,
                subtitle: '常见问题、地区适用性与数据安全',
                onTap: () => widget.onOpenSection(ProfileSection.help),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-about'),
                section: ProfileSection.about,
                subtitle: '产品定位、隐私原则与联系信息',
                onTap: () => widget.onOpenSection(ProfileSection.about),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-privacy-policy'),
                section: ProfileSection.privacy,
                subtitle: '了解数据处理、保留、安全与账号权利',
                onTap: () => widget.onOpenSection(ProfileSection.privacy),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-terms-of-use'),
                section: ProfileSection.terms,
                subtitle: '服务定位、使用规则和重要风险说明',
                onTap: () => widget.onOpenSection(ProfileSection.terms),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-account-deletion'),
                section: ProfileSection.accountDeletion,
                subtitle: '删除方式、数据范围和无法登录时的处理路径',
                onTap: () =>
                    widget.onOpenSection(ProfileSection.accountDeletion),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-support'),
                section: ProfileSection.support,
                subtitle: '联系开发者、反馈问题或提出数据请求',
                onTap: () => widget.onOpenSection(ProfileSection.support),
              ),
              if (widget.hasVerifiedAccount) ...[
                Divider(height: 1, color: AppColors.line),
                _SettingsDestination(
                  key: const Key('settings-feedback'),
                  section: ProfileSection.feedback,
                  subtitle: '提交问题、建议与信息纠错，并查看处理进度',
                  onTap: () => widget.onOpenSection(ProfileSection.feedback),
                ),
              ],
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-version'),
                section: ProfileSection.version,
                subtitle: '当前版本、构建号与更新方式',
                onTap: () => widget.onOpenSection(ProfileSection.version),
              ),
              if (widget.hasVerifiedAccount) ...[
                Divider(height: 1, color: AppColors.line),
                _SettingsDestination(
                  key: const Key('settings-app-messages'),
                  section: ProfileSection.notifications,
                  subtitle: '查看资讯、新卡上线和反馈记录',
                  onTap: _openNotifications,
                ),
              ],
            ],
          ),
        ),
        if (widget.onLogout != null) ...[
          SizedBox(height: 14),
          _SettingsLogoutAction(onLogout: widget.onLogout!),
        ],
        if (widget.onDeleteAccount != null) ...[
          SizedBox(height: 10),
          _SettingsDeleteAccountAction(
            onDeleteAccount: widget.onDeleteAccount!,
          ),
        ],
      ],
    );
  }

  Widget _reminderSettings() {
    return Column(
      children: [
        _InfoCard(
          child: Column(
            children: [
              _SettingsToggle(
                key: const Key('settings-content-push'),
                icon: Icons.notifications_active_outlined,
                title: '内容更新提醒',
                subtitle: '资讯发布与新卡上线时通知你',
                value: widget.pushEnabled,
                onChanged: widget.onPushEnabledChanged,
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsActionRow(
                icon: Icons.rule_folder_outlined,
                title: '卡片规则变更',
                trailingText: '在 Pro 工作区管理',
                onTap: () => AppNotice.info(
                  context,
                  '可在 Pro 工作区管理关注卡片；正式推送任务接入后同步提醒。',
                  title: '规则变更提醒',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _notificationStatusLabel {
    if (widget.pushEnabled) return '已开启';
    return switch (widget.notificationPermissionStatus) {
      NotificationPermissionStatus.denied => '系统已关闭',
      NotificationPermissionStatus.authorized ||
      NotificationPermissionStatus.provisional => '已关闭',
      NotificationPermissionStatus.unavailable => '暂不可用',
      NotificationPermissionStatus.notDetermined => '未设置',
    };
  }

  Widget _feedback() {
    return _submission(
      heading: '记录问题或建议',
      copy: '提交后会同步到你的账号，便于查看处理进度与回复；请不要填写账号、证件或其他敏感信息。',
      includeSubject: true,
      includeLink: false,
    );
  }

  Widget _versionPage() {
    final packageInfo = _packageInfo;
    if (packageInfo == null && !_packageInfoFailed) {
      return const AppLoadingPanel(label: '正在读取版本信息');
    }
    if (packageInfo == null) {
      return _InfoCard(
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.textMuted,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              '暂时无法读取版本信息',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('version-retry'),
              onPressed: _loadPackageInfo,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新读取'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _InfoCard(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.violet, AppColors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: .2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageInfo.appName.isEmpty
                          ? 'CardFi'
                          : packageInfo.appName,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '版本 ${packageInfo.version}  ·  构建 ${packageInfo.buildNumber}',
                      key: const Key('version-summary'),
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: '复制版本信息',
                child: IconButton(
                  key: const Key('version-copy'),
                  onPressed: () => _copyVersionInfo(packageInfo),
                  icon: const Icon(Icons.copy_rounded),
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InfoCard(
          child: Column(
            children: [
              _VersionFactRow(label: '版本号', value: packageInfo.version),
              Divider(height: 22, color: AppColors.line),
              _VersionFactRow(label: '构建号', value: packageInfo.buildNumber),
              Divider(height: 22, color: AppColors.line),
              _VersionFactRow(label: '运行平台', value: _platformLabel),
              Divider(height: 22, color: AppColors.line),
              _VersionFactRow(
                label: '安装来源',
                value: _installerLabel(packageInfo.installerStore),
              ),
              Divider(height: 22, color: AppColors.line),
              _VersionFactRow(label: '应用标识', value: packageInfo.packageName),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _appUpdateCard(packageInfo),
      ],
    );
  }

  Widget _appUpdateCard(PackageInfo packageInfo) {
    final update = _appVersionUpdate;
    final localizations = AppLocalizations.of(context);
    final title = switch ((update?.configurationInvalid, update?.status)) {
      (true, _) => '更新配置暂不可用',
      (_, AppUpdateStatus.upToDate) => '已是最新版本',
      (_, AppUpdateStatus.optional) => '发现新版本',
      (_, AppUpdateStatus.required) => '需要更新后继续使用',
      _ => '更新方式',
    };
    final body = switch ((update?.configurationInvalid, update?.status)) {
      (true, _) => '服务端更新信息缺少有效的 HTTPS 商店链接，本次不会阻止使用。',
      (_, AppUpdateStatus.upToDate) => '当前安装包已是服务端配置的最新版本。',
      (_, AppUpdateStatus.optional) =>
        '${localizations.text('可更新至 ')}${update!.latestVersion}${localizations.text('（构建 ')}${update.latestBuildNumber}${localizations.text('）。')}',
      (_, AppUpdateStatus.required) =>
        update!.minimumVersion.isEmpty
            ? '当前版本已不再受支持，请前往应用商店安装最新版本。'
            : '${localizations.text('当前版本低于最低支持版本 ')}${update.minimumVersion}${localizations.text('（构建 ')}${update.minimumBuildNumber}${localizations.text('）。请前往应用商店安装最新版本。')}',
      _ when _appVersionCheckFailed => '暂时无法检查更新，请确认网络后重试。',
      _ when widget.appVersionRepository != null => '服务端暂未发布此平台的版本更新信息。',
      _ => '公开发布后，新版本将通过系统应用商店安装。App 不会绕过应用商店静默更新。',
    };
    final canOpenStore =
        update?.needsUpdate == true && update?.updateUrl.isNotEmpty == true;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                update?.requiresUpdate == true
                    ? Icons.system_security_update_warning_rounded
                    : Icons.system_update_alt_rounded,
                color: update?.requiresUpdate == true
                    ? AppColors.pink
                    : AppColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_checkingAppVersion)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          if (update?.releaseNotes.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              update!.releaseNotes,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ],
          if (update?.forceUpdateEnabled == true &&
              update?.minimumVersion.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.pink.withValues(alpha: .22),
                ),
              ),
              child: Text(
                '${localizations.text('强制更新策略：最低支持 ')}${update!.minimumVersion}${localizations.text('（构建 ')}${update.minimumBuildNumber}${localizations.text('）')}',
                style: TextStyle(
                  color: AppColors.pink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (canOpenStore)
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('version-update'),
                    onPressed: () => _openUpdateUrl(update!.updateUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('前往更新'),
                  ),
                ),
              if (canOpenStore) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('version-check-update'),
                  onPressed: _checkingAppVersion
                      ? null
                      : () => _checkForAppUpdate(packageInfo),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('检查更新'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdateUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      AppNotice.error(context, '暂时无法打开应用商店，请稍后重试。', title: '打开失败');
    }
  }

  Future<void> _copyVersionInfo(PackageInfo packageInfo) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${packageInfo.appName} ${packageInfo.version} (${packageInfo.buildNumber})\n'
              '${packageInfo.packageName}\n$_platformLabel',
        ),
      );
      if (mounted) {
        AppNotice.success(context, '版本号和构建信息已复制', title: '复制成功');
      }
    } catch (_) {
      if (mounted) {
        AppNotice.error(context, '暂时无法复制，请稍后再试。', title: '复制失败');
      }
    }
  }

  Future<void> _copyUserId() async {
    final userId = _shortUserId(widget.profileUserId);
    if (userId == null) return;
    await Clipboard.setData(ClipboardData(text: userId));
    if (mounted) AppNotice.success(context, 'UID 已复制', title: '复制成功');
  }

  String? _shortUserId(String? value) {
    final source = value?.trim() ?? '';
    final hex = source.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();
    if (hex.length < 8) return source.isEmpty ? null : source;
    final suffix = hex.substring(hex.length - 8);
    return 'UID-${suffix.substring(0, 4)}-${suffix.substring(4)}';
  }

  String get _platformLabel => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.android => 'Android',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };

  String _installerLabel(String? installerStore) {
    final store = installerStore?.toLowerCase();
    if (store == null || store.isEmpty) return '直接安装';
    if (store.contains('testflight')) return 'TestFlight';
    if (store.contains('apple') || store.contains('appstore')) {
      return 'App Store';
    }
    if (store.contains('vending') || store.contains('google')) {
      return 'Google Play';
    }
    return installerStore!;
  }

  Widget _languagePage() {
    final systemLocale = View.of(context).platformDispatcher.locale;
    final matchingSystemLanguage = AppLanguage.releaseLanguages.where(
      (language) => language.locale?.languageCode == systemLocale.languageCode,
    );
    final systemLabel = matchingSystemLanguage.isEmpty
        ? systemLocale.toLanguageTag()
        : matchingSystemLanguage.first.nativeName;
    return Column(
      children: [
        _InfoCard(
          child: Column(
            children: [
              for (
                var index = 0;
                index < AppLanguage.releaseLanguages.length;
                index++
              ) ...[
                _LanguageDestination(
                  language: AppLanguage.releaseLanguages[index],
                  selected:
                      widget.selectedLanguage ==
                      AppLanguage.releaseLanguages[index],
                  systemLabel: systemLabel,
                  onTap: () {
                    final language = AppLanguage.releaseLanguages[index];
                    widget.onLanguageChanged(language);
                    AppNotice.success(
                      context,
                      language == AppLanguage.system
                          ? '已跟随系统语言：$systemLabel'
                          : '显示语言已设为 ${language.nativeName}',
                      title: '语言偏好已保存',
                    );
                  },
                ),
                if (index != AppLanguage.releaseLanguages.length - 1)
                  Divider(height: 1, color: AppColors.line),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.translate_rounded, color: AppColors.cyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '系统会记住你的语言选择，并应用到整个 App。',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoList(List<(String, String)> items) {
    return Column(
      children: [
        for (final item in items) ...[
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  item.$2,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _legalPage({
    required List<(String, String)> items,
    required String onlineUrl,
    required Key onlineButtonKey,
  }) {
    final uri = LegalConfig.httpsUri(onlineUrl);
    return Column(
      children: [
        if (uri != null) ...[
          _InfoCard(
            child: _LegalAction(
              key: onlineButtonKey,
              icon: Icons.open_in_new_rounded,
              title: '查看公开网页版',
              subtitle: uri.toString(),
              onTap: () => _launchLegalUri(uri),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _infoList(items),
      ],
    );
  }

  Widget _supportPage() {
    final emailUri = LegalConfig.supportEmailUri;
    final supportEmail = LegalConfig.supportEmail.trim();
    return Column(
      children: [
        if (emailUri != null) ...[
          _InfoCard(
            child: _LegalAction(
              key: const Key('support-email'),
              icon: Icons.email_outlined,
              title: '发送支持邮件',
              subtitle: supportEmail,
              onTap: () => _launchLegalUri(emailUri),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _infoList([
          const (
            '账号内反馈',
            '已登录并完成邮箱验证后，可在“我的 → 设置 → 反馈”提交问题、建议、纠错或数据请求，并在“消息与反馈”查看进度。',
          ),
          (
            '支持邮箱',
            supportEmail.isEmpty
                ? '公开发布前需通过 SUPPORT_EMAIL 构建参数配置可联系的支持邮箱。内测期间可先使用账号内反馈。'
                : supportEmail,
          ),
          const (
            '安全提醒',
            '联系支持时请说明 App 版本、设备系统和问题步骤，不要发送密码、验证码、访问令牌、完整卡号、CVV、证件照片或钱包助记词。',
          ),
          const ('账号或数据请求', '申请访问、更正或删除个人数据时，需要验证账号邮箱所有权。账号删除也可在 App 设置页直接完成。'),
        ]),
      ],
    );
  }

  Future<void> _launchLegalUri(Uri uri) async {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!mounted) return;
    AppNotice.error(context, '暂时无法打开，请稍后重试。', title: '打开失败');
  }

  Widget _submission({
    required String heading,
    required String copy,
    required bool includeSubject,
    required bool includeLink,
  }) {
    return Column(
      children: [
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                copy,
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (includeSubject) ...[
                TextField(
                  key: Key('submission-subject'),
                  controller: _subjectController,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: '主题'),
                ),
                SizedBox(height: 10),
              ],
              TextField(
                key: Key('submission-description'),
                controller: _descriptionController,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(labelText: '详细说明'),
              ),
              if (includeLink) ...[
                SizedBox(height: 10),
                TextField(
                  key: Key('submission-link'),
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: '参考链接（可选）'),
                ),
              ],
              if (_formMessage != null) ...[
                SizedBox(height: 12),
                Text(
                  _formMessage!,
                  key: Key('submission-result'),
                  style: TextStyle(
                    color: _formMessage!.startsWith('反馈已提交')
                        ? AppColors.mint
                        : Color(0xFFFF8496),
                    fontSize: 12.5,
                  ),
                ),
              ],
              SizedBox(height: 16),
              FilledButton(
                key: Key('submission-submit'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(_submitting ? '正在提交…' : '提交反馈'),
              ),
              SizedBox(height: 8),
              Text(
                '提交后会同步到账号，可在“消息与反馈”中查看处理进度。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notifications() {
    final visibleItems =
        widget.submissions
            .where((item) {
              final isMessage =
                  item.category == LocalSubmissionCategory.message;
              return _notificationTab == '留言' ? isMessage : !isMessage;
            })
            .toList(growable: false)
          ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return Column(
      children: [
        _Segmented(
          values: ['更新', '贡献', '留言'],
          selected: _notificationTab,
          onChanged: (value) => setState(() => _notificationTab = value),
        ),
        SizedBox(height: 16),
        if (_notificationTab == '更新')
          _appMessages()
        else if (_notificationTab == '贡献' && visibleItems.isNotEmpty) ...[
          _SubmissionOverview(submissions: visibleItems),
          const SizedBox(height: 12),
          for (final submission in visibleItems) ...[
            _LocalSubmissionCard(submission: submission),
            const SizedBox(height: 12),
          ],
        ] else if (visibleItems.isEmpty)
          _EmptyState(
            title: _notificationTab == '留言' ? '还没有留言' : '还没有反馈',
            copy: _notificationTab == '留言'
                ? '发送留言后会在这里显示处理进度。'
                : '推荐卡片或提交纠错后会显示在这里。',
          )
        else
          for (final submission in visibleItems) ...[
            _LocalSubmissionCard(submission: submission),
            const SizedBox(height: 12),
          ],
        if (_notificationTab != '更新') ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25;
              final recommendation = OutlinedButton.icon(
                key: const Key('notifications-create-recommendation'),
                onPressed: () => widget.onOpenSection(ProfileSection.recommend),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: const Text('推荐卡片'),
              );
              final message = FilledButton.icon(
                key: const Key('notifications-create-message'),
                onPressed: () => widget.onOpenSection(ProfileSection.feedback),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('写留言'),
              );
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    recommendation,
                    const SizedBox(height: 10),
                    message,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: recommendation),
                  const SizedBox(width: 10),
                  Expanded(child: message),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            '下拉可同步最新处理状态；采纳结果和管理员回复会保留在账号中。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ],
      ],
    );
  }

  Widget _appMessages() {
    if (widget.appMessages.isEmpty) {
      return const _EmptyState(
        title: '还没有内容更新',
        copy: '资讯发布和新卡上线后，会在这里保留消息记录。',
      );
    }
    return Column(
      children: [
        for (final message in widget.appMessages) ...[
          _InfoCard(
            child: MotionPressEffect(
              child: InkWell(
                onTap: () => widget.onOpenAppMessage(message),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.title,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SubmissionOverview extends StatelessWidget {
  const _SubmissionOverview({required this.submissions});

  final List<LocalSubmission> submissions;

  @override
  Widget build(BuildContext context) {
    final inProgress = submissions
        .where((item) => item.status.isInProgress)
        .length;
    final accepted = submissions.where((item) => item.status.isAccepted).length;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的贡献',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '每条纠错和推荐都有独立处理进度，采纳结果与回复会持续保留。',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SubmissionMetric(
                label: '已提交',
                value: submissions.length,
                color: AppColors.cyan,
              ),
              const SizedBox(width: 8),
              _SubmissionMetric(
                label: '处理中',
                value: inProgress,
                color: AppColors.violet,
              ),
              const SizedBox(width: 8),
              _SubmissionMetric(
                label: '已采纳',
                value: accepted,
                color: AppColors.mint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionMetric extends StatelessWidget {
  const _SubmissionMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalSubmissionCard extends StatelessWidget {
  const _LocalSubmissionCard({required this.submission});

  final LocalSubmission submission;

  Color get _statusColor => switch (submission.status) {
    LocalSubmissionStatus.received => AppColors.cyan,
    LocalSubmissionStatus.reviewing => AppColors.violet,
    LocalSubmissionStatus.accepted ||
    LocalSubmissionStatus.resolved => AppColors.mint,
    LocalSubmissionStatus.declined => const Color(0xFFFFA45B),
  };

  IconData get _statusIcon => switch (submission.status) {
    LocalSubmissionStatus.received => Icons.inbox_rounded,
    LocalSubmissionStatus.reviewing => Icons.manage_search_rounded,
    LocalSubmissionStatus.accepted => Icons.thumb_up_alt_rounded,
    LocalSubmissionStatus.resolved => Icons.task_alt_rounded,
    LocalSubmissionStatus.declined => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final title = submission.cardName ?? submission.subject;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  submission.category.label,
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      submission.status.label,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (title?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              title!,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            submission.description,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (submission.link case final link?) ...[
            const SizedBox(height: 9),
            Text(
              link,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.cyan, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 16),
          _SubmissionProgress(status: submission.status),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _statusColor.withValues(alpha: .16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.statusNote ?? submission.status.description,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '最后更新 ${_formatSubmissionTime(context, submission.lastActivityAt)}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (submission.adminReply case final reply?) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: .16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.cyan,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '处理回复',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (submission.repliedAt case final repliedAt?) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatSubmissionTime(context, repliedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reply,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '提交于 ${_formatSubmissionTime(context, submission.createdAt)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _SubmissionProgress extends StatelessWidget {
  const _SubmissionProgress({required this.status});

  final LocalSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final progress = switch (status) {
      LocalSubmissionStatus.received => 0,
      LocalSubmissionStatus.reviewing => 1,
      _ => 2,
    };
    final labels = ['已收到', '审核中', progress == 2 ? status.label : '处理结果'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          _SubmissionProgressNode(
            label: labels[index],
            active: index <= progress,
            current: index == progress,
          ),
          if (index < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: index < progress
                    ? AppColors.mint.withValues(alpha: .62)
                    : AppColors.line,
              ),
            ),
        ],
      ],
    );
  }
}

class _SubmissionProgressNode extends StatelessWidget {
  const _SubmissionProgressNode({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.mint : AppColors.textMuted;
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? color.withValues(alpha: current ? .2 : .12)
                  : AppColors.line,
              border: Border.all(
                color: active ? color : AppColors.textMuted,
                width: current ? 2 : 1,
              ),
            ),
            child: active && !current
                ? Icon(Icons.check_rounded, color: color, size: 13)
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: current ? color : AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSubmissionTime(BuildContext context, DateTime value) {
  final date = value.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatCompactDate(date)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class _LanguageDestination extends StatelessWidget {
  const _LanguageDestination({
    required this.language,
    required this.selected,
    required this.systemLabel,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final String systemLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: InkWell(
        key: Key('language-${language.storageKey}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    language.flag,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      if (language == AppLanguage.system) ...[
                        const SizedBox(height: 3),
                        Text(
                          '当前系统：$systemLabel',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : MotionTokens.stateChange,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.cyan.withValues(alpha: .14)
                        : Colors.transparent,
                  ),
                  child: MotionStateIcon(
                    stateKey: selected,
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.circle_outlined,
                      color: selected ? AppColors.cyan : Colors.transparent,
                      size: 22,
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

class _VersionFactRow extends StatelessWidget {
  const _VersionFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsToggle extends StatefulWidget {
  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;
  final bool enabled;

  @override
  State<_SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<_SettingsToggle> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(widget.icon, color: AppColors.cyan),
      title: Text(
        widget.title,
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: _busy
          ? SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.cyan,
              ),
            )
          : Switch.adaptive(
              value: widget.value,
              onChanged: !widget.enabled
                  ? null
                  : (value) async {
                      setState(() => _busy = true);
                      await widget.onChanged(value);
                      if (mounted) setState(() => _busy = false);
                    },
            ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingTextFlex,
    this.trailing,
    this.actionLabel,
    this.onTap,
    this.showChevron = true,
    this.minHeight = 68,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final int? trailingTextFlex;
  final Widget? trailing;
  final String? actionLabel;
  final bool showChevron;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.violet.withValues(alpha: .07),
        highlightColor: AppColors.violet.withValues(alpha: .03),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: AppColors.cyan, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing case final widget?) ...[
                widget,
                const SizedBox(width: 8),
              ] else if (trailingText case final text?) ...[
                if (trailingTextFlex case final flex?)
                  Expanded(
                    flex: flex,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        text,
                        maxLines: 1,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(width: 4),
              ],
              if (actionLabel case final label?) ...[
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSettingPreview extends StatelessWidget {
  const _AvatarSettingPreview({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim();
    if (source == null || source.isEmpty) {
      return Text(
        '默认',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        source,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Text(
          '已设置',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HapticStrengthSetting extends StatelessWidget {
  const _HapticStrengthSetting({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final AppHapticStrength value;
  final bool enabled;
  final ValueChanged<AppHapticStrength> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.cyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '卡片滑动强度',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            IgnorePointer(
              ignoring: !enabled,
              child: _Segmented(
                values: AppHapticStrength.values
                    .map((strength) => strength.label)
                    .toList(growable: false),
                selected: value.label,
                onChanged: (label) {
                  final next = AppHapticStrength.values.firstWhere(
                    (strength) => strength.label == label,
                  );
                  onChanged(next);
                  AppHaptics.cardSwipe();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.section,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final ProfileSection section;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MotionPressEffect(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.violet.withValues(alpha: .07),
        highlightColor: AppColors.violet.withValues(alpha: .03),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: AppColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLogoutAction extends StatefulWidget {
  const _SettingsLogoutAction({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<_SettingsLogoutAction> createState() => _SettingsLogoutActionState();
}

class _SettingsDeleteAccountAction extends StatefulWidget {
  const _SettingsDeleteAccountAction({required this.onDeleteAccount});

  final Future<bool> Function() onDeleteAccount;

  @override
  State<_SettingsDeleteAccountAction> createState() =>
      _SettingsDeleteAccountActionState();
}

class _SettingsDeleteAccountActionState
    extends State<_SettingsDeleteAccountAction> {
  bool _busy = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除账号？'),
        content: const Text(
          '这会永久删除账号及已同步的卡包、收藏、历史、反馈和 Pro 工作区数据，无法恢复。已有应用商店订阅不会自动取消。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD94D67),
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final deleted = await widget.onDeleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    if (deleted) {
      AppNotice.success(context, '账号和云端数据已删除。', title: '账号已删除');
    } else {
      AppNotice.error(context, '账号删除失败，请重新登录后重试。', title: '未能删除账号');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('settings-delete-account'),
      onPressed: _busy ? null : _confirmAndDelete,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: const Color(0xFFB9435A),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(_busy ? '正在删除账号…' : '删除账号'),
    );
  }
}

class _SettingsLogoutActionState extends State<_SettingsLogoutAction> {
  bool _busy = false;

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后将回到只读演示模式；重新登录即可恢复账号功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: OutlinedButton.icon(
        key: const Key('settings-logout'),
        onPressed: _busy ? null : _confirmAndLogout,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(_busy ? '正在退出…' : '退出登录'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: const Color(0xFFD94D67),
          side: const BorderSide(color: Color(0x55E15A72)),
          backgroundColor: const Color(0x0CFF637C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          key: Key('profile-subpage-back'),
          onPressed: onBack,
          tooltip: '返回',
          icon: Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: Size(48, 48),
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.glassStrong,
            side: BorderSide(color: AppColors.line),
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      ),
    );
  }
}

class _LegalAction extends StatelessWidget {
  const _LegalAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, color: AppColors.cyan, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.copy});

  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: SizedBox(
        height: 142,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 30),
            SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              copy,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedGlassSegment<String>(
    height: 48,
    padding: 5,
    fontSize: 13,
    radius: 24,
    items: [
      for (final value in values)
        GlassSegmentItem(
          value: value,
          label: value,
          key: Key('segment-$value'),
        ),
    ],
    selected: selected,
    onChanged: onChanged,
  );
}
