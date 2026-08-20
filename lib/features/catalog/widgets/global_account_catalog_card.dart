import 'package:cardfi/core/motion/pressable_scale.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:cardfi/features/catalog/widgets/global_account_cover.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

class GlobalAccountCatalogCard extends StatelessWidget {
  const GlobalAccountCatalogCard({
    required this.card,
    required this.onTap,
    this.onTapWithGeometry,
    this.sharedContentHidden = false,
    super.key,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final ValueChanged<CatalogCardSourceGeometry>? onTapWithGeometry;
  final bool sharedContentHidden;

  @override
  Widget build(BuildContext context) {
    final coverKey = GlobalKey();
    final titleKey = GlobalKey();
    final localizations = AppLocalizations.of(context);
    final transferCurrencies = card.transferCurrencies;
    final transferCurrencyText = transferCurrencies.isEmpty
        ? localizations.text('支持转账币种以官方实时页面为准')
        : '${localizations.text('支持转账币种')}：${transferCurrencies.join(' · ')}';

    void handleTap() {
      final coverBox = coverKey.currentContext?.findRenderObject();
      final titleBox = titleKey.currentContext?.findRenderObject();
      if (onTapWithGeometry != null &&
          coverBox is RenderBox &&
          titleBox is RenderBox) {
        onTapWithGeometry!(
          CatalogCardSourceGeometry(
            artworkRect: coverBox.localToGlobal(Offset.zero) & coverBox.size,
            titleRect: titleBox.localToGlobal(Offset.zero) & titleBox.size,
          ),
        );
        return;
      }
      onTap();
    }

    return PressableScale(
      onTap: handleTap,
      scale: .98,
      semanticLabel: '查看${card.name}全球账户详情',
      builder: (context, pressed) => Container(
        key: Key('global-account-card-${card.id}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF56628C).withValues(
                alpha: AppColors.isDark
                    ? (pressed ? .10 : .18)
                    : (pressed ? .08 : .16),
              ),
              blurRadius: pressed ? 14 : 26,
              spreadRadius: -4,
              offset: Offset(0, pressed ? 5 : 12),
            ),
            if (!AppColors.isDark)
              BoxShadow(
                color: AppColors.violet.withValues(
                  alpha: pressed ? .025 : .055,
                ),
                blurRadius: pressed ? 8 : 18,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: sharedContentHidden ? 0 : 1,
              child: ClipRRect(
                key: coverKey,
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GlobalAccountCover(card: card, compact: true),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Opacity(
                    opacity: sharedContentHidden ? 0 : 1,
                    child: Text(
                      card.name,
                      key: titleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              transferCurrencyText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.cyan,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '查看支持币种、收款能力与开户条件',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
