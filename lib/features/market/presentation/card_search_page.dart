import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';
import 'package:card_app/features/catalog/widgets/catalog_card_row.dart';
import 'package:flutter/material.dart';

enum CardSearchMode { market, add }

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({
    required this.mode,
    required this.cards,
    required this.addedCardIds,
    required this.onBack,
    required this.onOpenCard,
    required this.onCardChanged,
    super.key,
  });

  final CardSearchMode mode;
  final List<CardSummary> cards;
  final Set<String> addedCardIds;
  final VoidCallback onBack;
  final ValueChanged<CardSummary> onOpenCard;
  final void Function(CardSummary card, bool added) onCardChanged;

  @override
  State<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends State<CardSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CardSummary> get _results => widget.cards
      .where((card) => card.matches(_query))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final isAddMode = widget.mode == CardSearchMode.add;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      key: Key('card-search-page'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              _BackButton(onPressed: widget.onBack),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAddMode ? '搜索添加卡片' : '搜索卡片',
                      key: Key('search-title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 3),
                    Text(
                      isAddMode ? '查找并加入演示收藏' : '按名称、发行方或类型查找',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: TextField(
            key: Key('catalog-search-field'),
            controller: _controller,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            style: TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: '搜索卡片名称或发行方',
              hintStyle: TextStyle(color: AppColors.textMuted),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: Key('clear-search'),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      tooltip: '清空搜索',
                      icon: Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.glass,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.violet),
              ),
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? const _SearchEmpty()
              : ListView.separated(
                  key: Key('search-results'),
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final card = _results[index];
                    final added = widget.addedCardIds.contains(card.id);
                    return CatalogCardRow(
                      card: card,
                      added: isAddMode ? added : null,
                      onToggleAdded: isAddMode
                          ? (value) => widget.onCardChanged(card, value)
                          : null,
                      onTap: () {
                        if (isAddMode && !added) {
                          widget.onCardChanged(card, true);
                          return;
                        }
                        widget.onOpenCard(card);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      key: Key('search-back'),
      onPressed: onPressed,
      tooltip: '返回',
      icon: Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        minimumSize: Size(48, 48),
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.glassStrong,
        side: BorderSide(color: AppColors.line),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: Key('search-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.cyan, size: 42),
            SizedBox(height: 16),
            Text('没有找到相关卡片', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text(
              '尝试更换名称、发行方或卡片类型。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
