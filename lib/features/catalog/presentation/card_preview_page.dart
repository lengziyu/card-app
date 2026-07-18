import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/interactive_card_artwork.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CardPreviewPage extends StatefulWidget {
  const CardPreviewPage({
    required this.card,
    required this.detail,
    required this.added,
    required this.favorite,
    required this.onBack,
    required this.onAddedChanged,
    required this.onFavoriteChanged,
    required this.onCorrection,
    required this.onViewSimilar,
    super.key,
  });

  final CardSummary card;
  final CardDetail detail;
  final bool added;
  final bool favorite;
  final VoidCallback onBack;
  final ValueChanged<bool> onAddedChanged;
  final ValueChanged<bool> onFavoriteChanged;
  final VoidCallback onCorrection;
  final VoidCallback onViewSimilar;

  @override
  State<CardPreviewPage> createState() => _CardPreviewPageState();
}

class _CardPreviewPageState extends State<CardPreviewPage> {
  CardVisualEffect _effect = CardVisualEffect.particle;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _openOfficial() async {
    final source = widget.card.sourceUrl;
    if (source == null || source.isEmpty) {
      _showMessage('这张卡片暂未提供官网地址');
      return;
    }
    final uri = Uri.tryParse(source);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showMessage('暂时无法打开官网');
    }
  }

  Future<void> _showActions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) => _DetailActionSheet(
        card: widget.card,
        added: widget.added,
        favorite: widget.favorite,
        effect: _effect,
        onFavorite: () {
          Navigator.pop(sheetContext);
          widget.onFavoriteChanged(!widget.favorite);
        },
        onEffect: (effect) {
          Navigator.pop(sheetContext);
          setState(() => _effect = effect);
          _showMessage('${_effectLabel(effect)}已启用');
        },
        onViewSimilar: () {
          Navigator.pop(sheetContext);
          widget.onViewSimilar();
        },
        onOpenOfficial: () {
          Navigator.pop(sheetContext);
          _openOfficial();
        },
        onCorrection: () {
          Navigator.pop(sheetContext);
          widget.onCorrection();
        },
        onRemove: widget.added
            ? () {
                Navigator.pop(sheetContext);
                widget.onAddedChanged(false);
              }
            : null,
      ),
    );
  }

  String _effectLabel(CardVisualEffect effect) => switch (effect) {
    CardVisualEffect.particle => '粒子效果',
    CardVisualEffect.flame => '火焰效果',
    CardVisualEffect.ice => '冰霜效果',
    CardVisualEffect.none => '无效果',
  };

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final detail = widget.detail;
    final added = widget.added;
    final onBack = widget.onBack;
    final onAddedChanged = widget.onAddedChanged;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: Key('card-preview-page'),
      children: [
        ListView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 14, 24, 112 + bottomInset),
          children: [
            _DetailNavigation(onBack: onBack, onMore: _showActions),
            SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.586,
              child: InteractiveCardArtwork(card: card, effect: _effect),
            ),
            SizedBox(height: 25),
            Text(
              card.name,
              key: Key('detail-title'),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              card.issuer,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in detail.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 18),
            _BasicInfo(detail: detail),
            SizedBox(height: 16),
            _KycBlock(card: card, detail: detail),
            if (detail.paymentChannels.isNotEmpty) ...[
              SizedBox(height: 16),
              _PaymentBlock(channels: detail.paymentChannels),
            ],
            SizedBox(height: 16),
            _OfficialAction(onTap: _openOfficial),
            SizedBox(height: 22),
            _FeatureBlock(features: detail.features),
            SizedBox(height: 28),
            _FeeBlock(detail: detail),
            SizedBox(height: 16),
            _SourceBlock(detail: detail),
            const SizedBox(height: 20),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 342),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: added
                          ? const [Color(0xFFEF5B66), Color(0xFFDA4351)]
                          : const [Color(0xFF252B38), Color(0xFF0F1421)],
                    ),
                    borderRadius: BorderRadius.circular(29),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (added
                                    ? const Color(0xFFDA4351)
                                    : const Color(0xFF141C30))
                                .withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    key: Key('detail-toggle-card'),
                    onPressed: () => onAddedChanged(!added),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                    child: Text(added ? '已添加，点击移除' : '添加到我的卡片'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfficialAction extends StatelessWidget {
  const _OfficialAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassStrong,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('detail-open-official'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '打开官方网站',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailNavigation extends StatelessWidget {
  const _DetailNavigation({required this.onBack, required this.onMore});

  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
          key: Key('preview-back'),
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
        IconButton.filledTonal(
          key: const Key('detail-more'),
          onPressed: onMore,
          tooltip: '更多操作',
          icon: const Icon(Icons.more_horiz_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.glassStrong,
            side: BorderSide(color: AppColors.line),
          ),
        ),
      ],
    );
  }
}

class _DetailActionSheet extends StatelessWidget {
  const _DetailActionSheet({
    required this.card,
    required this.added,
    required this.favorite,
    required this.effect,
    required this.onFavorite,
    required this.onEffect,
    required this.onViewSimilar,
    required this.onOpenOfficial,
    required this.onCorrection,
    required this.onRemove,
  });

  final CardSummary card;
  final bool added;
  final bool favorite;
  final CardVisualEffect effect;
  final VoidCallback onFavorite;
  final ValueChanged<CardVisualEffect> onEffect;
  final VoidCallback onViewSimilar;
  final VoidCallback onOpenOfficial;
  final VoidCallback onCorrection;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xF21C2030)
            : const Color(0xF5F8FAFF),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.glassStrong,
                    foregroundColor: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-favorite'),
              icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
              label: favorite ? '取消收藏' : '收藏卡片',
              onTap: onFavorite,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glassStrong,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '卡面效果',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final item in const [
                        (
                          CardVisualEffect.particle,
                          Icons.auto_awesome_rounded,
                          '粒子',
                        ),
                        (
                          CardVisualEffect.flame,
                          Icons.local_fire_department_rounded,
                          '火焰',
                        ),
                        (CardVisualEffect.ice, Icons.ac_unit_rounded, '冰霜'),
                        (
                          CardVisualEffect.none,
                          Icons.visibility_off_outlined,
                          '关闭',
                        ),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              key: Key('detail-effect-${item.$1.name}'),
                              onTap: () => onEffect(item.$1),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: effect == item.$1
                                      ? AppColors.violet.withValues(alpha: 0.24)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: effect == item.$1
                                        ? AppColors.violet.withValues(
                                            alpha: 0.5,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      item.$2,
                                      color: effect == item.$1
                                          ? AppColors.cyan
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.$3,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-similar'),
              icon: Icons.storefront_outlined,
              label: '查看同类卡片',
              onTap: onViewSimilar,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-official'),
              icon: Icons.open_in_new_rounded,
              label: '打开官网',
              onTap: onOpenOfficial,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-correction'),
              icon: Icons.edit_note_rounded,
              label: '提交信息纠正',
              onTap: onCorrection,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              key: const Key('detail-action-remove'),
              icon: Icons.remove_circle_outline_rounded,
              label: added ? '从我的卡片移除' : '尚未添加到我的卡片',
              onTap: onRemove,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF8496) : AppColors.text;
    return Material(
      color: AppColors.glassStrong,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: onTap == null ? AppColors.textMuted : color),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onTap == null ? AppColors.textMuted : color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasicInfo extends StatelessWidget {
  const _BasicInfo({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-basic-info'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetaCell(label: '适用地区', value: detail.region),
          Container(height: 1, color: AppColors.line),
          Row(
            children: [
              Expanded(
                child: _MetaCell(
                  label: '入金方式',
                  value: detail.funding,
                  compact: true,
                ),
              ),
              Container(width: 1, height: 78, color: AppColors.line),
              Expanded(
                child: _MetaCell(
                  label: '开放状态',
                  value: detail.availability,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBlock extends StatelessWidget {
  const _KycBlock({required this.card, required this.detail});

  final CardSummary card;
  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-kyc'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KYC 与身份材料',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '仅展示公开资料标签，不收集证件',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final document in KycDocument.values)
                _StatusPill(
                  label: document.label,
                  supported: card.kycDocuments.contains(document),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail.kycNote,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.supported});

  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final color = supported ? AppColors.mint : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            supported ? Icons.check_circle_outline : Icons.help_outline,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '$label · ${supported ? '资料提及' : '待确认'}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.channels});

  final Set<PaymentChannel> channels;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: Key('detail-payments'),
      title: '支付渠道',
      subtitle: '支持状态仍需以官方最新说明为准',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final channel in channels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                channel.label,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({required this.features});

  final List<DetailFeature> features;

  IconData _icon(DetailFeatureIcon icon) => switch (icon) {
    DetailFeatureIcon.wallet => Icons.account_balance_wallet_outlined,
    DetailFeatureIcon.shield => Icons.shield_outlined,
    DetailFeatureIcon.payments => Icons.contactless_outlined,
    DetailFeatureIcon.globe => Icons.public_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('detail-features'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '核心权益',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final feature in features)
                  Container(
                    width: width,
                    constraints: const BoxConstraints(minHeight: 82),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.isDark
                            ? const [Color(0xD0303448), Color(0xB81C2030)]
                            : [
                                Colors.white.withValues(alpha: 0.72),
                                Colors.white.withValues(alpha: 0.48),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _icon(feature.icon),
                          color: _color(feature.icon),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature.text,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Color _color(DetailFeatureIcon icon) => switch (icon) {
    DetailFeatureIcon.wallet => const Color(0xFF969BFF),
    DetailFeatureIcon.payments => const Color(0xFFA98AFF),
    DetailFeatureIcon.globe => const Color(0xFF67D4FF),
    DetailFeatureIcon.shield => const Color(0xFFB7A6FF),
  };
}

class _FeeBlock extends StatelessWidget {
  const _FeeBlock({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('detail-fees'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '费用',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final fee in detail.fees)
          _FeeRow(label: fee.label, value: fee.value),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 132,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBlock extends StatelessWidget {
  const _SourceBlock({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('detail-source'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glass.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '资料来源 · ${detail.sourceLabel}',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '资料整理自公开来源，具体费用与申请结果以发卡方规则为准。',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            SizedBox(height: 5),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
