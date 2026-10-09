import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/icons/app_icons.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/core/widgets/premium_motion.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/shell/widgets/sticky_page_header.dart';
import 'package:cardfi/features/tools/data/tools_repository.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:cardfi/features/tools/widgets/tool_components.dart';
import 'package:cardfi/features/tools/widgets/bin_lookup_content.dart';
import 'package:cardfi/features/tools/widgets/h5_tool_cards.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    required this.repository,
    required this.onBack,
    this.cards = const [],
    super.key,
  });
  final ToolsRepository repository;
  final VoidCallback onBack;
  final List<CardSummary> cards;

  @override
  State<ToolsPage> createState() => ToolsPageState();
}

class ToolsPageState extends State<ToolsPage> with WidgetsBindingObserver {
  ToolKind? _kind;
  ToolRecord? _selected;
  Future<ToolRecord>? _detail;
  late Future<Map<ToolKind, ToolAvailability>> _availability;
  final _collections = <ToolKind, Future<ToolCollection>>{};
  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  String _filter = '';
  bool _payment = false;
  final _binPageKey = GlobalKey<BinLookupContentState>();
  final _binTapGroup = Object();
  String? _expandedRequirement;

  bool get _chinese => Localizations.localeOf(context).languageCode == 'zh';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _availability = widget.repository.loadAvailability();
    _searchFocus.addListener(_searchFocusChanged);
  }

  void _searchFocusChanged() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _query.dispose();
    _searchFocus.removeListener(_searchFocusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  /// Shared by the top button, Android system back and the shell edge gesture.
  bool handleBack() {
    if (_kind == ToolKind.bin &&
        _binPageKey.currentState?.dismissPicker() == true) {
      return true;
    }
    if (_expandedRequirement != null) {
      setState(() => _expandedRequirement = null);
      return true;
    }
    if (_selected != null) {
      setState(() {
        _selected = null;
        _detail = null;
      });
      return true;
    }
    if (_kind != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _kind = null;
        _query.clear();
        _filter = '';
        _payment = false;
      });
      return true;
    }
    return false;
  }

  void _back() {
    if (!handleBack()) widget.onBack();
  }

  void _openKind(ToolKind kind) => setState(() {
    _kind = kind;
    if (kind == ToolKind.requirements) {
      _collections[kind] = _observe(widget.repository.load(kind));
    } else {
      _collections.putIfAbsent(
        kind,
        () => _observe(widget.repository.load(kind)),
      );
    }
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _kind == ToolKind.requirements) {
      unawaited(_refresh());
    }
  }

  void _openItem(ToolRecord item) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = item;
      _detail = _observe(widget.repository.detail(_kind!, item));
    });
  }

  Future<void> _refresh() async {
    final kind = _kind;
    if (kind == null) {
      setState(() {
        _availability = widget.repository.loadAvailability();
      });
      await _availability;
    } else {
      final future = widget.repository.load(kind);
      setState(() {
        _collections[kind] = future;
        if (kind == ToolKind.requirements) _expandedRequirement = null;
      });
      try {
        await future;
      } catch (_) {
        /* FutureBuilder displays the failure. */
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = publicToolUri(
      url,
      base: widget.repository.apiClient.resolve('/'),
    );
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Display the same failure for unavailable handlers. */
    }
    if (mounted) AppNotice.error(context, '暂时无法打开链接');
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final selected = _selected;
    final title = selected == null
        ? kind?.title ?? '实用工具'
        : selected.title(kind!, chinese: _chinese);
    return Stack(
      key: const Key('tools-page'),
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 84,
            ),
            child: selected != null
                ? _detailView()
                : kind == null
                ? _hub()
                : _catalog(kind),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: StickyPageHeader(
            child: Row(
              children: [
                TapRegion(
                  groupId: _binTapGroup,
                  child: IconButton.filledTonal(
                    key: const Key('tools-back'),
                    tooltip: context.tr('返回'),
                    onPressed: _back,
                    icon: const Icon(AppIcons.back, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.text,
                      backgroundColor: AppColors.glassStrong,
                      side: BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hub() => FutureBuilder<Map<ToolKind, ToolAvailability>>(
    future: _availability,
    builder: (context, snapshot) => AppPullToRefresh(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey('tools-hub'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _listPadding,
        children: [
          for (final kind in ToolKind.values)
            if (!kind.hasAvailability ||
                !snapshot.hasData ||
                snapshot.data![kind]!.enabled ||
                snapshot.data![kind]!.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _panel(
                  child: ListTile(
                    key: Key('tool-${kind.name}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    leading: _toolIcon(kind),
                    title: Text(
                      kind.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        kind.hasAvailability && !snapshot.hasData
                            ? '正在加载资料…'
                            : snapshot.data?[kind]?.failed == true
                            ? '暂时无法加载资料，点击重试'
                            : kind.description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: kind.hasAvailability && !snapshot.hasData
                        ? null
                        : snapshot.data?[kind]?.failed == true
                        ? _refresh
                        : () => _openKind(kind),
                  ),
                ),
              ),
        ],
      ),
    ),
  );

  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom);

  Widget _catalog(ToolKind kind) {
    if (kind == ToolKind.bin) {
      return BinLookupContent(
        key: _binPageKey,
        tapGroup: _binTapGroup,
        collection: _collections[kind]!,
        repository: widget.repository,
        onRefresh: _refresh,
        artwork: (item, width) => _recordArtwork(kind, item, width),
        onOpenUrl: _openUrl,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Column(
            children: [
              if (kind == ToolKind.requirements)
                ToolModeSegment(
                  items: const [('kyc', '开卡条件'), ('payment', '支付支持')],
                  selected: _payment ? 'payment' : 'kyc',
                  onChanged: (value) => setState(() {
                    _payment = value == 'payment';
                    _filter = '';
                    _expandedRequirement = null;
                  }),
                )
              else
                BeamBorder(
                  active: _searchFocus.hasFocus || _query.text.isNotEmpty,
                  child: TextField(
                    key: const Key('tools-search'),
                    controller: _query,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.tr(
                        kind == ToolKind.noKyc ? '搜索卡片名称或发行方' : '搜索',
                      ),
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      prefixIcon: Icon(
                        AppIcons.search,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.tr('清除'),
                              onPressed: () => setState(() => _query.clear()),
                              icon: const Icon(Icons.close_rounded),
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
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ToolCollection>(
            future: _collections[kind],
            builder: (context, snapshot) {
              if (snapshot.hasError) return _failure(_refresh);
              if (!snapshot.hasData) return _loading();
              final collection = snapshot.data!;
              final items = collection.items
                  .where((item) => _matches(kind, item))
                  .toList();
              return AppPullToRefresh(
                onRefresh: _refresh,
                child: ListView(
                  key: PageStorageKey('tools-list-${kind.name}'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: kind == ToolKind.requirements
                      ? EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          32 + MediaQuery.paddingOf(context).bottom,
                        )
                      : _listPadding,
                  children: [
                    if (kind == ToolKind.noKyc)
                      const ToolNotice('免 KYC 条件可能变化，费用与申请要求以发行方最新规则为准。'),
                    if (!collection.sourceAvailable)
                      _note('来源暂不可用，当前显示 H5 已保存的资料。'),
                    _collectionCaption(kind, collection, items.length),
                    if (_filters(kind, collection.items).length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: kind == ToolKind.requirements && !_payment
                            ? ToolRequirementFilters(
                                selected: _filter,
                                onChanged: (value) => setState(() {
                                  _filter = value;
                                  _expandedRequirement = null;
                                }),
                              )
                            : ToolFilterStrip(
                                items: _filters(kind, collection.items),
                                selected: _filter,
                                onChanged: (value) => setState(() {
                                  _filter = value;
                                  _expandedRequirement = null;
                                }),
                              ),
                      ),
                    if (kind == ToolKind.requirements && _payment)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '✓ 支持  ·  ! 有条件  ·  ? 待确认',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    if (items.isEmpty)
                      _empty()
                    else if ({
                      ToolKind.internationalSim,
                      ToolKind.sms,
                      ToolKind.addressProof,
                    }.contains(kind))
                      ToolDirectoryGrid(
                        items: items,
                        builder: (item) => ToolDirectoryCard(
                          key: Key('tool-record-${item.id}'),
                          kind: kind,
                          item: item,
                          base: widget.repository.apiClient.resolve('/'),
                          onTap: () => _openItem(item),
                        ),
                      )
                    else
                      for (final item in items)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: kind == ToolKind.requirements ? 8 : 12,
                          ),
                          child: _recordTile(kind, item),
                        ),
                    if (collection.sourceName.isNotEmpty)
                      _source(collection.sourceName, collection.sourceUrl),
                    if (kind == ToolKind.sms)
                      const ToolNotice('公开收件箱的短信可被他人查看，请勿用于银行等敏感账号。'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<(String, String)> _filters(
    ToolKind kind,
    List<ToolRecord> items,
  ) => switch (kind) {
    ToolKind.requirements => [
      ('', '全部'),
      if (!_payment) ...[
        ('idCard', '身份证'),
        ('passport', '护照'),
      ] else
        ..._channels,
    ],
    ToolKind.internationalSim => [
      ('', '${context.tr('全部')} (${items.length})'),
      ...{
        for (final item in items)
          item.value('countryCode'): item.localized(
            'countryName',
            chinese: _chinese,
          ),
      }.entries.map(
        (entry) => (
          entry.key,
          '${entry.value} (${items.where((item) => item.value('countryCode') == entry.key).length})',
        ),
      ),
    ],
    ToolKind.sms => [
      ('', '全部'),
      ('activation', '按次接码'),
      ('rental', '号码租用'),
      ('public', '公开免费'),
      ('app', '号码 App'),
      ('messaging', '短信通信'),
      ('bot', '机器人线索'),
      ('unknown', '其他'),
    ],
    ToolKind.addressProof => [('', '全部'), ('yes', '免费'), ('no', '收费')],
    _ => [('', '全部')],
  };

  static const _channels = [
    ('wechatPay', '微信支付'),
    ('alipay', '支付宝'),
    ('applePay', 'Apple Pay'),
    ('googlePay', 'Google Pay'),
    ('chatgpt', 'ChatGPT'),
    ('claude', 'Claude'),
  ];
  static const _requirements = [
    ('inviteCode', '邀请码'),
    ('idCard', '身份证'),
    ('passport', '护照'),
    ('overseasAddressProof', '海外地址证明'),
    ('overseasPhone', '海外手机号'),
  ];

  bool _matches(ToolKind kind, ToolRecord item) {
    final query = kind == ToolKind.requirements
        ? ''
        : _query.text.trim().toLowerCase();
    final text =
        '${item.title(kind, chinese: _chinese)} ${item.summary(kind, chinese: _chinese)} ${item.value('issuer')} ${item.value('provider')} ${item.localized('countryName', chinese: _chinese)} ${item.localized('coverage', chinese: _chinese)} ${item.value('websiteUrl')} ${item.strings('aliases').join(' ')} ${item.strings('tags').join(' ')}'
            .toLowerCase();
    if (query.isNotEmpty && !text.contains(query)) return false;
    if (_filter.isEmpty) return true;
    return switch (kind) {
      ToolKind.requirements =>
        _payment
            ? {'supported', 'conditional'}.contains(
                ToolRecord(
                  ToolRecord(item.object('card')).object('paymentSupport'),
                ).object(_filter)['status'],
              )
            : item.object('requirements')[_filter] == 'required',
      ToolKind.internationalSim => item.value('countryCode') == _filter,
      ToolKind.sms => item.strings('modes').contains(_filter),
      ToolKind.addressProof =>
        _filter == 'no'
            ? item.value('freeAvailability') == 'no'
            : {'yes', 'partial'}.contains(item.value('freeAvailability')),
      _ => true,
    };
  }

  Widget _recordTile(ToolKind kind, ToolRecord item) {
    if (kind == ToolKind.requirements) {
      return ToolComparisonCard(
        key: Key('tool-record-${item.id}'),
        item: item,
        artwork: _recordArtwork(kind, item, 57),
        payment: _payment,
        expanded: _expandedRequirement == item.id,
        onToggle: () => setState(
          () => _expandedRequirement = _expandedRequirement == item.id
              ? null
              : item.id,
        ),
        details: _payment
            ? _requirementDetails(item).skip(1).take(2).toList()
            : [
                _field('资料来源', item.value('sourceName')),
                if (item.value('sourceUrl').isNotEmpty)
                  _source(item.value('sourceName'), item.value('sourceUrl')),
                _field('资料核对', _date(item.value('checkedAt'))),
                _field('核验状态', _status(item.value('verificationStatus'))),
                if (item.localized('note', chinese: _chinese).isNotEmpty)
                  _note(item.localized('note', chinese: _chinese)),
              ],
      );
    }
    final chinese = _chinese;
    final relatedCard = ToolRecord(item.object('card'));
    final ranges = item.records('binRanges');
    final bins = ranges
        .map((range) => range.value('bin'))
        .where((value) => RegExp(r'^\d{6,8}$').hasMatch(value))
        .take(2)
        .toList();
    final subtitle = kind == ToolKind.bin
        ? ranges.isEmpty
              ? context.tr('暂无已公开的 BIN 资料')
              : [
                  ranges.first.value('network'),
                  ranges.first.value('region'),
                ].where((value) => value.isNotEmpty).join(' · ')
        : kind == ToolKind.requirements && _payment
        ? relatedCard.localized('feeSummary', chinese: chinese)
        : item.summary(kind, chinese: chinese);
    final facts = switch (kind) {
      ToolKind.bin => [if (bins.isNotEmpty) 'BIN ${bins.join(' / ')}'],
      ToolKind.noKyc => [
        ...item.strings(chinese ? 'tagsZh' : 'tagsEn'),
        item.localized('feeSummary', chinese: chinese),
        _status(item.value('status')),
      ].where((value) => value.isNotEmpty).toList(),
      ToolKind.internationalSim => [
        '${item.value('countryFlag')} ${item.localized('countryName', chinese: chinese)} ${item.value('callingCode')}',
      ],
      ToolKind.addressProof => [
        if (item.value('price').isNotEmpty) item.value('price'),
      ],
      ToolKind.sms => [_status(item.value('siteStatus'))],
      _ => <String>[],
    };
    return ToolResultRow(
      key: Key('tool-record-${item.id}'),
      title: item.title(kind, chinese: chinese),
      subtitle: cleanToolText(subtitle),
      facts: facts,
      leading: (width) => _recordArtwork(kind, item, width),
      onTap: () => _openItem(item),
    );
  }

  Widget _recordArtwork(ToolKind kind, ToolRecord item, double width) {
    if ({ToolKind.bin, ToolKind.requirements, ToolKind.noKyc}.contains(kind)) {
      return ToolCardArt(card: _cardForRecord(kind, item), width: width);
    }
    final image = kind == ToolKind.internationalSim
        ? item.value('logoUrl')
        : kind == ToolKind.addressProof
        ? item.value('coverImageUrl')
        : '';
    return Container(
      width: width,
      height: width / 1.6,
      decoration: BoxDecoration(
        color: _toolColor(kind).withValues(alpha: .07),
        borderRadius: BorderRadius.circular(9),
      ),
      child: image.isEmpty
          ? Icon(_iconFor(kind), color: _toolColor(kind), size: 26)
          : Padding(
              padding: const EdgeInsets.all(8),
              child: _image(image, height: width / 1.6 - 16),
            ),
    );
  }

  CardSummary _cardForRecord(ToolKind kind, ToolRecord item) {
    final card = kind == ToolKind.requirements
        ? ToolRecord(item.object('card'))
        : item;
    final id = kind == ToolKind.bin
        ? item.id
        : item.value('cardId').isNotEmpty
        ? item.value('cardId')
        : card.id;
    final matches = widget.cards.where((value) => value.id == id);
    final known = matches.isEmpty ? null : matches.first;
    final rawImage = card.value('cardImageSrc');
    final image = publicToolUri(
      rawImage,
      base: widget.repository.apiClient.resolve('/'),
    )?.toString();
    return CardSummary(
      id: id,
      name: item.title(kind, chinese: _chinese),
      issuer: known?.issuer ?? card.value('issuer'),
      category: known?.category ?? CardCategory.uCard,
      label: known?.label ?? card.value('network'),
      tint: known?.tint ?? 0xFF6677AD,
      assetPath: known?.assetPath,
      imageUrl: known?.imageUrl ?? image,
    );
  }

  Widget _collectionCaption(
    ToolKind kind,
    ToolCollection collection,
    int count,
  ) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 5,
      children: [
        Text(
          '${context.tr(kind == ToolKind.bin || kind == ToolKind.requirements || kind == ToolKind.noKyc ? '卡片' : '已收录')} · $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        if (collection.updatedAt.isNotEmpty)
          Text(
            '${context.tr('资料更新')} ${_date(collection.updatedAt)}',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
      ],
    ),
  );
  Widget _detailView() => FutureBuilder<ToolRecord>(
    future: _detail,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _failure(() async {
          setState(() {
            _detail = _observe(widget.repository.detail(_kind!, _selected!));
          });
        });
      }
      if (!snapshot.hasData) return _loading();
      final item = snapshot.data!;
      final kind = _kind!;
      return ListView(
        key: ValueKey('tool-detail-${item.id}'),
        padding: _listPadding,
        children: [
          _detailHero(kind, item),
          ...switch (kind) {
            ToolKind.bin => _cardBinDetails(item),
            ToolKind.requirements => _requirementDetails(item),
            ToolKind.noKyc => [
              _section('卡片资料', [
                _field('核验状态', _status(item.value('status'))),
                _field('费用', item.localized('feeSummary', chinese: _chinese)),
                _field('KYC', item.value('localKycSummary')),
                _field(
                  '标签',
                  item.strings(_chinese ? 'tagsZh' : 'tagsEn').join(' · '),
                ),
              ]),
              ToolNotice('免 KYC 条件可能变化，费用与申请要求以发行方最新规则为准。'),
            ],
            ToolKind.addressProof => _addressDetails(item),
            ToolKind.internationalSim => _simDetails(item),
            ToolKind.sms => _smsDetails(item),
          },
          if (item.value('verificationStatus').isNotEmpty)
            _field('核验状态', _status(item.value('verificationStatus'))),
          if (item.value('checkedAt').isNotEmpty)
            _field('资料核对', _date(item.value('checkedAt'))),
          if (item.value('updatedAt').isNotEmpty)
            _field('资料更新', _date(item.value('updatedAt'))),
          if (item.value('sourceName').isNotEmpty ||
              item.value('sourceUrl').isNotEmpty)
            _source(
              item.value('sourceName').isEmpty
                  ? '资料来源'
                  : item.value('sourceName'),
              item.value('sourceUrl'),
            ),
          for (final source in item.records('sources'))
            _source(source.value('name'), source.value('url')),
          for (final key in ['officialUrl', 'applicationUrl', 'websiteUrl'])
            if (item.value(key).isNotEmpty) _source('官方网站', item.value(key)),
        ],
      );
    },
  );

  Widget _detailHero(ToolKind kind, ToolRecord item) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ToolSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _recordArtwork(
              kind,
              item,
              MediaQuery.textScalerOf(context).scale(14) > 20 ? 64 : 100,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title(kind, chinese: _chinese),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      height: 1.35,
                    ),
                  ),
                  if (item.summary(kind, chinese: _chinese).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      cleanToolText(item.summary(kind, chinese: _chinese)),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _cardBinDetails(ToolRecord item) => [
    if (item.records('binRanges').isEmpty) _note('暂无已公开的 BIN 资料'),
    for (final range in item.records('binRanges'))
      _section(range.value('label'), [
        _field('BIN', range.value('bin')),
        _field('支付网络', range.value('network')),
        _field('卡片类型', range.value('type')),
        _field('发卡机构', range.value('issuer')),
        _field('发卡地区', range.value('region')),
        _field('核验状态', _status(range.value('status'))),
        _field('资料核对', _date(range.value('checkedAt'))),
        _source(range.value('source'), range.value('sourceUrl')),
      ]),
  ];

  List<Widget> _requirementDetails(ToolRecord item) {
    final card = ToolRecord(item.object('card'));
    final payments = ToolRecord(card.object('paymentSupport'));
    return [
      _section('开卡条件', [
        for (final fact in _requirements)
          _field(
            fact.$2,
            _status(
              item.object('requirements')[fact.$1]?.toString() ?? 'unknown',
            ),
          ),
      ]),
      _section('费用', [
        _field('费用概览', card.localized('feeSummary', chinese: _chinese)),
        for (final fee in card.records('fees'))
          _field(fee.value('label'), fee.value('value')),
      ]),
      _section('支付支持', [
        for (final channel in _channels) ...[
          _field(
            channel.$2,
            _status(
              payments.object(channel.$1)['status']?.toString() ?? 'unknown',
            ),
          ),
          if (ToolRecord(
            payments.object(channel.$1),
          ).localized('note', chinese: _chinese).isNotEmpty)
            _note(
              ToolRecord(
                payments.object(channel.$1),
              ).localized('note', chinese: _chinese),
            ),
          if (payments.object(channel.$1)['sourceUrl']?.toString().isNotEmpty ==
              true)
            _source(
              channel.$2,
              payments.object(channel.$1)['sourceUrl'].toString(),
            ),
        ],
      ]),
      if (item.localized('note', chinese: _chinese).isNotEmpty)
        _note(item.localized('note', chinese: _chinese)),
    ];
  }

  List<Widget> _addressDetails(ToolRecord item) => [
    _section('适用范围', [
      _field('费用', item.value('price')),
      _field('免费', switch (item.value('freeAvailability')) {
        'yes' => '免费',
        'no' => '收费',
        'partial' => '部分免费',
        _ => '待核验',
      }),
      _field('支付方式', item.strings('paymentMethods').join(' · ')),
      _field(
        '国家/地区',
        item.strings('regions').isEmpty
            ? item.value('regionCount')
            : item.strings('regions').join(' · '),
      ),
      _field('手持证明', _status(item.value('handheldAvailability'))),
    ]),
    if (item.value('bodyHtml').isNotEmpty ||
        item.value('rawContent').isNotEmpty)
      _section('使用指南', [
        MarkdownBody(
          data: toolHtmlToMarkdown(
            item.value('bodyHtml').isNotEmpty
                ? item.value('bodyHtml')
                : item.value('rawContent'),
          ),
          selectable: true,
          onTapLink: (_, href, _) {
            if (href != null) _openUrl(href);
          },
          sizedImageBuilder: (config) =>
              publicToolUri(
                    config.uri.toString(),
                    base: widget.repository.apiClient.resolve('/'),
                  ) ==
                  null
              ? const SizedBox.shrink()
              : _image(config.uri.toString(), height: 220),
        ),
      ]),
  ];

  List<Widget> _simDetails(ToolRecord item) => [
    _section('申请与激活', [
      _field(
        '国家/地区',
        '${item.localized('countryName', chinese: _chinese)} ${item.value('callingCode')}',
      ),
      _field(
        'SIM 类型',
        item
            .strings('formFactors')
            .map((value) => value == 'physical' ? '实体 SIM' : 'eSIM')
            .join(' · '),
      ),
      _field('中国用户申请', item.localized('chinaApplication', chinese: _chinese)),
      _field('申请材料', item.localized('documents', chinese: _chinese)),
      for (final fact in [
        ('activationInChina', '中国境内首次激活'),
        ('requiresLocalPresence', '需要前往当地'),
        ('hasPhoneNumber', '附带手机号'),
        ('supportsCalls', '通话'),
        ('supportsSms', '普通短信'),
        ('supportsWifiCalling', 'Wi-Fi Calling'),
        ('mainlandRoaming', '中国大陆漫游'),
      ])
        _field(
          fact.$2,
          fact.$1 == 'requiresLocalPresence'
              ? switch (item.value(fact.$1)) {
                  'yes' => '需要',
                  'no' => '不需要',
                  'conditional' => '有条件',
                  _ => '待核验',
                }
              : _status(item.value(fact.$1)),
        ),
    ]),
    _section('费用与保号', [
      for (final fact in [
        ('openingCost', '开通费用'),
        ('monthlyCost', '月度费用'),
        ('retentionCost', '保号费用'),
        ('price', '资费说明'),
        ('keepNumber', '保号条件'),
      ])
        _field(fact.$2, item.localized(fact.$1, chinese: _chinese)),
    ]),
    if (item.localized('note', chinese: _chinese).isNotEmpty)
      _note(item.localized('note', chinese: _chinese)),
    for (final guide in item.records('guides'))
      _section(guide.localized('title', chinese: _chinese), [
        _field('资料性质', switch (guide.value('evidence')) {
          'official' => '官方资料',
          'mixed' => '官方资料与用户经验',
          'experience' => '用户经验',
          _ => '待核验',
        }),
        _note(guide.localized('summary', chinese: _chinese)),
        for (final step in guide.records('steps'))
          _field(
            step.localized('title', chinese: _chinese),
            cleanToolText(step.localized('body', chinese: _chinese)),
          ),
        if (guide.localized('warning', chinese: _chinese).isNotEmpty)
          _note(guide.localized('warning', chinese: _chinese)),
        for (final url in guide.strings('sourceUrls')) _source('资料来源', url),
      ]),
    for (final application in item.records('verifiedCardApplications'))
      _section(application.value('cardName'), [
        _field('资料核对', _date(application.value('verifiedAt'))),
        _note(application.localized('note', chinese: _chinese)),
        _source('资料来源', application.value('sourceUrl')),
      ]),
  ];

  List<Widget> _smsDetails(ToolRecord item) => [
    ToolNotice('公开收件箱的短信可被他人查看，请勿用于银行等敏感账号。'),
    _section('平台资料', [
      _field('网站状态', _status(item.value('siteStatus'))),
      _field('收件箱隐私', _status(item.value('privacy'))),
      _field('API 接入', _status(item.value('api'))),
      for (final fact in [
        ('coverage', '覆盖范围'),
        ('price', '费用'),
        ('duration', '有效时长'),
        ('refund', '退款规则'),
        ('requirements', '使用条件'),
        ('reviewNote', '核验说明'),
        ('note', '注意事项'),
      ])
        _field(fact.$2, item.localized(fact.$1, chinese: _chinese)),
    ]),
  ];

  // A fast failure may arrive before the next frame attaches FutureBuilder.
  // Observe it immediately while retaining the original error for the UI.
  Future<T> _observe<T>(Future<T> future) {
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return future;
  }

  Widget _panel({required Widget child}) => ToolSurface(child: child);

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    ),
  );
  Widget _field(String label, String value) =>
      ToolFact(label: label, value: cleanToolText(value));
  Widget _note(String text) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
        );
  Widget _source(String name, String url) {
    final uri = publicToolUri(url);
    if (uri == null) return _field('资料来源', name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          foregroundColor: AppColors.cyan,
          backgroundColor: AppColors.glass,
          side: BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: () => _openUrl(uri.toString()),
        icon: const Icon(Icons.open_in_new_rounded, size: 17),
        label: Text(
          '${context.tr(name.isEmpty ? '资料来源' : name)} · ${uri.host}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _image(String url, {double? width, required double height}) {
    final uri = publicToolUri(
      url,
      base: widget.repository.apiClient.resolve('/'),
    );
    if (uri == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: uri.toString(),
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(
          width: width,
          height: height,
          child: Icon(Icons.image_outlined, color: AppColors.textMuted),
        ),
        errorWidget: (_, _, _) => SizedBox(
          width: width,
          height: height,
          child: Icon(Icons.image_outlined, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _toolIcon(ToolKind kind) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: _toolColor(kind).withValues(alpha: .13),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(_iconFor(kind), color: _toolColor(kind), size: 23),
  );
  IconData _iconFor(ToolKind kind) => switch (kind) {
    ToolKind.bin => Icons.credit_card_rounded,
    ToolKind.requirements => Icons.compare_arrows_rounded,
    ToolKind.noKyc => Icons.shield_outlined,
    ToolKind.addressProof => Icons.description_outlined,
    ToolKind.internationalSim => Icons.sim_card_outlined,
    ToolKind.sms => Icons.sms_outlined,
  };
  Color _toolColor(ToolKind kind) => switch (kind) {
    ToolKind.bin => const Color(0xFF8B68FF),
    ToolKind.requirements => const Color(0xFF5C73FF),
    ToolKind.noKyc => const Color(0xFF328776),
    ToolKind.addressProof => const Color(0xFFAF7A3F),
    ToolKind.internationalSim => const Color(0xFF5367B8),
    ToolKind.sms => const Color(0xFF36898F),
  };
  Widget _loading() => const Center(child: CircularProgressIndicator());
  Widget _failure(Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 36),
          const SizedBox(height: 12),
          const Text('暂时无法加载资料'),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('重试')),
        ],
      ),
    ),
  );
  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, size: 36),
        const SizedBox(height: 12),
        const Text('没有找到匹配的资料'),
        if (_query.text.isNotEmpty || _filter.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              _query.clear();
              _filter = '';
            }),
            child: const Text('清除筛选'),
          ),
      ],
    ),
  );
  String _date(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
  String _status(String value) => switch (value) {
    'required' => '需要',
    'notRequired' => '不需要',
    'yes' || 'supported' => '支持',
    'no' || 'unsupported' => '不支持',
    'conditional' => '有条件',
    'partial' => '部分免费',
    'optional' => '可选',
    'verified' || 'official' => '已核验',
    'conflict' => '资料有冲突',
    'private' => '账户内收码',
    'public' => '短信公开可见',
    'mixed' => '免费与付费并存',
    'listed' => '已收录',
    'unreachable' => '暂无法访问',
    'redirected' => '已跳转',
    'repurposed' => '用途已变更',
    'expired' => '已失效',
    'experience' => '用户经验',
    _ => '待核验',
  };
}

/// A small, native Markdown conversion for the H5 guide content. Scripts,
/// embedded frames and executable URL schemes never enter the rendered tree.
String toolHtmlToMarkdown(String html) {
  var result = html.replaceAll(
    RegExp(
      r'<(script|style|iframe)\b[^>]*>[\s\S]*?</\1>',
      caseSensitive: false,
    ),
    '',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'<a\b[^>]*href=["\x27]([^"\x27]*)["\x27][^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ),
    (match) {
      final uri = publicToolUri(match[1]!);
      final label = match[2]!.replaceAll(RegExp(r'<[^>]+>'), '');
      return uri == null ? label : '[${cleanToolText(label)}]($uri)';
    },
  );
  result = result.replaceAllMapped(
    RegExp(
      r'<img\b[^>]*src=["\x27]([^"\x27]*)["\x27][^>]*>',
      caseSensitive: false,
    ),
    (match) => '![](${match[1]})',
  );
  result = result
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|ul|ol|blockquote)>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n- ');
  result = result
      .replaceAll(RegExp(r'</?(strong|b)\b[^>]*>', caseSensitive: false), '**')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  for (final entry in const {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
  }.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return cleanToolText(result).trim();
}
