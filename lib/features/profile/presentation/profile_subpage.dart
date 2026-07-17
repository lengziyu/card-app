import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:card_app/features/home/domain/home_card_layout.dart';
import 'package:card_app/features/profile/presentation/profile_page.dart';
import 'package:card_app/features/ranking/domain/local_article.dart';
import 'package:flutter/material.dart';

class ProfileSubpage extends StatefulWidget {
  const ProfileSubpage({
    required this.section,
    required this.cards,
    required this.favoriteCards,
    required this.recentCards,
    required this.favoriteArticles,
    required this.cardHeightScale,
    required this.onCardHeightScaleChanged,
    required this.onBack,
    required this.onOpenCard,
    required this.onOpenArticle,
    super.key,
  });

  final ProfileSection section;
  final List<CardSummary> cards;
  final List<CardSummary> favoriteCards;
  final List<CardSummary> recentCards;
  final List<LocalArticle> favoriteArticles;
  final double cardHeightScale;
  final ValueChanged<double> onCardHeightScaleChanged;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final ValueChanged<LocalArticle> onOpenArticle;

  @override
  State<ProfileSubpage> createState() => _ProfileSubpageState();
}

class _ProfileSubpageState extends State<ProfileSubpage> {
  String _language = '中文';
  String _favoriteTab = '卡片';
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  String? _formMessage;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _previewSubmit() {
    if (_descriptionController.text.trim().length < 8) {
      setState(() => _formMessage = '请至少输入 8 个字的说明');
      return;
    }
    _subjectController.clear();
    _descriptionController.clear();
    _linkController.clear();
    setState(() => _formMessage = '表单预览完成，内容未发送或保存。');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: Key('profile-subpage-${widget.section.name}'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
      children: [
        _Header(title: widget.section.title, onBack: widget.onBack),
        SizedBox(height: 22),
        switch (widget.section) {
          ProfileSection.cards => _collection(
            title: '本地已添加卡片',
            emptyCopy: '还没有添加卡片，可从市场或添加页选择。',
          ),
          ProfileSection.favorites => _favorites(),
          ProfileSection.history => _collection(
            title: '最近浏览',
            emptyCopy: '浏览卡片详情后会显示在这里。',
            items: widget.recentCards,
          ),
          ProfileSection.settings => _settings(),
          ProfileSection.language => _languagePage(),
          ProfileSection.help => _infoList([
            ('如何添加卡片？', '进入市场或点击底部加号，选择卡片后即可加入本地收藏。'),
            ('卡片资料来自哪里？', '资料整理自公开来源；详情页会展示来源说明，最终规则以发卡方为准。'),
            ('为什么不能正式登录？', '现有认证服务尚未通过移动端安全要求，因此当前只开放 UI 预览。'),
            ('会收集身份证或护照吗？', '不会。App 只展示公开的 KYC 要求标签，不接收或保存证件。'),
            ('排行是投资建议吗？', '不是。排行仅用于信息整理和界面演示，不构成金融建议。'),
          ]),
          ProfileSection.about => _infoList([
            ('关于集卡', '集卡是一款用于浏览、整理和比较卡片公开资料的信息工具。'),
            ('独立项目', 'App 由个人开发者维护，不代表任何银行、卡组织或发卡平台。'),
            ('隐私原则', '不收集 KYC 材料，不接入广告，不出售用户数据。'),
            ('联系与反馈', '正式反馈服务接入前，可先使用在线留言页面预览反馈流程。'),
          ]),
          ProfileSection.services => _infoList([
            ('跨设备同步', '待安全账号服务完成后提供；当前收藏只存在于演示状态。'),
            ('订阅服务', '当前项目不提供付费订阅、会员购买或功能付费墙。'),
            ('后续能力', '离线缓存、更新提醒等功能将在独立评审后逐步加入。'),
          ]),
          ProfileSection.recommend => _submission(
            heading: '推荐一张值得收录的卡片',
            copy: '请说明卡片名称、发行方和推荐理由，链接可选。',
            includeSubject: false,
            includeLink: true,
          ),
          ProfileSection.message => _submission(
            heading: '给我们留言',
            copy: '当前只验证留言表单体验，不会向服务器发送内容。',
            includeSubject: true,
            includeLink: false,
          ),
          ProfileSection.notifications => _notifications(),
        },
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
                  onPressed: () => widget.onCardHeightScaleChanged(1),
                  child: Text('恢复默认'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _InfoCard(
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, color: AppColors.cyan),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '当前为游客模式，正式账号设置暂不可用。',
                  style: TextStyle(color: AppColors.textMuted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _languagePage() {
    return _InfoCard(
      child: Column(
        children: [
          for (final language in ['中文', 'English'])
            InkWell(
              key: Key('language-$language'),
              onTap: () => setState(() => _language = language),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _language == language
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: _language == language
                          ? AppColors.cyan
                          : AppColors.textMuted,
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language,
                            style: TextStyle(color: AppColors.text),
                          ),
                          SizedBox(height: 3),
                          Text(
                            language == '中文' ? '当前界面语言' : '完整英文文案将在后续补齐',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
                    color: _formMessage!.startsWith('表单')
                        ? AppColors.mint
                        : Color(0xFFFF8496),
                    fontSize: 12.5,
                  ),
                ),
              ],
              SizedBox(height: 16),
              FilledButton(
                key: Key('submission-submit'),
                onPressed: _previewSubmit,
                child: Text('预览提交'),
              ),
              SizedBox(height: 8),
              Text(
                '账号与反馈服务暂未接入，内容不会发送或保存。',
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
    return Column(
      children: [
        _Segmented(
          values: ['反馈', '留言'],
          selected: _favoriteTab == '文章' ? '留言' : '反馈',
          onChanged: (value) =>
              setState(() => _favoriteTab = value == '留言' ? '文章' : '卡片'),
        ),
        SizedBox(height: 16),
        const _EmptyState(title: '暂无消息', copy: '正式账号和反馈服务接入后，处理进度与回复会显示在这里。'),
      ],
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
