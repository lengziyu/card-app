import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/tools/domain/tool_record.dart';
import 'package:flutter/services.dart';

class ToolsRepository {
  ToolsRepository(this.apiClient);
  final ApiClient apiClient;

  Future<Map<ToolKind, ToolAvailability>> loadAvailability() async {
    final results = await Future.wait(
      ToolKind.values.where((kind) => kind.hasAvailability).map((kind) async {
        try {
          final json = jsonObject(await apiClient.get('${kind.path}/meta'));
          final count = (json['count'] as num?)?.toInt() ?? 0;
          return MapEntry(
            kind,
            ToolAvailability(
              enabled: json['enabled'] == true && count > 0,
              count: count,
            ),
          );
        } catch (_) {
          return MapEntry(
            kind,
            const ToolAvailability(enabled: false, failed: true),
          );
        }
      }),
    );
    return Map.fromEntries(results);
  }

  Future<ToolCollection> load(ToolKind kind) async {
    final json = jsonObject(
      await apiClient.get(
        kind.path,
        headers: kind == ToolKind.requirements
            ? const {'cache-control': 'no-cache'}
            : null,
      ),
    );
    var items = jsonList(json['items'])
        .map((item) => ToolRecord(jsonObject(item)))
        .where((item) => !{'draft', 'archived'}.contains(item.value('status')))
        .toList();
    if (kind == ToolKind.noKyc && json['enabled'] != true) items = [];
    if (kind == ToolKind.bin) {
      final defaults = jsonObject(
        jsonDecode(
          await rootBundle.loadString('assets/tools/h5-card-bin-ranges.json'),
        ),
      );
      items = items.map((item) {
        // An explicitly configured empty range overrides the H5 fallback too.
        return ToolRecord({
          ...item.data,
          'binRanges': item.data['binRanges'] is List
              ? item.data['binRanges']
              : defaults[item.id] ?? const [],
        });
      }).toList();
      // Keep the source order for the H5-style selector; ranges are displayed
      // for the selected card, rather than used to rank the card directory.
    }
    return ToolCollection(
      items: List.unmodifiable(items),
      updatedAt: json['updatedAt']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      sourceAvailable: json['sourceAvailable'] != false,
    );
  }

  Future<ToolRecord> detail(ToolKind kind, ToolRecord item) async {
    if (!{
      ToolKind.addressProof,
      ToolKind.internationalSim,
      ToolKind.sms,
    }.contains(kind)) {
      return item;
    }
    final key = kind == ToolKind.addressProof ? item.value('slug') : item.id;
    final json = jsonObject(
      await apiClient.get('${kind.path}/${Uri.encodeComponent(key)}'),
    );
    final record = ToolRecord(jsonObject(json['item']));
    if ({'draft', 'archived'}.contains(record.value('status'))) {
      throw const FormatException('Unpublished tool record');
    }
    return record;
  }

  Future<ToolRecord> lookupBin(String bin) async {
    if (!RegExp(r'^\d{6,8}$').hasMatch(bin)) {
      throw const FormatException('BIN must contain 6–8 digits');
    }
    final json = jsonObject(await apiClient.get('/api/bin-lookup/$bin'));
    return ToolRecord(jsonObject(json['item']));
  }
}
