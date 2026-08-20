import 'package:cardfi/core/network/api_client.dart';

class RemoteCatalogSettingsRepository {
  RemoteCatalogSettingsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<String>> loadHomeDefaultCardIds() =>
      _loadCardIds('/api/home-default-cards');

  Future<List<String>> loadListCardOrder() =>
      _loadCardIds('/api/list-card-order');

  Future<List<String>> _loadCardIds(String path) async {
    final response = jsonObject(await _apiClient.get(path));
    return jsonList(response['cardIds'] ?? const [], label: '卡片编号')
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
