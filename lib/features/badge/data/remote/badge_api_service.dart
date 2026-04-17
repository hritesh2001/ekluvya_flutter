import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/badge_model.dart';

/// HTTP layer for:
///   GET [mediaBaseUrl]/badges/chapter-badges?courseId=&chapterId=
class BadgeApiService {
  static const _tag = 'BadgeApiService';

  Future<List<ChannelBadgeData>> fetchChapterBadges({
    required String courseId,
    required String chapterId,
  }) async {
    final url =
        '${AppConstants.mediaBaseUrl}/badges/chapter-badges'
        '?courseId=$courseId&chapterId=$chapterId';

    AppLogger.info(_tag, 'GET chapter-badges → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Chapter-badges response ${res.statusCode}');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  List<ChannelBadgeData> _parse(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) {
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

    // Path: response → winners → studios[]
    final response = decoded['response'];
    final winners =
        response is Map<String, dynamic> ? response['winners'] : null;
    final studios =
        winners is Map<String, dynamic> ? winners['studios'] as List? : null;

    if (studios == null) {
      AppLogger.warning(_tag, 'No studios in chapter-badges response');
      return [];
    }

    final data = studios
        .whereType<Map<String, dynamic>>()
        .map(ChannelBadgeData.fromJson)
        .where((b) => b.channelId.isNotEmpty)
        .toList();

    AppLogger.info(_tag, 'Parsed badge data for ${data.length} channels');
    return data;
  }

  Never _handleError(Object e, StackTrace st) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, 'fetchChapterBadges error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) {
      throw const NetworkException();
    }
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
