import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

class BookmarkApiService {
  static const _tag = 'BookmarkApiService';

  // ── Toggle (add / remove) ─────────────────────────────────────────────────

  /// PUT /home/bookmark
  /// [isWatchLater] = 1 → add, 0 → remove
  Future<void> toggleBookmark({
    required String token,
    required String episodeId,
    required String seasonId,
    required int isWatchLater,
  }) async {
    final uri = Uri.parse('${AppConstants.mediaBaseUrl}/home/bookmark');

    final body = json.encode({
      'episode_id': episodeId,
      'id': episodeId,
      'is_watch_later': isWatchLater,
      'season_id': seasonId,
      'sho_type': 2,
    });

    AppLogger.info(
      _tag,
      'toggleBookmark ▶  PUT $uri  '
      'episodeId=$episodeId  is_watch_later=$isWatchLater',
    );

    final response = await http
        .put(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: body,
        )
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(
      _tag,
      'toggleBookmark ◀  ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'toggleBookmark failed [${response.statusCode}]: ${response.body}',
      );
    }
  }

  // ── Fetch list ─────────────────────────────────────────────────────────────

  /// GET /home/bookmark-list?limit=14&page=`page`
  Future<Map<String, dynamic>> fetchBookmarks({
    required String token,
    int page = 1,
    int limit = 14,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.mediaBaseUrl}/home/bookmark-list'
      '?limit=$limit&page=$page',
    );

    AppLogger.info(_tag, 'fetchBookmarks ▶  GET $uri');

    final response = await http
        .get(uri, headers: {HttpHeaders.authorizationHeader: 'Bearer $token'})
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(_tag, 'fetchBookmarks ◀  ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'fetchBookmarks failed [${response.statusCode}]: ${response.body}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
