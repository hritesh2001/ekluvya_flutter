import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

class WatchHistoryApiService {
  static const _tag = 'WatchHistoryApiService';

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchWatchHistory({
    required String token,
    required String profileId,
    int limit = 14,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.userActionsBaseUrl}/watch-history'
      '?watch_type=continue_watch&is_promo=true'
      '&profile_id=$profileId&limit=$limit',
    );

    AppLogger.info(_tag, 'GET $uri');

    final response = await http
        .get(uri, headers: {HttpHeaders.authorizationHeader: 'Bearer $token'})
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(_tag, 'fetchWatchHistory → ${response.statusCode}');

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'response': decoded};
  }

  // ── Remove single item ─────────────────────────────────────────────────────

  /// DELETE /watch-history/{media_id}
  /// Body: {"watch_type":"continue_watch","profile_id":"..."}
  Future<void> removeItem({
    required String token,
    required String mediaId,
    required String profileId,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.userActionsBaseUrl}/watch-history/$mediaId',
    );

    final body = json.encode({
      'watch_type': 'continue_watch',
      'profile_id': profileId,
    });

    AppLogger.info(
      _tag,
      'removeItem ▶  DELETE $uri\n'
      '  profile_id: ${profileId.isNotEmpty ? profileId : "(empty)"}\n'
      '  body: $body',
    );

    final response = await http
        .delete(
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
      'removeItem ◀  ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'removeItem failed [${response.statusCode}]: ${response.body}',
      );
    }
  }

  // ── Post watch progress ────────────────────────────────────────────────────

  /// POST /watch-history — records a watched segment for My History.
  Future<void> postWatchHistory({
    required String token,
    required String mediaId,
    required int watchedDuration,
    required int playTime,
    required String profileId,
  }) async {
    final uri = Uri.parse('${AppConstants.userActionsBaseUrl}/watch-history');

    AppLogger.info(_tag, 'POST $uri — media=$mediaId pos=${watchedDuration}s');

    final response = await http
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: json.encode({
            'media_id':        mediaId,
            'watched_duration': watchedDuration,
            'play_time':        playTime,
            'profile_id':       profileId,
          }),
        )
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        _tag,
        'postWatchHistory [${response.statusCode}] media=$mediaId — '
        'body: ${response.body}',
      );
    }
  }

  // ── Clear all ──────────────────────────────────────────────────────────────

  /// DELETE /watch-history/delete/all?watch_type=continue_watch[&profile_id=…]
  ///
  /// iOS contract (ProfileRouter.swift):
  ///   — watch_type=continue_watch is a REQUIRED URL query param
  ///   — NO request body
  ///
  /// [profileId] is appended as a query param when non-empty so the backend
  /// can scope the deletion to the correct profile — matching the same profile
  /// used in fetchWatchHistory.  Cross-platform sync (mobile ↔ web) requires
  /// the DELETE and the subsequent GET to operate on the same profile context.
  Future<void> clearAll({
    required String token,
    String profileId = '',
  }) async {
    final profileParam =
        profileId.isNotEmpty ? '&profile_id=$profileId' : '';

    final uri = Uri.parse(
      '${AppConstants.userActionsBaseUrl}/watch-history/delete/all'
      '?watch_type=continue_watch$profileParam',
    );

    AppLogger.info(
      _tag,
      'clearAll ▶  DELETE $uri\n'
      '  profile_id: ${profileId.isNotEmpty ? profileId : "(empty — backend uses JWT)"}',
    );

    final response = await http
        .delete(
          uri,
          headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        )
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(
      _tag,
      'clearAll ◀  ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'clearAll failed [${response.statusCode}]: ${response.body}',
      );
    }
  }
}
