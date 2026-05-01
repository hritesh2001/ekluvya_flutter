import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../channel/data/models/video_item_model.dart';

/// Fetches per-episode data including HLS URL and access validity.
///
/// Endpoint:
///   GET [mediaBaseUrl]/watch/series/series-data/{slug}
class WatchApiService {
  static const _tag = 'WatchApiService';

  Future<VideoItemModel> fetchEpisode(String slug, {String? token}) async {
    final url = '${AppConstants.mediaBaseUrl}/watch/series/series-data/$slug';
    AppLogger.info(_tag, 'GET episode → $url (auth=${token != null && token.isNotEmpty})');

    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http
          .get(Uri.parse(url), headers: headers.isEmpty ? null : headers)
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Episode response ${res.statusCode} body-start="${res.body.substring(0, res.body.length.clamp(0, 120))}"');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st, 'fetchEpisode');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  VideoItemModel _parse(http.Response res) {
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
      throw ServerException(
          decoded['message']?.toString() ?? 'Server error');
    }

    // response.data is a list; take first item
    final response = decoded['response'];
    List? dataList;
    if (response is Map<String, dynamic>) {
      dataList = response['data'] as List?;
    }
    dataList ??= decoded['data'] as List?;

    if (dataList == null || dataList.isEmpty) {
      throw const ParseException();
    }

    final item = dataList.first;
    if (item is! Map<String, dynamic>) throw const ParseException();

    // Flatten master_details_id fields into the episode map so
    // VideoItemModel.fromJson picks up is_subscription, monetization, etc.
    final merged = <String, dynamic>{...item};
    final master = item['master_details_id'];
    if (master is Map<String, dynamic>) {
      merged.addAll(master);
      // Preserve episode-level _id over master _id
      merged['_id'] = item['_id']?.toString() ?? master['_id']?.toString() ?? '';
    }

    final video = VideoItemModel.fromJson(merged);
    AppLogger.info(_tag, 'Parsed episode: ${video.title} | ${video.hlsUrl}');
    return video;
  }

  Never _handleError(Object e, StackTrace st, String method) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, '$method error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) throw const NetworkException();
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
