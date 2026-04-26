import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/rating_model.dart';
import '../models/video_rating_model.dart';

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

  // ── Video rating ─────────────────────────────────────────────────────────────

  /// POST /mediaview/api/v1/ratings/create
  /// Submits a 1–5 star rating for a video.  Returns updated rating data on
  /// success, null on non-fatal failure so the ViewModel can decide whether to
  /// revert the optimistic update.
  Future<VideoRatingModel?> submitVideoRating({
    required String token,
    required String masterDetailsId,
    required int ratingPoints,
  }) async {
    final url = '${AppConstants.mediaBaseUrl}/ratings/create';
    final body = jsonEncode({
      'master_details_id': masterDetailsId,
      'sho_type':          2,
      'rating_points':     ratingPoints,
    });
    AppLogger.info(_tag, 'POST submit-rating → $url | id=$masterDetailsId pts=$ratingPoints');
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'submitVideoRating ${res.statusCode}: ${res.body}');
      if (res.statusCode == 401) throw const UnauthorizedException();
      if (res.body.trimLeft().startsWith('<!')) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final ok = decoded['status'] == 'success' ||
          (decoded['statusCode'] as num?)?.toInt() == 200 ||
          (decoded['statusCode'] as num?)?.toInt() == 201;
      if (!ok) {
        AppLogger.warning(_tag, 'submitVideoRating rejected: ${decoded['message']}');
        return null;
      }
      return VideoRatingModel.fromJson(decoded);
    } on AppException {
      rethrow; // let ViewModel revert the optimistic update
    } catch (e, st) {
      AppLogger.error(_tag, 'submitVideoRating error: $e', e, st);
      return null;
    }
  }

  /// GET /mediaview/api/v1/ratings/overall/{masterDetailsId}
  /// Fetches the community-average rating and the current user's own vote.
  /// Returns null on any failure (non-fatal — absence of rating data is safe).
  Future<VideoRatingModel?> fetchVideoRating({
    required String masterDetailsId,
    String token = '',
  }) async {
    final url = '${AppConstants.mediaBaseUrl}/ratings/overall/$masterDetailsId';
    AppLogger.info(_tag, 'GET overall-rating → $url');
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: token.isNotEmpty
                ? {'Authorization': 'Bearer $token'}
                : null,
          )
          .timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'fetchVideoRating ${res.statusCode}: ${res.body}');
      if (res.body.trimLeft().startsWith('<!')) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return VideoRatingModel.fromJson(decoded);
    } catch (e, st) {
      AppLogger.error(_tag, 'fetchVideoRating error: $e', e, st);
      return null;
    }
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
