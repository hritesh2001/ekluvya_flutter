import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/rating_model.dart';

/// HTTP layer for:
///   GET [mediaBaseUrl]/ratings/channel-ratings
///       ?chapterId=&courseId=&subjectId=&classId=
class RatingApiService {
  static const _tag = 'RatingApiService';

  Future<List<ChannelRatingModel>> fetchChannelRatings({
    required String courseId,
    required String classId,
    required String subjectId,
    required String chapterId,
  }) async {
    final url =
        '${AppConstants.mediaBaseUrl}/ratings/channel-ratings'
        '?chapterId=$chapterId&courseId=$courseId'
        '&subjectId=$subjectId&classId=$classId';

    AppLogger.info(_tag, 'GET channel-ratings → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Channel-ratings response ${res.statusCode}');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  List<ChannelRatingModel> _parse(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) throw const ParseException();

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException {
      throw const ParseException();
    }

    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      throw ServerException(decoded['message']?.toString() ?? 'Server error');
    }

    // Path: response → channels[]
    final response = decoded['response'];
    final channels =
        response is Map<String, dynamic> ? response['channels'] as List? : null;

    if (channels == null) {
      AppLogger.warning(_tag, 'No channels in channel-ratings response');
      return [];
    }

    final data = channels
        .whereType<Map<String, dynamic>>()
        .map(ChannelRatingModel.fromJson)
        .where((r) => r.channelId.isNotEmpty)
        .toList();

    AppLogger.info(_tag, 'Parsed ratings for ${data.length} channels');
    return data;
  }

  Never _handleError(Object e, StackTrace st) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, 'fetchChannelRatings error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) throw const NetworkException();
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
