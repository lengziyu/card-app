import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/ledger/domain/ledger_models.dart';

abstract final class LedgerConfig {
  // Enable only after the independent service and account deletion path pass
  // integration checks. Old app and legacy bill APIs remain unchanged.
  static const enabled = bool.fromEnvironment(
    'ENABLE_PERSONAL_LEDGER',
    defaultValue: false,
  );
  static const baseUrl = String.fromEnvironment('LEDGER_API_BASE_URL');
}

class LedgerRepository {
  LedgerRepository(
    this.client, {
    required this.subject,
    required this.currentSubject,
    required this.accessToken,
  });
  final ApiClient client;
  final String subject;
  final String? Function() currentSubject;
  final Future<String?> Function() accessToken;
  static const path = '/api/user/card-ledger';

  void _checkSession() {
    if (subject.isEmpty || currentSubject() != subject) {
      throw const ApiException(
        code: 'SESSION_CHANGED',
        message: '账号已切换，请重新打开账本',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String suffix, {
    Map<String, Object?>? query,
    Map<String, Object?>? body,
  }) async {
    _checkSession();
    final token = await accessToken();
    _checkSession();
    if (token == null || token.isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '请先登录');
    }
    final headers = {'authorization': 'Bearer $token'};
    try {
      final Object? response = switch (method) {
        'POST' => await client.post(
          '$path$suffix',
          body: body,
          headers: headers,
        ),
        'PATCH' => await client.patch(
          '$path$suffix',
          body: body,
          headers: headers,
        ),
        'DELETE' => await client.delete(
          '$path$suffix',
          body: body,
          headers: headers,
        ),
        _ => await client.get('$path$suffix', query: query, headers: headers),
      };
      _checkSession();
      return jsonObject(response);
    } on ApiException catch (error) {
      _checkSession();
      if (error.statusCode == 404 &&
          method == 'GET' &&
          const ['/cards', '/entries', '/summary'].contains(suffix)) {
        throw const ApiException(
          code: 'LEDGER_UNAVAILABLE',
          message: '消费账本暂未开放，请稍后重试',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  Future<List<PersonalCard>> cards() async {
    final data = await _request('GET', '/cards');
    return jsonList(
      data['cards'],
    ).map((item) => PersonalCard.fromJson(jsonObject(item))).toList();
  }

  Future<PersonalCard> saveCard(
    Map<String, Object?> input, {
    PersonalCard? existing,
    required String requestId,
  }) async {
    final data = await _request(
      existing == null ? 'POST' : 'PATCH',
      '/cards${existing == null ? '' : '/${Uri.encodeComponent(existing.id)}'}',
      body: {
        ...input,
        if (existing == null) 'requestId': requestId,
        if (existing != null) 'expectedRevision': existing.revision,
      },
    );
    return PersonalCard.fromJson(jsonObject(data['card']));
  }

  Future<void> deleteCard(PersonalCard card) async => _request(
    'DELETE',
    '/cards/${Uri.encodeComponent(card.id)}',
    body: {'expectedRevision': card.revision},
  );

  Future<LedgerPage> entries({
    String? month,
    String? userCardId,
    String? currency,
    String? state,
    String? cursor,
  }) async {
    final data = await _request(
      'GET',
      '/entries',
      query: {
        'month': month,
        'userCardId': userCardId,
        'currency': currency,
        'state': state,
        'cursor': cursor,
        'limit': 50,
      },
    );
    return LedgerPage(
      jsonList(
        data['entries'],
      ).map((item) => LedgerEntry.fromJson(jsonObject(item))).toList(),
      data['nextCursor'] as String?,
    );
  }

  Future<LedgerSummary> summary({
    required String month,
    String? userCardId,
    String? currency,
  }) async {
    final data = await _request(
      'GET',
      '/summary',
      query: {'month': month, 'userCardId': userCardId, 'currency': currency},
    );
    return LedgerSummary.fromJson(jsonObject(data['summary']));
  }

  Future<LedgerEntry> saveEntry(
    Map<String, Object?> input, {
    LedgerEntry? existing,
    required String requestId,
  }) async {
    final data = await _request(
      existing == null ? 'POST' : 'PATCH',
      '/entries${existing == null ? '' : '/${Uri.encodeComponent(existing.id)}'}',
      body: {
        ...input,
        if (existing == null) 'requestId': requestId,
        if (existing != null) 'expectedRevision': existing.revision,
      },
    );
    return LedgerEntry.fromJson(jsonObject(data['entry']));
  }

  Future<void> deleteEntry(LedgerEntry entry) async => _request(
    'DELETE',
    '/entries/${Uri.encodeComponent(entry.id)}',
    body: {'expectedRevision': entry.revision},
  );

  Future<bool> eraseForAccountDeletion() async {
    try {
      await _request('DELETE', '');
      return true;
    } on ApiException catch (error) {
      // A deployment without this route has no ledger data. Other failures must
      // block account deletion so personal records are never silently orphaned.
      if (error.statusCode != 404) rethrow;
      return false;
    }
  }
}
