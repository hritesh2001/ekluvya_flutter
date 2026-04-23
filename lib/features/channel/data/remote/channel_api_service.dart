import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/channel_model.dart';

/// HTTP layer for the channel-list endpoint.
///
/// Endpoint:
///   GET [mediaBaseUrl]/home/channel-list
///     ?courseId=&subjectId=&classId=&chapterId=
///     &page=1&limit=10&inside_limit=12
///
/// Auth token is optional but strongly recommended — the server uses it to
/// compute per-user subscription state (is_user_subscribed) per video.
class ChannelApiService {
  static const _tag = 'ChannelApiService';

  Future<List<ChannelModel>> fetchChannels({
    required String courseId,
    required String classId,
    required String subjectId,
    String chapterId = '',
    int page = 1,
    int channelLimit = 100,  // channels per page (match Android)
    int insideLimit = 1000,  // videos per channel (match Android)
    String? token,           // when provided, sends Authorization header
  }) async {
    // Build URL — only include chapterId when non-empty.
    final sb = StringBuffer(
      '${AppConstants.mediaBaseUrl}/home/channel-list'
      '?courseId=$courseId'
      '&subjectId=$subjectId'
      '&classId=$classId',
    );
    if (chapterId.isNotEmpty) sb.write('&chapterId=$chapterId');
    sb.write('&page=$page&limit=$channelLimit&inside_limit=$insideLimit');

    final url = sb.toString();
    AppLogger.info(_tag, 'GET channels → $url');

    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http
          .get(Uri.parse(url), headers: headers.isEmpty ? null : headers)
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Channels response ${res.statusCode}');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st, 'fetchChannels');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  List<ChannelModel> _parse(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) {
      AppLogger.error(_tag, 'Received HTML instead of JSON');
      throw const ParseException();
    }

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException catch (e) {
      AppLogger.error(_tag, 'JSON parse error: $e');
      throw const ParseException();
    }

    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      final msg = decoded['message']?.toString() ?? 'Server error';
      throw ServerException(msg);
    }

    List? rawList;
    final response = decoded['response'];
    if (response is Map<String, dynamic>) {
      rawList = response['data'] as List?;
    }
    rawList ??= decoded['data'] as List?;

    if (rawList == null) {
      AppLogger.warning(_tag, 'No data array found in channels response');
      return [];
    }

    final seen = <String>{};
    final channels = rawList
        .whereType<Map<String, dynamic>>()
        .map(ChannelModel.fromJson)
        .where((c) => c.hasValidId && c.isNotEmpty && seen.add(c.id))
        .toList();

    AppLogger.info(_tag, 'Parsed ${channels.length} channels');
    return channels;
  }

  Never _handleError(Object e, StackTrace st, String method) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, '$method error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('lookup') || msg.contains('network')) {
        throw const NetworkException();
      }
      throw ServerException('Connection failed: ${e.message}');
    }
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
