import 'dart:async';
import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RemoteUserCardState {
  const RemoteUserCardState({
    required this.addedCardIds,
    required this.favoriteCardIds,
    required this.recentCardIds,
  });

  factory RemoteUserCardState.fromJson(Map<String, dynamic> json) {
    return RemoteUserCardState(
      addedCardIds: _stringList(json['myCardIds'], limit: 240),
      favoriteCardIds: _stringList(json['favoriteIds'], limit: 240),
      recentCardIds: _stringList(json['recentIds'], limit: 8),
    );
  }

  final List<String> addedCardIds;
  final List<String> favoriteCardIds;
  final List<String> recentCardIds;

  Map<String, Object?> toJson() => {
    'myCardIds': addedCardIds,
    'favoriteIds': favoriteCardIds,
    'recentIds': recentCardIds,
  };
}

class RemoteUserDataRepository {
  RemoteUserDataRepository(
    this._apiClient, {
    required this._accessTokenProvider,
    http.Client? uploadClient,
  }) : _uploadClient = uploadClient ?? http.Client();

  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;
  final http.Client _uploadClient;

  Future<RemoteUserCardState> loadCardState({String? accessToken}) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/user/card-state',
        headers: await _headers(accessToken),
      ),
      label: '个人卡片状态',
    );
    return RemoteUserCardState.fromJson(response);
  }

  Future<void> saveCardState(
    RemoteUserCardState state, {
    String? accessToken,
  }) async {
    await _apiClient.put(
      '/api/user/card-state',
      headers: await _headers(accessToken),
      body: state.toJson(),
    );
  }

  Future<List<String>> loadArticleFavorites({String? accessToken}) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/user/article-state',
        headers: await _headers(accessToken),
      ),
      label: '文章收藏状态',
    );
    return _stringList(response['favoriteArticleIds'], limit: 240);
  }

  Future<void> saveArticleFavorites(
    Iterable<String> ids, {
    String? accessToken,
  }) async {
    await _apiClient.put(
      '/api/user/article-state',
      headers: await _headers(accessToken),
      body: {'favoriteArticleIds': _normalizeIds(ids, limit: 240)},
    );
  }

  Future<List<LocalSubmission>> loadSubmissions({String? accessToken}) async {
    final response = jsonObject(
      await _apiClient.get(
        '/api/user/submissions',
        headers: await _headers(accessToken),
      ),
      label: '反馈记录',
    );
    return jsonList(response['items'] ?? const [], label: '反馈记录')
        .map((item) => LocalSubmission.fromJson(jsonObject(item, label: '反馈')))
        .where((item) => item.id.isNotEmpty && item.description.isNotEmpty)
        .toList(growable: false);
  }

  Future<LocalSubmission> createSubmission(
    LocalSubmissionDraft draft, {
    String? accessToken,
  }) async {
    if (draft.category == LocalSubmissionCategory.tip &&
        (draft.subject?.trim().isEmpty ?? true)) {
      throw const ApiException(code: 'TIP_TITLE_REQUIRED', message: '请填写技巧标题');
    }
    if (draft.category == LocalSubmissionCategory.tip &&
        draft.subject!.trim().length > 80) {
      throw const ApiException(
        code: 'INVALID_TIP_TITLE',
        message: '技巧标题需控制在 80 字以内',
      );
    }
    if (draft.category == LocalSubmissionCategory.tip &&
        (draft.description.trim().isEmpty ||
            draft.description.trim().length > 2000)) {
      throw const ApiException(
        code: 'INVALID_TIP_DESCRIPTION',
        message: '经验描述需控制在 2000 字以内',
      );
    }
    if (draft.category == LocalSubmissionCategory.tip &&
        (draft.cardId?.trim().isEmpty ?? true)) {
      throw const ApiException(code: 'TIP_CARD_REQUIRED', message: '请选择关联卡片');
    }
    final path = switch (draft.category) {
      LocalSubmissionCategory.correction => '/api/submissions/corrections',
      LocalSubmissionCategory.recommendation =>
        '/api/submissions/recommendations',
      LocalSubmissionCategory.tip => '/api/submissions/tips',
      LocalSubmissionCategory.message => '/api/submissions/messages',
    };
    if (draft.images.isNotEmpty) {
      if (draft.category != LocalSubmissionCategory.tip) {
        throw const ApiException(
          code: 'SUBMISSION_IMAGES_NOT_SUPPORTED',
          message: '当前只有技巧投稿支持附加图片。',
        );
      }
      return _createTipWithImages(path, draft, accessToken);
    }
    final body = _submissionBody(draft);
    try {
      final response = jsonObject(
        await _apiClient.post(
          path,
          headers: await _headers(accessToken),
          body: body,
        ),
        label: '反馈提交结果',
      );
      return LocalSubmission.fromJson(response);
    } on ApiException catch (error) {
      throw _normalizeTipApiError(draft.category, error);
    }
  }

  Future<LocalSubmission> _createTipWithImages(
    String path,
    LocalSubmissionDraft draft,
    String? accessToken,
  ) async {
    _validateImages(draft.images);
    final request = http.MultipartRequest('POST', _apiClient.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        ...await _headers(accessToken),
      });
    for (final entry in _submissionBody(draft).entries) {
      final value = entry.value;
      request.fields[entry.key] = value is List ? jsonEncode(value) : '$value';
    }
    for (final image in draft.images) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          image.bytes,
          filename: _safeFileName(image.fileName),
          contentType: MediaType.parse(image.mimeType),
        ),
      );
    }

    try {
      final streamed = await _uploadClient
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{};
        throw _normalizeTipApiError(
          LocalSubmissionCategory.tip,
          ApiException(
            code: error['code']?.toString() ?? 'TIP_UPLOAD_FAILED',
            message: error['message']?.toString() ?? '技巧图片上传失败，请稍后重试',
            statusCode: response.statusCode,
          ),
        );
      }
      return LocalSubmission.fromJson(jsonObject(decoded, label: '技巧投稿结果'));
    } on TimeoutException {
      throw const ApiException(
        code: 'REQUEST_TIMEOUT',
        message: '图片上传超时，请检查网络后重试',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        code: 'TIP_UPLOAD_FAILED',
        message: '技巧图片上传失败，请检查网络后重试',
      );
    }
  }

  Map<String, Object?> _submissionBody(LocalSubmissionDraft draft) {
    final subject = draft.subject?.trim();
    final isTip = draft.category == LocalSubmissionCategory.tip;
    return {
      // Put the required title fields first in multipart requests. Some older
      // handlers stopped reading fields after file parts, so they must arrive
      // before the description and uploaded images.
      if (subject?.isNotEmpty == true && isTip) 'title': subject,
      if (subject?.isNotEmpty == true) 'subject': subject,
      'description': draft.description.trim(),
      if (draft.link?.trim().isNotEmpty == true) 'link': draft.link!.trim(),
      if (draft.cardId?.trim().isNotEmpty == true)
        'cardId': draft.cardId!.trim(),
      if (draft.cardName?.trim().isNotEmpty == true)
        'cardName': draft.cardName!.trim(),
      if (isTip) 'publishAnonymously': draft.publishAnonymously,
    };
  }

  void _validateImages(List<LocalSubmissionImage> images) {
    if (images.length > maxLocalSubmissionImages) {
      throw const ApiException(
        code: 'TOO_MANY_TIP_IMAGES',
        message: '技巧投稿最多上传 3 张图片',
      );
    }
    var totalBytes = 0;
    for (final image in images) {
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(image.mimeType)) {
        throw const ApiException(
          code: 'UNSUPPORTED_TIP_IMAGE',
          message: '图片仅支持 JPG、PNG 或 WebP 格式',
        );
      }
      if (image.bytes.isEmpty ||
          image.bytes.length > maxLocalSubmissionImageBytes) {
        throw const ApiException(
          code: 'TIP_IMAGE_TOO_LARGE',
          message: '每张图片需小于 4 MB',
        );
      }
      totalBytes += image.bytes.length;
    }
    if (totalBytes > maxLocalSubmissionImageTotalBytes) {
      throw const ApiException(
        code: 'TIP_IMAGES_TOO_LARGE',
        message: '投稿图片总大小需小于 10 MB',
      );
    }
  }

  String _safeFileName(String value) {
    final name = value.trim().split(RegExp(r'[/\\]')).last;
    return name.isEmpty ? 'tip-image.jpg' : name;
  }

  Object? _decode(String source) {
    if (source.trim().isEmpty) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '技巧投稿服务返回了无效数据',
      );
    }
  }

  ApiException _normalizeTipApiError(
    LocalSubmissionCategory category,
    ApiException error,
  ) {
    if (category != LocalSubmissionCategory.tip) return error;
    if (error.statusCode == 404 || error.code == 'INVALID_JSON') {
      return const ApiException(
        code: 'TIP_API_UNAVAILABLE',
        message: '技巧投稿服务尚未完成更新，请稍后再试',
      );
    }
    return error;
  }

  Future<Map<String, String>> _headers([String? accessToken]) async {
    final token = (accessToken ?? await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: '请先登录并完成邮箱验证后再同步个人数据。',
      );
    }
    return {'authorization': 'Bearer $token'};
  }
}

List<String> _stringList(Object? value, {required int limit}) => value is List
    ? _normalizeIds(value.map((item) => item.toString()), limit: limit)
    : const [];

List<String> _normalizeIds(Iterable<String> ids, {required int limit}) {
  final result = <String>[];
  final seen = <String>{};
  for (final rawId in ids) {
    final id = rawId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    result.add(id);
    if (result.length == limit) break;
  }
  return result;
}
