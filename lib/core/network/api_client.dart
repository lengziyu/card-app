import 'dart:async';
import 'dart:convert';

import 'package:card_app/core/network/api_exception.dart';
import 'package:card_app/core/network/app_environment.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse(baseUrl ?? AppEnvironment.apiBaseUrl);

  final http.Client _client;
  final Uri _baseUri;

  static const _readTimeout = Duration(seconds: 15);
  static const _writeTimeout = Duration(seconds: 30);

  Uri resolve(String path, [Map<String, Object?>? query]) {
    final normalizedBase = _baseUri.toString().endsWith('/')
        ? _baseUri
        : Uri.parse('${_baseUri.toString()}/');
    final uri = normalizedBase.resolve(path.replaceFirst(RegExp(r'^/+'), ''));
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      },
    );
  }

  Future<Object?> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
  }) async {
    final uri = resolve(path, query);
    try {
      final request = http.Request(method, uri)
        ..headers['accept'] = 'application/json';
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client
          .send(request)
          .timeout(method == 'GET' ? _readTimeout : _writeTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{};
        throw ApiException(
          code: error['code']?.toString() ?? 'REQUEST_FAILED',
          message: error['message']?.toString() ?? '请求失败',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(code: 'REQUEST_TIMEOUT', message: '请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(code: 'NETWORK_ERROR', message: '网络连接失败，请稍后重试');
    }
  }

  Object? _decode(String source) {
    if (source.trim().isEmpty) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      throw const ApiException(code: 'INVALID_RESPONSE', message: '服务返回了无效数据');
    }
  }

  void close() => _client.close();
}

Map<String, dynamic> jsonObject(Object? value, {String label = '响应'}) {
  if (value is Map<String, dynamic>) return value;
  throw ApiException(code: 'INVALID_RESPONSE', message: '$label格式不正确');
}

List<dynamic> jsonList(Object? value, {String label = '列表'}) {
  if (value is List<dynamic>) return value;
  throw ApiException(code: 'INVALID_RESPONSE', message: '$label格式不正确');
}
