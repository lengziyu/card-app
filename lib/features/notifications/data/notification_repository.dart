import 'package:card_app/core/network/api_client.dart';

class AppMessage {
  const AppMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final String route;
  final DateTime? sentAt;
}

class NotificationRepository {
  const NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> subscribe({
    required String installationId,
    required String token,
    required String platform,
    required String locale,
  }) async {
    await _apiClient.post(
      '/api/push/subscriptions',
      body: {
        'installationId': installationId,
        'token': token,
        'platform': platform,
        'locale': locale,
        'enabled': true,
      },
    );
  }

  Future<void> unsubscribe({required String installationId}) =>
      _apiClient.delete(
        '/api/push/subscriptions',
        body: {'installationId': installationId},
      );

  Future<List<AppMessage>> loadMessages(String installationId) async {
    final json = jsonObject(
      await _apiClient.get(
        '/api/app-messages',
        query: {'installationId': installationId},
      ),
      label: '应用内消息',
    );
    return jsonList(json['items'] ?? const [], label: '应用内消息')
        .map((value) {
          final item = jsonObject(value, label: '消息');
          return AppMessage(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            body: item['body']?.toString() ?? '',
            route: item['route']?.toString() ?? '/',
            sentAt: DateTime.tryParse(item['sentAt']?.toString() ?? ''),
          );
        })
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }
}
