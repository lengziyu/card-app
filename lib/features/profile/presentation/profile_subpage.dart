import 'dart:async';

import 'package:card_app/core/localization/app_language.dart';
import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/profile/data/local_guest_state.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:card_app/features/notifications/data/notification_repository.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:card_app/features/shell/widgets/sticky_page_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileSubpage extends StatefulWidget {
  const ProfileSubpage({
    required this.section,
    required this.cards,
    required this.favoriteCards,
    required this.recentCards,
    required this.favoriteArticles,
    required this.submissions,
    required this.appMessages,
    required this.cardHeightScale,
    required this.onCardHeightScaleChanged,
    required this.onBack,
    required this.onOpenCard,
    required this.onOpenArticle,
    required this.onOpenSection,
    required this.onSubmit,
    required this.onDeleteSubmission,
    required this.onRefreshAppMessages,
    required this.onOpenAppMessage,
    required this.onLogin,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.pushEnabled,
    required this.onPushEnabledChanged,
    super.key,
  });

  final ProfileSection section;
  final List<CardSummary> cards;
  final List<CardSummary> favoriteCards;
  final List<CardSummary> recentCards;
  final List<LocalArticle> favoriteArticles;
  final List<LocalSubmission> submissions;
  final List<AppMessage> appMessages;
  final double cardHeightScale;
  final ValueChanged<double> onCardHeightScaleChanged;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<LocalArticle> onOpenArticle;
  final ValueChanged<ProfileSection> onOpenSection;
  final ValueChanged<LocalSubmissionDraft> onSubmit;
  final ValueChanged<String> onDeleteSubmission;
  final Future<void> Function() onRefreshAppMessages;
  final ValueChanged<AppMessage> onOpenAppMessage;
  final VoidCallback onLogin;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final bool pushEnabled;
  final Future<void> Function(bool enabled) onPushEnabledChanged;

  @override
  State<ProfileSubpage> createState() => _ProfileSubpageState();
}

class _ProfileSubpageState extends State<ProfileSubpage> {
  String _favoriteTab = '卡片';
  String _notificationTab = '反馈';
  String? _pendingDeleteId;
  PackageInfo? _packageInfo;
  bool _packageInfoFailed = false;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  String? _formMessage;

  @override
  void initState() {
    super.initState();
    if (widget.section == ProfileSection.version) {
      _loadPackageInfo();
    }
  }

  Future<void> _loadPackageInfo() async {
    setState(() => _packageInfoFailed = false);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _packageInfo = packageInfo);
    } catch (_) {
      if (!mounted) return;
      setState(() => _packageInfoFailed = true);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _submit() {
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
    widget.onSubmit(
      LocalSubmissionDraft(
        category: category,
        subject: _subjectController.text,
        description: _descriptionController.text,
        link: link,
      ),
    );
    _subjectController.clear();
    _descriptionController.clear();
    _linkController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _formMessage = '反馈已提交，感谢你的建议。');
  }

  void _requestDelete(LocalSubmission submission) {
    if (_pendingDeleteId != submission.id) {
      setState(() => _pendingDeleteId = submission.id);
      AppNotice.warning(context, '再次点击删除即可移除这条记录', title: '确认删除');
      return;
    }
    widget.onDeleteSubmission(submission.id);
    setState(() => _pendingDeleteId = null);
    AppNotice.success(context, '这条记录已删除', title: '已删除');
  }

  void _openNotifications() {
    widget.onOpenSection(ProfileSection.notifications);
    unawaited(widget.onRefreshAppMessages().catchError((_) {}));
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
          ProfileSection.cards => _collection(
            title: '已添加卡片',
            emptyCopy: '还没有添加卡片，可从市场或添加页选择。',
          ),
          ProfileSection.favorites => _favorites(),
          ProfileSection.history => _collection(
            title: '最近浏览',
            emptyCopy: '浏览卡片详情后会显示在这里。',
            items: widget.recentCards,
          ),
          ProfileSection.settings => _settings(),
          ProfileSection.version => _versionPage(),
          ProfileSection.language => _languagePage(),
          ProfileSection.help => _infoList([
            ('如何添加卡片？', '登录后，进入市场或点击底部加号即可添加和管理卡片。'),
            ('卡片资料来自哪里？', '资料整理自公开来源；详情页会展示来源说明，最终规则以发卡方为准。'),
            ('游客的数据会保存吗？', '不会。游客可以浏览公开资料；卡片、收藏和反馈等个人操作需要登录后才能使用。'),
            ('会收集身份证或护照吗？', '不会。App 只展示公开的 KYC 要求标签，不接收或保存证件。'),
            ('排行是投资建议吗？', '不是。排行仅用于信息整理和界面演示，不构成金融建议。'),
          ]),
          ProfileSection.about => _infoList([
            ('关于集卡', '集卡是一款用于浏览、整理和比较卡片公开资料的信息工具。'),
            ('独立项目', 'App 由个人开发者维护，不代表任何银行、卡组织或发卡平台。'),
            ('隐私原则', '不收集 KYC 材料，不接入广告，不出售用户数据。'),
            ('联系与反馈', '登录后可提交问题、建议和卡片信息纠错，后续可在账号中查看处理进度。'),
          ]),
          ProfileSection.services => _infoList([
            ('账号同步', '登录后可在账号中管理卡片、收藏、历史和反馈。'),
            ('跨设备同步', '待安全账号服务完成后提供；当前不会上传或跨设备同步。'),
            ('订阅服务', '当前项目不提供付费订阅、会员购买或功能付费墙。'),
            ('后续能力', '离线缓存、更新提醒等功能将在独立评审后逐步加入。'),
          ]),
          ProfileSection.recommend => _submission(
            heading: '推荐一张值得收录的卡片',
            copy: '请说明卡片名称、发行方和推荐理由，链接可选。',
            includeSubject: false,
            includeLink: true,
          ),
          ProfileSection.feedback => _feedback(),
          ProfileSection.notifications => _notifications(),
        },
      ],
    );
    return Stack(
      key: Key('profile-subpage-${widget.section.name}'),
      children: [
        if (widget.section == ProfileSection.notifications)
          AppPullToRefresh(
            onRefresh: widget.onRefreshAppMessages,
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
    List<CardSummary>? items,
  }) {
    final visibleItems = items ?? widget.cards;
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
        if (visibleItems.isEmpty)
          _EmptyState(title: '暂无内容', copy: emptyCopy)
        else
          for (final card in visibleItems) ...[
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

  Widget _settings() {
    return Column(
      children: [
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '首页卡片高度',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${homeCardHeightPercent(widget.cardHeightScale)}%',
                    style: TextStyle(color: AppColors.cyan),
                  ),
                ],
              ),
              Slider(
                key: Key('profile-card-height'),
                value: widget.cardHeightScale,
                min: homeCardHeightScaleMin,
                max: homeCardHeightScaleMax,
                onChanged: widget.onCardHeightScaleChanged,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => widget.onCardHeightScaleChanged(
                    homeCardStackDefaultScale,
                  ),
                  child: Text('恢复默认'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _InfoCard(
          child: Column(
            children: [
              _SettingsDestination(
                key: const Key('settings-feedback'),
                section: ProfileSection.feedback,
                subtitle: '登录后提交问题、建议与信息纠错',
                onTap: () => widget.onOpenSection(ProfileSection.feedback),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-version'),
                section: ProfileSection.version,
                subtitle: '当前版本、构建号与更新方式',
                onTap: () => widget.onOpenSection(ProfileSection.version),
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsToggle(
                key: const Key('settings-content-push'),
                icon: Icons.notifications_active_outlined,
                title: '内容更新提醒',
                subtitle: '资讯发布与新卡上线时通知你',
                value: widget.pushEnabled,
                onChanged: widget.onPushEnabledChanged,
              ),
              Divider(height: 1, color: AppColors.line),
              _SettingsDestination(
                key: const Key('settings-app-messages'),
                section: ProfileSection.notifications,
                subtitle: '查看资讯、新卡上线和反馈记录',
                onTap: _openNotifications,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feedback() {
    return _InfoCard(
      child: Column(
        children: [
          Icon(Icons.feedback_outlined, color: AppColors.cyan, size: 34),
          const SizedBox(height: 12),
          Text(
            '登录后提交反馈',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '问题、建议和卡片信息纠错会关联到你的账号，便于后续查看处理进度。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('feedback-login'),
            onPressed: widget.onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('登录后反馈'),
          ),
        ],
      ),
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
                      packageInfo.appName.isEmpty ? '集卡' : packageInfo.appName,
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
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '更新方式',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '公开发布后，新版本将通过 App Store 或 Google Play 安装。App 不会绕过应用商店静默更新。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('version-copy'),
            onPressed: () => _copyVersionInfo(packageInfo),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('复制版本信息'),
          ),
        ),
      ],
    );
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
    final matchingSystemLanguage = AppLanguage.values.where(
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
                index < AppLanguage.values.length;
                index++
              ) ...[
                _LanguageDestination(
                  language: AppLanguage.values[index],
                  selected:
                      widget.selectedLanguage == AppLanguage.values[index],
                  systemLabel: systemLabel,
                  onTap: () {
                    final language = AppLanguage.values[index];
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
                if (index != AppLanguage.values.length - 1)
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
                  '系统会记住你的语言选择。尚未完成翻译的业务内容会暂时使用简体中文。',
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
                    color: _formMessage!.startsWith('已保存')
                        ? AppColors.mint
                        : Color(0xFFFF8496),
                    fontSize: 12.5,
                  ),
                ),
              ],
              SizedBox(height: 16),
              FilledButton(
                key: Key('submission-submit'),
                onPressed: _submit,
                child: Text('提交反馈'),
              ),
              SizedBox(height: 8),
              Text(
                '当前不会上传；保存后可在“消息与反馈”中管理。',
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
    final visibleItems = widget.submissions
        .where((item) {
          final isMessage = item.category == LocalSubmissionCategory.message;
          return _notificationTab == '留言' ? isMessage : !isMessage;
        })
        .toList(growable: false);
    return Column(
      children: [
        _Segmented(
          values: ['更新', '反馈', '留言'],
          selected: _notificationTab,
          onChanged: (value) => setState(() => _notificationTab = value),
        ),
        SizedBox(height: 16),
        if (_notificationTab == '更新')
          _appMessages()
        else if (visibleItems.isEmpty)
          _EmptyState(
            title: _notificationTab == '留言' ? '还没有留言' : '还没有反馈',
            copy: _notificationTab == '留言' ? '登录后即可提交留言。' : '推荐卡片或提交纠错后会显示在这里。',
          )
        else
          for (final submission in visibleItems) ...[
            _LocalSubmissionCard(
              submission: submission,
              confirmingDelete: _pendingDeleteId == submission.id,
              onDelete: () => _requestDelete(submission),
            ),
            const SizedBox(height: 12),
          ],
        if (_notificationTab != '更新') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('notifications-create-recommendation'),
                  onPressed: () =>
                      widget.onOpenSection(ProfileSection.recommend),
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text('推荐卡片'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('notifications-create-message'),
                  onPressed: () =>
                      widget.onOpenSection(ProfileSection.feedback),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('写留言'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '登录后可在账号中查看反馈记录。',
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
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LocalSubmissionCard extends StatelessWidget {
  const _LocalSubmissionCard({
    required this.submission,
    required this.confirmingDelete,
    required this.onDelete,
  });

  final LocalSubmission submission;
  final bool confirmingDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = submission.createdAt.toLocal();
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
              Text(
                '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone_iphone_rounded, color: AppColors.mint, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '已提交',
                  style: TextStyle(
                    color: AppColors.mint,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: Key('submission-delete-${submission.id}'),
                onPressed: onDelete,
                icon: Icon(
                  confirmingDelete
                      ? Icons.delete_forever_rounded
                      : Icons.delete_outline_rounded,
                  size: 17,
                ),
                label: Text(confirmingDelete ? '确认删除' : '删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    return InkWell(
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
                    : const Duration(milliseconds: 240),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.cyan.withValues(alpha: .14)
                      : Colors.transparent,
                ),
                child: AnimatedScale(
                  scale: selected ? 1 : .72,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.check_rounded,
                    color: selected ? AppColors.cyan : Colors.transparent,
                    size: 22,
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
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;

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
              onChanged: (value) async {
                setState(() => _busy = true);
                await widget.onChanged(value);
                if (mounted) setState(() => _busy = false);
              },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.copy});

  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 34),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? AppColors.violet.withValues(alpha: 0.28)
                        : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: selected == value
                          ? AppColors.text
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
