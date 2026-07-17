import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/interactive_card_artwork.dart';
import 'package:flutter/material.dart';

class CardPreviewPage extends StatelessWidget {
  const CardPreviewPage({
    required this.card,
    required this.detail,
    required this.added,
    required this.favorite,
    required this.onBack,
    required this.onAddedChanged,
    required this.onFavoriteChanged,
    required this.onCorrection,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: Key('card-preview-page'),
      children: [
        ListView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 14, 24, 112 + bottomInset),
          children: [
            _DetailNavigation(onBack: onBack),
            SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.586,
              child: InteractiveCardArtwork(card: card),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '轻触并移动可查看普通卡面动效',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 26),
            Text(
              card.name,
              key: Key('detail-title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 8),
            Text(card.issuer, style: Theme.of(context).textTheme.bodyMedium),
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
            SizedBox(height: 20),
            _BasicInfo(detail: detail),
            SizedBox(height: 16),
            _KycBlock(card: card, detail: detail),
            if (detail.paymentChannels.isNotEmpty) ...[
              SizedBox(height: 16),
              _PaymentBlock(channels: detail.paymentChannels),
            ],
            SizedBox(height: 16),
            _FeatureBlock(features: detail.features),
            SizedBox(height: 16),
            _FeeBlock(detail: detail),
            SizedBox(height: 16),
            _SourceBlock(detail: detail),
            SizedBox(height: 12),
            OutlinedButton.icon(
              key: Key('detail-favorite'),
              onPressed: () => onFavoriteChanged(!favorite),
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              label: Text(favorite ? '已收藏，点击取消' : '收藏卡片'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: favorite ? AppColors.pink : AppColors.text,
                side: BorderSide(color: AppColors.line),
              ),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              key: Key('detail-correction'),
              onPressed: onCorrection,
              icon: Icon(Icons.edit_note_rounded),
              label: Text('发现信息有误？提交纠正'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.text,
                side: BorderSide(color: AppColors.line),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomInset),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00101828), Color(0xFF0B1120)],
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: Key('detail-toggle-card'),
                onPressed: () => onAddedChanged(!added),
                icon: Icon(added ? Icons.check_rounded : Icons.add_rounded),
                label: Text(added ? '已添加，点击移除' : '添加到我的卡片'),
                style: FilledButton.styleFrom(
                  backgroundColor: added ? AppColors.glassStrong : null,
                  foregroundColor: AppColors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: AppColors.line),
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

class _DetailNavigation extends StatelessWidget {
  const _DetailNavigation({required this.onBack});

  final VoidCallback onBack;

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            '本地演示详情',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BasicInfo extends StatelessWidget {
  const _BasicInfo({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: Key('detail-basic-info'),
      title: '基本信息',
      child: Column(
        children: [
          _InfoRow(label: '适用地区', value: detail.region),
          _InfoRow(label: '入金方式', value: detail.funding),
          _InfoRow(label: '开放状态', value: detail.availability, isLast: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
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
    return _DetailPanel(
      key: Key('detail-kyc'),
      title: 'KYC 与身份材料',
      subtitle: '仅展示公开资料标签，不收集证件',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          SizedBox(height: 14),
          Text(
            detail.kycNote,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            supported ? Icons.check_circle_outline : Icons.help_outline,
            color: color,
            size: 16,
          ),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              '$label · ${supported ? '资料提及' : '待确认'}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
    return _DetailPanel(
      key: Key('detail-features'),
      title: '核心特点',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final feature in features)
                Container(
                  width: width,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _icon(feature.icon),
                        color: AppColors.cyan,
                        size: 21,
                      ),
                      SizedBox(height: 10),
                      Text(
                        feature.text,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeeBlock extends StatelessWidget {
  const _FeeBlock({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      key: Key('detail-fees'),
      title: '费用与规则',
      child: Column(
        children: [
          for (var index = 0; index < detail.fees.length; index++)
            _InfoRow(
              label: detail.fees[index].label,
              value: detail.fees[index].value,
              isLast: index == detail.fees.length - 1,
            ),
          SizedBox(height: 12),
          Text(
            detail.note,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.sourceLabel,
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '本 App 仅整理公开信息，不提供金融服务。卡片费用、地区限制、KYC 和申请结果均以发卡方最新官方规则为准。',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
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
