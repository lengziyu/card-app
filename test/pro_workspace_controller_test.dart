import 'dart:convert';

import 'package:card_app/core/network/api_client.dart';
import 'package:card_app/features/catalog/data/local_card_catalog.dart';
import 'package:card_app/features/catalog/data/local_card_details.dart';
import 'package:card_app/features/pro/data/pro_workspace_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists watchlist, comparison presets and offline details', () async {
    final apiClient = ApiClient(baseUrl: 'https://example.test');
    final controller = ProWorkspaceController(
      apiClient,
      accessTokenProvider: () async => null,
    );
    await controller.initialize();

    await controller.toggleWatched(localCardCatalog[0]);
    await controller.saveComparison(localCardCatalog.take(3).toList());
    await controller.refreshOfflinePack(
      cards: localCardCatalog.take(3).toList(),
      loadDetail: (card) async =>
          const LocalCardDetailRepository().detailFor(card),
    );

    expect(controller.isWatched(localCardCatalog[0].id), isTrue);
    expect(controller.comparisonPresets.single.cardIds, hasLength(3));
    expect(controller.offlineCardCount, 3);
    expect(controller.cachedDetailFor(localCardCatalog[1].id), isNotNull);

    final restored = ProWorkspaceController(
      apiClient,
      accessTokenProvider: () async => null,
    );
    await restored.initialize();
    expect(restored.isWatched(localCardCatalog[0].id), isTrue);
    expect(restored.comparisonPresets.single.cardIds, hasLength(3));
    expect(restored.offlineCardCount, 3);

    restored.dispose();
    controller.dispose();
    apiClient.close();
  });

  test('sync stays safe when the account provider is not connected', () async {
    final apiClient = ApiClient(baseUrl: 'https://example.test');
    final controller = ProWorkspaceController(
      apiClient,
      accessTokenProvider: () async => null,
    );
    await controller.initialize();

    expect(await controller.sync(), isFalse);
    expect(controller.message, contains('安全账号服务'));

    controller.dispose();
    apiClient.close();
  });

  test('offline snapshots never retain invite entry fields', () {
    final snapshot = CardDetailSnapshot.fromJson({
      'cardId': 'example',
      'inviteCode': 'must-not-cache',
      'inviteUrl': 'https://example.test/invite',
    });

    expect(snapshot.detail.inviteCode, isNull);
    expect(snapshot.detail.inviteUrl, isNull);
    expect(snapshot.toJson(), isNot(contains('inviteCode')));
    expect(snapshot.toJson(), isNot(contains('inviteUrl')));
  });

  test('newer local snapshot keeps deletions during cloud sync', () async {
    Map<String, dynamic>? uploadedWorkspace;
    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'workspace': {
              'version': 1,
              'watchedCardIds': [localCardCatalog.first.id],
              'comparisonPresets': const [],
              'updatedAt': '2000-01-01T00:00:00.000Z',
            },
          }),
          200,
        );
      }
      uploadedWorkspace =
          (jsonDecode(request.body) as Map<String, dynamic>)['workspace']
              as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'workspace': {
            ...uploadedWorkspace!,
            'updatedAt': '2026-07-21T12:00:00.000Z',
          },
        }),
        200,
      );
    });
    final apiClient = ApiClient(
      client: mockClient,
      baseUrl: 'https://example.test',
    );
    final controller = ProWorkspaceController(
      apiClient,
      accessTokenProvider: () async => 'safe-access-token',
    );
    await controller.initialize();
    await controller.toggleWatched(localCardCatalog.first);
    await controller.toggleWatched(localCardCatalog.first);

    expect(await controller.sync(), isTrue);
    expect(uploadedWorkspace?['watchedCardIds'], isEmpty);
    expect(controller.watchedCardIds, isEmpty);

    controller.dispose();
    apiClient.close();
  });
}
