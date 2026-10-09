import 'dart:async';
import 'dart:math' as math;

import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/features/tools/data/tools_repository.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:cardfi/features/tools/widgets/tool_components.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// H5's card selector and all ranges on one page, implemented with native UI.
class BinLookupContent extends StatefulWidget {
  const BinLookupContent({
    required this.collection,
    required this.repository,
    required this.onRefresh,
    required this.artwork,
    required this.onOpenUrl,
    required this.tapGroup,
    super.key,
  });
  final Future<ToolCollection> collection;
  final ToolsRepository repository;
  final Future<void> Function() onRefresh;
  final Widget Function(ToolRecord, double) artwork;
  final Future<void> Function(String) onOpenUrl;
  final Object tapGroup;

  @override
  State<BinLookupContent> createState() => BinLookupContentState();
}

class BinLookupContentState extends State<BinLookupContent> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _input = TextEditingController();
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  Object get _tapGroup => widget.tapGroup;
  String? _selectedId;
  bool _byBin = false;
  bool _loading = false;
  ToolRecord? _result;
  String? _error;
  String? _copied;
  Timer? _copyTimer;
  int _request = 0;
  bool get _chinese => Localizations.localeOf(context).languageCode == 'zh';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _overlay.show();
    } else {
      _overlay.hide();
    }
  }

  bool dismissPicker() {
    if (!_overlay.isShowing) return false;
    _focus.unfocus();
    _overlay.hide();
    return true;
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _query.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: ToolModeSegment(
          items: const [('card', '按卡片查询'), ('bin', '按 BIN 查询')],
          selected: _byBin ? 'bin' : 'card',
          onChanged: (value) {
            dismissPicker();
            setState(() => _byBin = value == 'bin');
          },
        ),
      ),
      Expanded(
        child: _byBin
            ? _rawLookup()
            : FutureBuilder<ToolCollection>(
                future: widget.collection,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _failure(widget.onRefresh);
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!.items;
                  if (items.isEmpty) {
                    return const Center(child: Text('没有找到匹配的资料'));
                  }
                  final selected = items.firstWhere(
                    (item) => item.id == _selectedId,
                    orElse: () => items.firstWhere(
                      (item) => item.id == 'bybit',
                      orElse: () => items.first,
                    ),
                  );
                  final ranges = selected.records('binRanges');
                  return AppPullToRefresh(
                    onRefresh: widget.onRefresh,
                    child: ListView(
                      key: const Key('bin-card-list'),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        32 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _picker(items, selected),
                        const SizedBox(height: 16),
                        _selectedCard(selected, ranges.length),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Text('BIN 卡段', style: _title)),
                            Text('按地区与产品区分', style: _muted),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (ranges.isEmpty)
                          _surface([
                            const Icon(Icons.article_outlined),
                            const SizedBox(height: 10),
                            const Text('这张卡还没有已发布的 BIN'),
                            const SizedBox(height: 5),
                            Text('暂无已公开的 BIN 资料', style: _muted),
                          ])
                        else
                          for (var i = 0; i < ranges.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _range(ranges[i], '${selected.id}-$i'),
                            ),
                        const ToolNotice(
                          '同一张卡可能因申请地区、币种、实体或虚拟版本而使用不同 BIN。页面只展示有来源的资料；“待录入”不代表该卡没有 BIN。',
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );

  TextStyle get _title => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
  TextStyle get _muted =>
      TextStyle(fontSize: 11, height: 1.5, color: AppColors.textMuted);
  Widget _surface(List<Widget> children) => ToolSurface(
    radius: 10,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _picker(List<ToolRecord> items, ToolRecord selected) => _surface([
    Row(
      children: [
        Expanded(child: Text('选择一张卡', style: _title)),
        Text('站内卡库', style: _muted),
      ],
    ),
    const SizedBox(height: 5),
    Text('搜索卡片名称，查看它使用的全部 BIN 卡段', style: _muted),
    const SizedBox(height: 14),
    LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (context) {
          final keyword = _query.text.trim().toLowerCase();
          final matches = items
              .where(
                (item) =>
                    '${item.value('name')} ${item.value('issuer')} ${item.value('category')} ${item.value('meta')}'
                        .toLowerCase()
                        .contains(keyword),
              )
              .toList();
          return Positioned(
            width: constraints.maxWidth,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: TapRegion(
                groupId: _tapGroup,
                child: ToolSurface(
                  radius: 10,
                  color: AppColors.surface,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(
                        300,
                        math.max(
                          120,
                          MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom -
                              310,
                        ),
                      ),
                    ),
                    child: matches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text('没有找到匹配的资料', style: _muted),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(4),
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final item = matches[index];
                              return Semantics(
                                selected: item.id == selected.id,
                                child: InkWell(
                                  key: Key('bin-option-${item.id}'),
                                  onTap: () {
                                    setState(() {
                                      _selectedId = item.id;
                                      _query.clear();
                                    });
                                    dismissPicker();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        widget.artwork(item, 52),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.value('name'),
                                                style: _title.copyWith(
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                              ),
                                              Text(
                                                '${item.value('issuer')} · ${item.records('binRanges').length} ${context.tr('个卡段')}',
                                                style: _muted,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          item.id == selected.id
                                              ? Icons.check_rounded
                                              : Icons.chevron_right_rounded,
                                          size: 17,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          );
        },
        child: CompositedTransformTarget(
          link: _link,
          child: TextField(
            key: const Key('tools-search'),
            groupId: _tapGroup,
            controller: _query,
            focusNode: _focus,
            onTap: () => _overlay.show(),
            onChanged: (_) {
              _overlay.show();
              setState(() {});
            },
            onTapOutside: (_) => dismissPicker(),
            style: TextStyle(fontSize: 13, color: AppColors.text),
            decoration: _inputDecoration('搜索 Bybit、RedotPay、KAST…').copyWith(
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              suffixIcon: _query.text.isEmpty
                  ? Icon(Icons.expand_more_rounded, color: AppColors.textMuted)
                  : IconButton(
                      tooltip: context.tr('清除'),
                      onPressed: () {
                        setState(_query.clear);
                        _overlay.show();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
      ),
    ),
  ]);

  Widget _selectedCard(ToolRecord item, int count) => Container(
    key: const Key('bin-selected-card'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF172536),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF35465A)),
    ),
    child: Row(
      children: [
        widget.artwork(item, 78),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前卡片',
                style: _muted.copyWith(
                  color: const Color(0xFF9FB3CB),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.value('name'),
                style: _title.copyWith(color: Colors.white),
                maxLines: 3,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.value('issuer')} · $count ${context.tr('个已整理卡段')}',
                style: _muted.copyWith(color: const Color(0xFFB6C7DC)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _range(ToolRecord range, String key) => _surface([
    _binHeading(
      range.value('network'),
      range.value('label'),
      range.value('bin'),
      key,
    ),
    const SizedBox(height: 13),
    Divider(height: 1, color: AppColors.line),
    const SizedBox(height: 12),
    ToolFactGrid(
      facts: [
        ('支付网络', range.value('network')),
        ('卡片类型', range.value('type')),
        ('发卡地区', range.value('region')),
        ('发卡机构', range.value('issuer')),
      ],
    ),
    const SizedBox(height: 13),
    Divider(height: 1, color: AppColors.line),
    const SizedBox(height: 10),
    _source(range.value('source'), range.value('sourceUrl')),
    if (range.value('status').isNotEmpty || range.value('checkedAt').isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Text(
          [
            if (range.value('status').isNotEmpty)
              context.tr(range.value('status') == 'verified' ? '已核验' : '待核验'),
            if (range.value('checkedAt').isNotEmpty)
              '${context.tr('资料核对')} ${range.value('checkedAt')}',
          ].join(' · '),
          style: _muted.copyWith(fontSize: 10),
        ),
      ),
  ]);

  Widget _binHeading(String network, String label, String bin, String key) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _networkIcon(network),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(label, style: _muted.copyWith(fontSize: 10)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'BIN $bin',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (RegExp(r'^\d{6,8}$').hasMatch(bin))
                      OutlinedButton.icon(
                        key: Key('copy-bin-$key'),
                        onPressed: () => _copy(bin, key),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.textMuted,
                          side: BorderSide(color: AppColors.line),
                        ),
                        icon: Icon(
                          _copied == key
                              ? Icons.check_rounded
                              : Icons.copy_outlined,
                          size: 13,
                        ),
                        label: Text(
                          _copied == key ? '已复制' : '复制',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Future<void> _copy(String bin, String key) async {
    await Clipboard.setData(ClipboardData(text: bin));
    if (!mounted) return;
    _copyTimer?.cancel();
    setState(() => _copied = key);
    _copyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  Widget _networkIcon(String network) => Semantics(
    label: network,
    image: true,
    child: SizedBox(
      width: 46,
      height: 35,
      child: network.toLowerCase().contains('visa')
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SvgPicture.asset(
                'assets/tools/payment-icons/visa-network.svg',
              ),
            )
          : network.toLowerCase().contains('mastercard')
          ? Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 3,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEB001B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 3,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xEBF79E1B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                network.isEmpty ? 'BIN' : network,
                textAlign: TextAlign.center,
                style: _muted.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    ),
  );

  Widget _source(String name, String url) => InkWell(
    onTap: publicToolUri(url) == null ? null : () => widget.onOpenUrl(url),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.article_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              cleanToolText(name.isEmpty ? url : name),
              style: _muted.copyWith(
                color: publicToolUri(url) == null
                    ? AppColors.textMuted
                    : AppColors.cyan,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: context.tr(hint),
    hintStyle: _muted.copyWith(fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    filled: true,
    fillColor: AppColors.glassStrong,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.cyan),
    ),
  );

  Widget _rawLookup() => ListView(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      32 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      _surface([
        Text('按 BIN 查询', style: _title),
        const SizedBox(height: 5),
        Text('输入卡号前 6–8 位，查看卡段属性', style: _muted),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('bin-input'),
                controller: _input,
                keyboardType: TextInputType.number,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: _inputDecoration('卡号前 6–8 位'),
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: AppColors.text,
                ),
                onSubmitted: (_) => _lookup(),
                onChanged: (_) => setState(() {
                  _result = null;
                  _error = null;
                  _loading = false;
                  _request++;
                }),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _input.text.length >= 6 && !_loading ? _lookup : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cyan,
                minimumSize: const Size(68, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _loading ? '查询中…' : '反查',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '只处理前 6–8 位，不接收完整卡号',
                style: _muted.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: _failure(() async => _lookup()),
          ),
        if (_result != null) ..._rawResult(_result!),
      ]),
      const SizedBox(height: 14),
      const ToolNotice('BIN 只能识别卡段属性，不能查询持卡人、余额或有效期，也不代表支付一定成功。'),
    ],
  );

  List<Widget> _rawResult(ToolRecord item) {
    final issuer = ToolRecord(item.object('issuer'));
    final country = ToolRecord(item.object('country'));
    final source = ToolRecord(item.object('source'));
    String localized(ToolRecord record, String key) =>
        _chinese && record.value('${key}Zh').isNotEmpty
        ? record.value('${key}Zh')
        : record.value(key);
    return [
      const SizedBox(height: 20),
      Divider(height: 1, color: AppColors.line),
      const SizedBox(height: 16),
      _binHeading(
        item.value('network'),
        context.tr('查询结果'),
        item.value('bin'),
        'raw-${item.value('bin')}',
      ),
      const SizedBox(height: 16),
      ToolFactGrid(
        facts: [
          ('支付网络', item.value('network')),
          ('卡片类型', localized(item, 'type')),
          ('发卡机构', localized(issuer, 'name')),
          ('发卡地区', localized(country, 'name')),
          ('卡产品', localized(item, 'category')),
          ('匹配精度', '${item.value('bin').length} ${context.tr('位 BIN')}'),
        ],
      ),
      const SizedBox(height: 14),
      _source(source.value('provider'), source.value('url')),
      if (source.value('license').isNotEmpty)
        _source(source.value('license'), source.value('licenseUrl')),
      if (source.value('license').isNotEmpty)
        Text(
          '${context.tr('开源数据已筛选并转换格式')} · ${context.tr('导入于')} ${item.value('importedAt').split('T').first}',
          style: _muted,
        ),
      if (source.value('changes').isNotEmpty)
        Text(cleanToolText(source.value('changes')), style: _muted),
      if (item.value('fetchedAt').isNotEmpty)
        Text(
          '${context.tr('资料更新')} ${item.value('fetchedAt').split('T').first}',
          style: _muted,
        ),
      const SizedBox(height: 8),
      Text('第三方聚合数据，仅用于辅助核验；卡片归属仍需结合发卡方资料确认。', style: _muted),
    ];
  }

  Future<void> _lookup() async {
    if (_loading || !RegExp(r'^\d{6,8}$').hasMatch(_input.text)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final version = ++_request;
    final prefix = _input.text;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.repository.lookupBin(prefix);
      if (mounted && version == _request) setState(() => _result = result);
    } catch (_) {
      if (mounted && version == _request) setState(() => _error = '暂时无法加载资料');
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  Widget _failure(Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('暂时无法加载资料'),
          TextButton(onPressed: retry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
