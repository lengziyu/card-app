import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:cardfi/features/tools/data/h5_sms_logo_paths.dart';
import 'package:cardfi/features/tools/widgets/tool_components.dart';
import 'package:cardfi/features/shell/widgets/animated_glass_segment.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_svg/flutter_svg.dart';

const toolRequirementFields = [
  ('inviteCode', '邀请码'),
  ('idCard', '身份证'),
  ('passport', '护照'),
  ('overseasAddressProof', '海外地址证明'),
  ('overseasPhone', '海外手机号'),
];
const toolPaymentFields = [
  ('wechatPay', '微信支付'),
  ('alipay', '支付宝'),
  ('applePay', 'Apple Pay'),
  ('googlePay', 'Google Pay'),
  ('chatgpt', 'ChatGPT'),
  ('claude', 'Claude'),
];

class ToolComparisonCard extends StatelessWidget {
  const ToolComparisonCard({
    required this.item,
    required this.artwork,
    required this.payment,
    required this.expanded,
    required this.onToggle,
    required this.details,
    super.key,
  });
  final ToolRecord item;
  final Widget artwork;
  final bool payment;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final card = ToolRecord(item.object('card'));
    final fields = toolPaymentFields;
    final payments = ToolRecord(card.object('paymentSupport'));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xFF263545) : const Color(0xFFE4E8ED);
    return Material(
      color: dark ? const Color(0xFF121F2D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: Key('tool-expand-${item.id}'),
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        MediaQuery.textScalerOf(context).scale(15) > 22 ||
                        constraints.maxWidth < 240;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title(ToolKind.requirements, chinese: chinese),
                          maxLines: stacked ? null : 1,
                          overflow: stacked ? null : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cleanToolText(
                            payment
                                ? card.localized('feeSummary', chinese: chinese)
                                : item.summary(
                                    ToolKind.requirements,
                                    chinese: chinese,
                                  ),
                          ),
                          maxLines: stacked ? null : 1,
                          overflow: stacked ? null : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                    final chevron = Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    );
                    return stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [artwork, const Spacer(), chevron]),
                              const SizedBox(height: 12),
                              copy,
                            ],
                          )
                        : Row(
                            children: [
                              artwork,
                              const SizedBox(width: 10),
                              Expanded(child: copy),
                              chevron,
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
          if (payment)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, color: AppColors.line),
            ),
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: payment
                  ? const EdgeInsets.fromLTRB(10, 14, 10, 15)
                  : EdgeInsets.zero,
              child: !payment
                  ? _RequirementGrid(item: item)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final scale = MediaQuery.textScalerOf(
                          context,
                        ).scale(11);
                        final columns = scale > 18
                            ? 2
                            : scale > 14 || constraints.maxWidth < 300
                            ? 3
                            : fields.length;
                        return Wrap(
                          spacing: 4,
                          runSpacing: 12,
                          children: [
                            for (final field in fields)
                              SizedBox(
                                width:
                                    (constraints.maxWidth - 4 * (columns - 1)) /
                                    columns,
                                child: _StateCell(
                                  label: field.$2,
                                  channel: field.$1,
                                  status:
                                      payments
                                          .object(field.$1)['status']
                                          ?.toString() ??
                                      'unknown',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          if (expanded)
            Padding(
              key: Key('tool-expanded-${item.id}'),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 10),
                  ...details,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RequirementGrid extends StatelessWidget {
  const _RequirementGrid({required this.item});
  final ToolRecord item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final line = dark ? const Color(0xFF263545) : const Color(0xFFEDF0F3);
    final scaler = MediaQuery.textScalerOf(context);
    final requirements = item.object('requirements');
    return Ink(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101B27) : const Color(0xFFFAFBFC),
        border: Border(top: BorderSide(color: line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 7, 5, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Preserve the H5 five-column comparison at every text size. Large
            // text and longer translations scroll without shrinking the type.
            final minCellWidth = scaler.scale(chinese ? 50 : 86);
            final width = math.max(constraints.maxWidth, minCellWidth * 5 + 4);
            final row = SizedBox(
              width: width,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < toolRequirementFields.length; i++) ...[
                      if (i > 0)
                        VerticalDivider(width: 1, thickness: 1, color: line),
                      Expanded(
                        child: Semantics(
                          label:
                              '${context.tr(toolRequirementFields[i].$2)}：${context.tr(_requirementCaption(requirements[toolRequirementFields[i].$1]?.toString() ?? 'unknown'))}',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: scaler.scale(18),
                                  ),
                                  child: Text(
                                    toolRequirementFields[i].$1 ==
                                            'overseasAddressProof'
                                        ? '海外证明'
                                        : toolRequirementFields[i].$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? const Color(0xFF8E99A7)
                                          : const Color(0xFF777F8B),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(height: 4),
                                _RequirementSymbol(
                                  status:
                                      requirements[toolRequirementFields[i].$1]
                                          ?.toString() ??
                                      'unknown',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
            return width > constraints.maxWidth
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: row,
                  )
                : row;
          },
        ),
      ),
    );
  }
}

String _requirementCaption(String status) => switch (status) {
  'required' => '需要',
  'notRequired' => '不需要',
  'conditional' => '有条件',
  _ => '待确认',
};

class _RequirementSymbol extends StatelessWidget {
  const _RequirementSymbol({required this.status, this.size = 22});
  final String status;
  final double size;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final required = status == 'required', absent = status == 'notRequired';
    final green = dark ? const Color(0xFF12D978) : const Color(0xFF10C86F);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: required
            ? green
            : absent
            ? Colors.transparent
            : const Color(0xFFFFC247),
        border: absent
            ? Border.all(
                color: dark ? const Color(0xFF536170) : const Color(0xFFAEB7C1),
              )
            : null,
        boxShadow: required
            ? [
                BoxShadow(color: green.withValues(alpha: .16), spreadRadius: 2),
                BoxShadow(color: green.withValues(alpha: .28), blurRadius: 10),
              ]
            : null,
      ),
      child: required || absent
          ? Icon(
              required ? Icons.check_rounded : Icons.remove_rounded,
              size: size * .72,
              color: required ? Colors.white : const Color(0xFF8995A2),
            )
          : Text(
              status == 'conditional' ? '!' : '?',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: size * .6,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6F4A00),
              ),
            ),
    );
  }
}

class ToolRequirementFilters extends StatelessWidget {
  const ToolRequirementFilters({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const filters = [('', '全部'), ('idCard', '身份证'), ('passport', '护照')];
      const statuses = ['required', 'notRequired', 'unknown'];
      final scaler = MediaQuery.textScalerOf(context);
      double textWidth(String value, double fontSize) {
        final painter = TextPainter(
          text: TextSpan(
            text: context.tr(value),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final filterWidth =
          filters
                  .map(
                    (field) => math.max(48.0, textWidth(field.$2, 10.5) + 20),
                  )
                  .reduce(math.max) *
              3 +
          12;
      final legendWidth =
          statuses.fold<double>(
            0,
            (width, status) =>
                width + 18 + 3 + textWidth(_requirementCaption(status), 10),
          ) +
          12;
      final chips = SizedBox(
        width: math.min(filterWidth, constraints.maxWidth),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: filterWidth,
            child: AnimatedPillSegment<String>(
              height: math.max(28, scaler.scale(10.5) * 1.4 + 8),
              gap: 6,
              fontSize: 10.5,
              items: [
                for (final field in filters)
                  GlassSegmentItem(
                    value: field.$1,
                    label: field.$2,
                    key: Key('tools-filter-${field.$1}'),
                  ),
              ],
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      );
      final legend = Wrap(
        spacing: 6,
        runSpacing: 8,
        children: [
          for (final status in statuses)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RequirementSymbol(status: status, size: 18),
                const SizedBox(width: 3),
                Text(
                  _requirementCaption(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
        ],
      );
      return filterWidth + legendWidth + 10 <= constraints.maxWidth
          ? Row(children: [chips, const Spacer(), legend])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [chips, const SizedBox(height: 4), legend],
            );
    },
  );
}

class _StateCell extends StatelessWidget {
  const _StateCell({required this.label, required this.status, this.channel});
  final String label;
  final String status;
  final String? channel;
  @override
  Widget build(BuildContext context) {
    final positive = {'required', 'supported'}.contains(status);
    final conditional = status == 'conditional';
    final absent = {'notRequired', 'unsupported'}.contains(status);
    final color = positive
        ? const Color(0xFF328776)
        : conditional
        ? const Color(0xFFAF7A3F)
        : AppColors.textMuted;
    final symbol = positive
        ? '✓'
        : conditional
        ? '!'
        : absent
        ? '—'
        : '?';
    final caption = switch (status) {
      'required' => '需要',
      'notRequired' => '不需要',
      'supported' => '支持',
      'unsupported' => '不支持',
      'conditional' => '有条件',
      _ => '待确认',
    };
    final icon = switch (channel) {
      'wechatPay' => 'wechat',
      'applePay' => 'applepay',
      'googlePay' => 'googlepay',
      _ => channel,
    };
    return Semantics(
      label: '${context.tr(label)}：${context.tr(caption)}',
      excludeSemantics: true,
      child: Column(
        children: [
          if (channel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: SvgPicture.asset(
                'assets/tools/payment-icons/$icon.svg',
                width: 25,
                height: 25,
              ),
            ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (channel != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ToolDirectoryGrid extends StatelessWidget {
  const ToolDirectoryGrid({
    required this.items,
    required this.builder,
    super.key,
  });
  final List<ToolRecord> items;
  final Widget Function(ToolRecord) builder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(12) > 16
          ? 1
          : 2;
      return Column(
        children: [
          for (var i = 0; i < items.length; i += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 12),
                    Expanded(
                      child: i + column < items.length
                          ? builder(items[i + column])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

class ToolDirectoryCard extends StatelessWidget {
  const ToolDirectoryCard({
    required this.kind,
    required this.item,
    required this.base,
    required this.onTap,
    super.key,
  });
  final ToolKind kind;
  final ToolRecord item;
  final Uri base;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return ToolSurface(
      radius: 12,
      child: InkWell(
        onTap: onTap,
        child: switch (kind) {
          ToolKind.internationalSim => _sim(context, chinese),
          ToolKind.sms => _sms(context, chinese),
          _ => _address(context),
        },
      ),
    );
  }

  TextStyle get _name => TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
  TextStyle get _small =>
      TextStyle(fontSize: 10, height: 1.55, color: AppColors.textMuted);

  Widget _picture(
    String path, {
    BoxFit fit = BoxFit.contain,
    double? width,
    double? height,
    Widget? fallback,
  }) {
    final uri = publicToolUri(path, base: base);
    final placeholder =
        fallback ??
        Icon(Icons.image_outlined, size: 25, color: AppColors.textMuted);
    return uri == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: uri.toString(),
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
  }

  Widget _sim(BuildContext context, bool chinese) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 5 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _picture(
              '/international-sim-flags/${Uri.encodeComponent(item.value('countryCode'))}.webp',
              fit: BoxFit.cover,
              fallback: Container(color: AppColors.cyan.withValues(alpha: .08)),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00172536), Color(0xD9172536)],
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 9,
              bottom: 9,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _picture(
                      item.value('logoUrl'),
                      fallback: Text(
                        item.value('provider').isEmpty
                            ? 'SIM'
                            : item
                                  .value('provider')
                                  .substring(
                                    0,
                                    item.value('provider').length < 2
                                        ? item.value('provider').length
                                        : 2,
                                  ),
                        style: _small,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title(kind, chinese: chinese),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _name.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${item.localized('countryName', chinese: chinese)} · ${item.value('callingCode')}',
                          maxLines: 1,
                          style: _small.copyWith(
                            color: const Color(0xFFE3EAF5),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              cleanToolText(item.summary(kind, chinese: chinese)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _small,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _badge(
                  item.strings('formFactors').firstOrNull == 'physical'
                      ? '实体 SIM'
                      : 'eSIM',
                ),
                _badge(
                  item.value('hasPhoneNumber') == 'yes'
                      ? '真实号码'
                      : item.value('requiresLocalPresence') == 'yes'
                      ? '当地激活'
                      : _serviceType(item.value('serviceType')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    switch (item.value('chinaApplicationStatus')) {
                      'available' => '中国用户可申请',
                      'conditional' => '中国用户有条件申请',
                      'unavailable' => '中国用户暂不可申请',
                      _ => '申请资格待核验',
                    },
                    style: _small.copyWith(
                      color: switch (item.value('chinaApplicationStatus')) {
                        'available' => const Color(0xFF328776),
                        'conditional' => const Color(0xFFAF7A3F),
                        'unavailable' => const Color(0xFFB95A65),
                        _ => AppColors.textMuted,
                      },
                      fontSize: 9,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  String _serviceType(String value) => switch (value) {
    'mvno' => '虚拟运营商',
    'carrier' => '运营商',
    'travel' || 'travel-esim' => '旅行 eSIM',
    'voip' => '网络号码',
    _ => '手机卡',
  };

  Widget _sms(BuildContext context, bool chinese) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _picture(
                h5SmsLogoPaths[item.id] ?? '',
                fallback: Icon(
                  Icons.sms_outlined,
                  color: AppColors.cyan,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value('name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _name,
                  ),
                  Text(
                    publicToolUri(
                          item.value('websiteUrl'),
                        )?.host.replaceFirst(RegExp(r'^www\.'), '') ??
                        '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _small.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          cleanToolText(item.summary(kind, chinese: chinese)),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _small,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final mode in item.strings('modes').take(3))
                    _badge(switch (mode) {
                      'activation' => '按次接码',
                      'rental' => '号码租用',
                      'public' => '公开免费',
                      'app' => '号码 App',
                      'messaging' => '短信通信',
                      'bot' => '机器人线索',
                      _ => '其他',
                    }),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _address(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (item.value('coverImageUrl').isNotEmpty)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _picture(item.value('coverImageUrl'), fit: BoxFit.cover),
        ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value('title'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _name,
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _badge(switch (item.value('freeAvailability')) {
                  'yes' => '免费',
                  'partial' => '部分免费',
                  'no' => '收费',
                  _ => '待确认',
                }),
                if (item.value('regionCount').isNotEmpty &&
                    item.value('regionCount') != '0')
                  _badge('${item.value('regionCount')} ${context.tr('个地区')}'),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.cyan.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, color: AppColors.textMuted, height: 1.35),
    ),
  );
}
