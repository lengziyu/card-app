import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/features/catalog/domain/card_detail.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/features/pro/data/pro_config.dart';
import 'package:cardfi/features/pro/data/pro_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProComparisonPreset {
  const ProComparisonPreset({
    required this.id,
    required this.cardIds,
    required this.cardNames,
    required this.updatedAt,
  });

  factory ProComparisonPreset.fromJson(Map<String, Object?> json) {
    return ProComparisonPreset(
      id: json['id']?.toString() ?? '',
      cardIds: _stringList(json['cardIds'], limit: 6),
      cardNames: _stringList(json['cardNames'], limit: 6),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final List<String> cardIds;
  final List<String> cardNames;
  final DateTime updatedAt;

  String get title => cardNames.isEmpty ? '卡片对比方案' : cardNames.join(' / ');

  Map<String, Object?> toJson() => {
    'id': id,
    'cardIds': cardIds,
    'cardNames': cardNames,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class ProWorkspaceSnapshot {
  const ProWorkspaceSnapshot({
    this.watchedCardIds = const {},
    this.comparisonPresets = const [],
    this.offlineDetails = const {},
    this.offlineUpdatedAt,
    this.updatedAt,
  });

  factory ProWorkspaceSnapshot.fromJson(Map<String, Object?> json) {
    final rawPresets = json['comparisonPresets'];
    final rawDetails = json['offlineDetails'];
    return ProWorkspaceSnapshot(
      watchedCardIds: _stringList(json['watchedCardIds'], limit: 240).toSet(),
      comparisonPresets: rawPresets is List
          ? rawPresets
                .whereType<Map>()
                .map(
                  (value) => ProComparisonPreset.fromJson(
                    value.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .where(
                  (preset) =>
                      preset.id.isNotEmpty && preset.cardIds.length >= 2,
                )
                .take(30)
                .toList(growable: false)
          : const [],
      offlineDetails: rawDetails is Map
          ? {
              for (final entry in rawDetails.entries)
                if (entry.key.toString().isNotEmpty && entry.value is Map)
                  entry.key.toString(): CardDetailSnapshot.fromJson(
                    (entry.value as Map).map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
            }
          : const {},
      offlineUpdatedAt: DateTime.tryParse(
        json['offlineUpdatedAt']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final Set<String> watchedCardIds;
  final List<ProComparisonPreset> comparisonPresets;
  final Map<String, CardDetailSnapshot> offlineDetails;
  final DateTime? offlineUpdatedAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson({bool includeOffline = true}) => {
    'version': 1,
    'watchedCardIds': watchedCardIds.toList(growable: false),
    'comparisonPresets': comparisonPresets
        .map((preset) => preset.toJson())
        .toList(growable: false),
    if (includeOffline)
      'offlineDetails': {
        for (final entry in offlineDetails.entries)
          entry.key: entry.value.toJson(),
      },
    if (offlineUpdatedAt != null)
      'offlineUpdatedAt': offlineUpdatedAt!.toUtc().toIso8601String(),
    'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

class CardDetailSnapshot {
  const CardDetailSnapshot({required this.detail});

  factory CardDetailSnapshot.fromJson(Map<String, Object?> json) {
    DetailFeatureIcon featureIcon(Object? value) =>
        DetailFeatureIcon.values.firstWhere(
          (icon) => icon.name == value,
          orElse: () => DetailFeatureIcon.wallet,
        );
    PaymentChannel? channel(Object? value) {
      final matches = PaymentChannel.values.where((item) => item.name == value);
      return matches.isEmpty ? null : matches.first;
    }

    final rawFeatures = json['features'];
    final rawFees = json['fees'];
    return CardDetailSnapshot(
      detail: CardDetail(
        cardId: json['cardId']?.toString() ?? '',
        tags: _stringList(json['tags'], limit: 30),
        region: json['region']?.toString() ?? '以官网为准',
        funding: json['funding']?.toString() ?? '以官网为准',
        availability: json['availability']?.toString() ?? '以官网为准',
        features: rawFeatures is List
            ? rawFeatures
                  .whereType<Map>()
                  .map((value) {
                    return DetailFeature(
                      icon: featureIcon(value['icon']),
                      text: value['text']?.toString() ?? '',
                    );
                  })
                  .toList(growable: false)
            : const [],
        fees: rawFees is List
            ? rawFees
                  .whereType<Map>()
                  .map((value) {
                    return FeeLine(
                      label: value['label']?.toString() ?? '',
                      value: value['value']?.toString() ?? '',
                    );
                  })
                  .toList(growable: false)
            : const [],
        kycNote: json['kycNote']?.toString() ?? '以官方申请流程为准。',
        paymentChannels: _stringList(
          json['paymentChannels'],
          limit: 20,
        ).map(channel).whereType<PaymentChannel>().toSet(),
        sourceLabel: json['sourceLabel']?.toString() ?? '离线资料',
        note: json['note']?.toString() ?? '',
        // 邀请入口受服务端公开开关控制，不能由离线缓存绕过。
        inviteCode: null,
        inviteUrl: null,
      ),
    );
  }

  final CardDetail detail;

  Map<String, Object?> toJson() => {
    'cardId': detail.cardId,
    'tags': detail.tags,
    'region': detail.region,
    'funding': detail.funding,
    'availability': detail.availability,
    'features': [
      for (final feature in detail.features)
        {'icon': feature.icon.name, 'text': feature.text},
    ],
    'fees': [
      for (final fee in detail.fees) {'label': fee.label, 'value': fee.value},
    ],
    'kycNote': detail.kycNote,
    'paymentChannels': detail.paymentChannels
        .map((channel) => channel.name)
        .toList(growable: false),
    'sourceLabel': detail.sourceLabel,
    'note': detail.note,
  };
}

class ProWorkspaceController extends ChangeNotifier {
  ProWorkspaceController(this._apiClient, {required this.accessTokenProvider});

  static const _storageKey = 'card-app-pro-workspace-v1';

  final ApiClient _apiClient;
  final ProAccessTokenProvider accessTokenProvider;
  ProWorkspaceSnapshot _snapshot = const ProWorkspaceSnapshot();
  bool loading = true;
  bool offlineRefreshing = false;
  bool syncing = false;
  String? message;

  ProWorkspaceSnapshot get snapshot => _snapshot;
  Set<String> get watchedCardIds => _snapshot.watchedCardIds;
  List<ProComparisonPreset> get comparisonPresets =>
      _snapshot.comparisonPresets;
  DateTime? get offlineUpdatedAt => _snapshot.offlineUpdatedAt;
  int get offlineCardCount => _snapshot.offlineDetails.length;

  bool isWatched(String cardId) => watchedCardIds.contains(cardId);

  CardDetail? cachedDetailFor(String cardId) =>
      _snapshot.offlineDetails[cardId]?.detail;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _snapshot = ProWorkspaceSnapshot.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } on FormatException {
        message = '本机 Pro 工作区数据已损坏，已使用空白状态。';
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> toggleWatched(CardSummary card) async {
    final next = {...watchedCardIds};
    if (!next.add(card.id)) next.remove(card.id);
    _snapshot = _copy(watchedCardIds: next);
    await _persist();
  }

  Future<void> saveComparison(List<CardSummary> cards) async {
    if (cards.length < 2) return;
    final cardIds = cards.map((card) => card.id).take(6).toList();
    final stableId = cardIds.join('|');
    final preset = ProComparisonPreset(
      id: stableId,
      cardIds: cardIds,
      cardNames: cards.map((card) => card.name).take(6).toList(),
      updatedAt: DateTime.now(),
    );
    final next = [
      preset,
      ...comparisonPresets.where((item) => item.id != stableId),
    ].take(30).toList(growable: false);
    _snapshot = _copy(comparisonPresets: next);
    message = '对比方案已保存到 Pro 工作区。';
    await _persist();
  }

  Future<void> removeComparison(String id) async {
    _snapshot = _copy(
      comparisonPresets: comparisonPresets
          .where((item) => item.id != id)
          .toList(growable: false),
    );
    await _persist();
  }

  Future<void> refreshOfflinePack({
    required List<CardSummary> cards,
    required Future<CardDetail> Function(CardSummary card) loadDetail,
  }) async {
    if (offlineRefreshing) return;
    offlineRefreshing = true;
    message = null;
    notifyListeners();
    try {
      final selected = cards.take(80).toList(growable: false);
      final details = await Future.wait(selected.map(loadDetail));
      _snapshot = _copy(
        offlineDetails: {
          for (var index = 0; index < details.length; index++)
            selected[index].id: CardDetailSnapshot(detail: details[index]),
        },
        offlineUpdatedAt: DateTime.now(),
      );
      message = '离线资料已更新，共 ${details.length} 张卡片。';
      await _persist();
    } catch (_) {
      message = '离线资料更新失败，请检查网络后重试。';
    } finally {
      offlineRefreshing = false;
      notifyListeners();
    }
  }

  Future<bool> sync() async {
    if (syncing) return false;
    syncing = true;
    message = null;
    notifyListeners();
    try {
      final token = (await accessTokenProvider())?.trim();
      if (token == null || token.isEmpty) {
        message = '安全账号服务接入后可同步 Pro 工作区。';
        return false;
      }
      final remote = jsonObject(
        await _apiClient.get(
          ProConfig.workspacePath,
          headers: {'authorization': 'Bearer $token'},
        ),
        label: 'Pro 工作区',
      );
      final remoteSnapshot = ProWorkspaceSnapshot.fromJson(
        jsonObject(remote['workspace'], label: 'Pro 工作区内容'),
      );
      final merged = _merge(remoteSnapshot);
      final saved = jsonObject(
        await _apiClient.put(
          ProConfig.workspacePath,
          headers: {'authorization': 'Bearer $token'},
          body: {'workspace': merged.toJson(includeOffline: false)},
        ),
        label: 'Pro 工作区同步结果',
      );
      final savedSnapshot = ProWorkspaceSnapshot.fromJson(
        jsonObject(saved['workspace'], label: 'Pro 工作区同步内容'),
      );
      _snapshot = ProWorkspaceSnapshot(
        watchedCardIds: savedSnapshot.watchedCardIds,
        comparisonPresets: savedSnapshot.comparisonPresets,
        offlineDetails: merged.offlineDetails,
        offlineUpdatedAt: merged.offlineUpdatedAt,
        updatedAt: savedSnapshot.updatedAt ?? merged.updatedAt,
      );
      message = 'Pro 工作区已完成同步。';
      await _persist();
      return true;
    } catch (_) {
      message = 'Pro 工作区暂时无法同步，请稍后重试。';
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  ProWorkspaceSnapshot _merge(ProWorkspaceSnapshot remote) {
    final localUpdatedAt = _snapshot.updatedAt;
    final remoteIsNewer =
        remote.updatedAt != null &&
        (localUpdatedAt == null || remote.updatedAt!.isAfter(localUpdatedAt));
    final selected = remoteIsNewer ? remote : _snapshot;
    return ProWorkspaceSnapshot(
      // 工作区作为一个带更新时间的快照同步，使删除操作也能传播，
      // 避免简单并集把已取消的关注或已删除的方案重新加回来。
      watchedCardIds: selected.watchedCardIds,
      comparisonPresets: selected.comparisonPresets,
      offlineDetails: _snapshot.offlineDetails,
      offlineUpdatedAt: _snapshot.offlineUpdatedAt,
      updatedAt: selected.updatedAt ?? DateTime.now(),
    );
  }

  ProWorkspaceSnapshot _copy({
    Set<String>? watchedCardIds,
    List<ProComparisonPreset>? comparisonPresets,
    Map<String, CardDetailSnapshot>? offlineDetails,
    DateTime? offlineUpdatedAt,
  }) {
    return ProWorkspaceSnapshot(
      watchedCardIds: watchedCardIds ?? _snapshot.watchedCardIds,
      comparisonPresets: comparisonPresets ?? _snapshot.comparisonPresets,
      offlineDetails: offlineDetails ?? _snapshot.offlineDetails,
      offlineUpdatedAt: offlineUpdatedAt ?? _snapshot.offlineUpdatedAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_snapshot.toJson()));
    notifyListeners();
  }
}

List<String> _stringList(Object? value, {required int limit}) {
  if (value is! List) return const [];
  final result = <String>[];
  final seen = <String>{};
  for (final item in value) {
    final text = item.toString().trim();
    if (text.isEmpty || !seen.add(text)) continue;
    result.add(text);
    if (result.length >= limit) break;
  }
  return result;
}
