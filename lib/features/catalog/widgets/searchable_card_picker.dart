import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/motion/app_bottom_sheet.dart';
import 'package:cardfi/core/motion/app_haptics.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/catalog/widgets/card_artwork.dart';
import 'package:cardfi/features/catalog/widgets/catalog_card_row.dart';
import 'package:flutter/material.dart' hide Text;

class SearchableCardPicker extends StatelessWidget {
  const SearchableCardPicker({
    required this.cards,
    required this.selected,
    required this.onChanged,
    this.label = '关联卡片',
    this.sheetTitle = '选择关联卡片',
    this.sheetKey = const Key('searchable-card-picker-sheet'),
    this.searchKey = const Key('searchable-card-picker-search'),
    super.key,
  });

  final List<CardSummary> cards;
  final CardSummary? selected;
  final ValueChanged<CardSummary> onChanged;
  final String label;
  final String sheetTitle;
  final Key sheetKey;
  final Key searchKey;

  Future<void> _open(BuildContext context) async {
    AppHaptics.selection();
    final card = await showAppDraggableSheet<CardSummary>(
      context: context,
      initialSize: .84,
      minSize: .48,
      maxSize: .94,
      barrierAlpha: .42,
      builder: (context, scrollController) => _SearchableCardPickerSheet(
        cards: cards,
        selectedId: selected?.id,
        title: sheetTitle,
        sheetKey: sheetKey,
        searchKey: searchKey,
        scrollController: scrollController,
      ),
    );
    if (card != null && card.id != selected?.id) onChanged(card);
  }

  @override
  Widget build(BuildContext context) {
    final card = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.glassStrong,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: card == null
                  ? const SizedBox(
                      height: 54,
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded),
                          SizedBox(width: 10),
                          Expanded(child: Text('搜索并选择一张卡片')),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    )
                  : _SelectedCard(card: card),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (card.issuer.trim().isNotEmpty) card.issuer.trim(),
      if (card.cashbackRate.trim().isNotEmpty) card.cashbackRate.trim(),
      if (card.kycSummary.trim().isNotEmpty) card.kycSummary.trim(),
    ];
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 104,
            height: 65,
            child: CardArtwork(card: card, showGeneratedLabels: false),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                details.isEmpty
                    ? card.category.label
                    : details.take(2).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 20),
      ],
    );
  }
}

class _SearchableCardPickerSheet extends StatefulWidget {
  const _SearchableCardPickerSheet({
    required this.cards,
    required this.selectedId,
    required this.title,
    required this.sheetKey,
    required this.searchKey,
    required this.scrollController,
  });

  final List<CardSummary> cards;
  final String? selectedId;
  final String title;
  final Key sheetKey;
  final Key searchKey;
  final ScrollController scrollController;

  @override
  State<_SearchableCardPickerSheet> createState() =>
      _SearchableCardPickerSheetState();
}

class _SearchableCardPickerSheetState
    extends State<_SearchableCardPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cards = widget.cards
        .where((card) => !card.isGlobalAccount && card.matches(_query))
        .toList(growable: false);
    return Container(
      key: widget.sheetKey,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 8 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? const Color(0xF51C2030)
            : const Color(0xFAF8FAFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: widget.searchKey,
            autofocus: false,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索卡片名称或发行方',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.glassStrong,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      '没有匹配的卡片',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Stack(
                        children: [
                          CatalogCardRow(
                            card: card,
                            onTap: () => Navigator.pop(context, card),
                          ),
                          if (card.id == widget.selectedId)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IgnorePointer(
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.mint,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
