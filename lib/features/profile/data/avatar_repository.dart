import 'dart:convert';
import 'dart:typed_data';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// Account-bound avatar API. The image itself is stored by the card API,
/// rather than in the device sandbox, so rankings and another signed-in
/// device can render the same profile image.
class AvatarRepository {
  AvatarRepository(
    this._apiClient, {
    required this.accessTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _avatarPath = '/api/user/avatar';
  static const _maxBytes = 5 * 1024 * 1024;

  final ApiClient _apiClient;
  final Future<String?> Function() accessTokenProvider;
  final http.Client _client;

  Future<String?> loadAvatarUrl() async {
    final token = await _token();
    try {
      final response = jsonObject(
        await _apiClient.get(
          _avatarPath,
          headers: {'authorization': 'Bearer $token'},
        ),
        label: '头像资料',
      );
      return _resolveAvatarUrl(response['avatarUrl']?.toString());
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> upload(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const ApiException(
        code: 'AVATAR_FILE_REQUIRED',
        message: '请选择头像图片',
      );
    }
    if (bytes.length > _maxBytes) {
      throw const ApiException(
        code: 'AVATAR_FILE_TOO_LARGE',
        message: '头像图片不能超过 5MB',
      );
    }

    final request =
        http.MultipartRequest('POST', _apiClient.resolve(_avatarPath))
          ..headers.addAll({
            'accept': 'application/json',
            'authorization': 'Bearer ${await _token()}',
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              Uint8List.fromList(bytes),
              filename: _filenameFor(image),
              contentType: _mimeTypeFor(image),
            ),
          );
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{};
        throw ApiException(
          code: error['code']?.toString() ?? 'AVATAR_UPLOAD_FAILED',
          message: error['message']?.toString() ?? '头像上传失败，请稍后重试',
          statusCode: response.statusCode,
        );
      }
      final object = jsonObject(decoded, label: '头像上传');
      final avatarUrl = _resolveAvatarUrl(object['avatarUrl']?.toString());
      if (avatarUrl == null) {
        throw const ApiException(
          code: 'INVALID_RESPONSE',
          message: '头像服务返回了无效地址',
        );
      }
      return avatarUrl;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        code: 'AVATAR_UPLOAD_FAILED',
        message: '头像上传失败，请检查网络后重试',
      );
    }
  }

  Future<String> _token() async {
    final token = (await accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(code: 'UNAUTHORIZED', message: '请先登录后再修改头像');
    }
    return token;
  }

  String? _resolveAvatarUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return uri.toString();
    return _apiClient.resolve(url).toString();
  }

  Object? _decode(String source) {
    if (source.trim().isEmpty) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '头像服务返回了无效数据',
      );
    }
  }

  String _filenameFor(XFile image) {
    final name = image.name.trim();
    if (name.isNotEmpty) return name;
    return 'avatar.jpg';
  }

  MediaType _mimeTypeFor(XFile image) {
    final extension = _filenameFor(image).split('.').last.toLowerCase();
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
