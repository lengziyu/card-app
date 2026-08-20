import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/motion/pressable_scale.dart';
import 'package:cardfi/core/motion/motion_widgets.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

@immutable
class CatalogCardSourceGeometry {
  const CatalogCardSourceGeometry({
    required this.artworkRect,
    required this.titleRect,
  });

  final Rect artworkRect;
  final Rect titleRect;
}

class CatalogCardRow extends StatelessWidget {
  const CatalogCardRow({
    required this.card,
    required this.onTap,
    this.added,
    this.onToggleAdded,
    this.toggleKey,
    this.enableMotion = true,
    this.sharedContentHidden = false,
    this.onTapWithGeometry,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final bool? added;
  final ValueChanged<bool>? onToggleAdded;
  final Key? toggleKey;
  final bool enableMotion;
  final bool sharedContentHidden;
  final ValueChanged<CatalogCardSourceGeometry>? onTapWithGeometry;

  @override
  Widget build(BuildContext context) {
    final isAdded = added ?? false;
    final artworkKey = GlobalKey();
    final titleKey = GlobalKey();

    void handleTap() {
      final artworkBox = artworkKey.currentContext?.findRenderObject();
      final titleBox = titleKey.currentContext?.findRenderObject();
      if (onTapWithGeometry != null &&
          artworkBox is RenderBox &&
          titleBox is RenderBox) {
        onTapWithGeometry!(
          CatalogCardSourceGeometry(
            artworkRect:
                artworkBox.localToGlobal(Offset.zero) & artworkBox.size,
            titleRect: titleBox.localToGlobal(Offset.zero) & titleBox.size,
          ),
        );
        return;
      }
      onTap();
    }

    Widget buildSurface(bool pressed, {required bool ownsTap}) => Container(
      key: Key('catalog-card-surface-${card.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: enableMotion
            ? _marketShadow(pressed)
            : AppColors.isDark
            ? const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 18,
                  spreadRadius: -3,
                  offset: Offset(0, 8),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x2863729F),
                  blurRadius: 22,
                  spreadRadius: -3,
                  offset: Offset(0, 9),
                ),
                BoxShadow(
                  color: Color(0x145C73FF),
                  blurRadius: 10,
                  spreadRadius: -4,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        key: ownsTap ? Key('catalog-card-${card.id}') : null,
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ownsTap ? null : Key('catalog-card-${card.id}'),
          onTap: ownsTap ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 88),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      key: artworkKey,
                      width: 112,
                      height: 70,
                      child: Opacity(
                        opacity: sharedContentHidden ? 0 : 1,
                        child: card.isGlobalAccount
                            ? _GlobalAccountArtwork(card: card)
                            : CardArtwork(
                                card: card,
                                showGeneratedLabels: false,
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: sharedContentHidden ? 0 : 1,
                          child: Text(
                            card.name,
                            key: titleKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          _decisionSubtitle(card),
                          key: Key('catalog-card-subtitle-${card.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  if (onToggleAdded != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filledTonal(
                        key: toggleKey ?? Key('search-toggle-${card.id}'),
                        onPressed: () => onToggleAdded!(!isAdded),
                        tooltip: isAdded ? '移除' : '添加',
                        icon: MotionStateIcon(
                          stateKey: isAdded,
                          child: Icon(
                            isAdded ? Icons.check_rounded : Icons.add_rounded,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: isAdded
                              ? AppColors.mint
                              : AppColors.text,
                          backgroundColor: isAdded
                              ? AppColors.mint.withValues(alpha: 0.14)
                              : AppColors.violet.withValues(alpha: 0.24),
                        ),
                      ),
                    )
                  else
                    card.isGlobalAccount
                        ? const _GlobalAccountMark()
                        : _CardNetworkMark(
                            network: card.network,
                            fallback: card.label,
                          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!enableMotion) return buildSurface(false, ownsTap: false);
    return PressableScale(
      onTap: handleTap,
      semanticLabel: '查看${card.name}详情',
      builder: (context, pressed) => buildSurface(pressed, ownsTap: true),
    );
  }

  List<BoxShadow> _marketShadow(bool pressed) {
    if (AppColors.isDark) {
      return [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: pressed ? .08 : .14),
          blurRadius: pressed ? 9 : 14,
          spreadRadius: -3,
          offset: Offset(0, pressed ? 3 : 6),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF63729F).withValues(alpha: pressed ? .06 : .12),
        blurRadius: pressed ? 10 : 16,
        spreadRadius: -3,
        offset: Offset(0, pressed ? 3 : 6),
      ),
      BoxShadow(
        color: const Color(0xFF5C73FF).withValues(alpha: pressed ? .025 : .05),
        blurRadius: pressed ? 5 : 8,
        spreadRadius: -4,
        offset: Offset(0, pressed ? 2 : 3),
      ),
    ];
  }
}

String _decisionSubtitle(CardSummary card) {
  final application = _applicationSummary(card);
  final benefit = _benefitSummary(card.cashbackRate);
  final freshness = _freshnessSummary(card.updatedAt);
  return <String?>[
    benefit,
    application,
    if (benefit == null) freshness,
  ].whereType<String>().join(' · ');
}

String _applicationSummary(CardSummary card) {
  final summary = card.kycSummary.trim();
  if (summary.isNotEmpty && summary != '申请条件待确认') {
    return _isDocumentSummary(summary) ? '证件：$summary' : summary;
  }

  final documents = KycDocument.values
      .where(card.kycDocuments.contains)
      .map((document) => document.label)
      .join(' / ');
  if (documents.isNotEmpty) return '证件：$documents';
  return '申请条件待确认';
}

bool _isDocumentSummary(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll('身份证', '')
      .replaceAll('护照', '')
      .replaceAll('id card', '')
      .replaceAll('passport', '')
      .replaceAll(RegExp(r'[\s/、,，&]+'), '');
  return normalized.isEmpty;
}

String? _benefitSummary(String source) {
  final value = source.trim();
  if (value.isEmpty) return null;
  final normalized = value.toLowerCase();
  if (normalized == 'none' ||
      normalized == 'low / none' ||
      normalized == 'n/a' ||
      normalized == '无') {
    return null;
  }
  if (normalized.contains('apy') || normalized.contains('yield')) {
    final rate = RegExp(r'\d+(?:\.\d+)?%').firstMatch(value)?.group(0);
    return rate == null ? '收益权益' : '收益最高约 $rate APY';
  }
  if (value.contains(r'$')) {
    return value.startsWith('最高') ? '奖励$value' : '奖励 $value';
  }
  if (value.contains('%')) {
    return value.startsWith('最高') ? '最高返现${value.substring(2)}' : '返现 $value';
  }
  return '权益：$value';
}

String? _freshnessSummary(DateTime? updatedAt) {
  if (updatedAt == null) return null;
  final local = updatedAt.toLocal();
  return '${local.month}月${local.day}日更新';
}

class _GlobalAccountArtwork extends StatelessWidget {
  const _GlobalAccountArtwork({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) {
    final tint = Color(card.tint);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: .88), const Color(0xFF1D2635)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.public_rounded,
              color: Colors.white.withValues(alpha: .9),
            ),
            const Spacer(),
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white.withValues(alpha: .82),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalAccountMark extends StatelessWidget {
  const _GlobalAccountMark();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.cyan.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.cyan.withValues(alpha: .28)),
    ),
    child: Text(
      '账户',
      style: TextStyle(
        color: AppColors.isDark
            ? const Color(0xFF83DFFF)
            : const Color(0xFF197D99),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CardNetworkMark extends StatelessWidget {
  const _CardNetworkMark({required this.network, required this.fallback});

  final CardNetwork network;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Align(
        alignment: Alignment.centerRight,
        child: switch (network) {
          CardNetwork.visa => Text(
            'VISA',
            style: TextStyle(
              color: AppColors.isDark
                  ? const Color(0xFF4F86FF)
                  : const Color(0xFF0A347E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.2,
            ),
          ),
          CardNetwork.mastercard => const _MastercardMark(),
          CardNetwork.other => Text(
            fallback.split('·').first.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        },
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 43,
      height: 28,
      child: Stack(
        children: [
          Positioned(left: 1, top: 3, child: _circle(const Color(0xFFEB001B))),
          Positioned(
            right: 1,
            top: 3,
            child: _circle(const Color(0xFFF79E1B).withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }

  Widget _circle(Color color) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
