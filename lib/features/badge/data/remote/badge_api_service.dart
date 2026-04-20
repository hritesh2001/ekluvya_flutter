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
///
/// Response structure (from live API):
///   response.winners.studios[]          — all channels with their scores
///   response.winners.winners.mostLoved   — channelId of the Most Loved winner
///   response.winners.winners.mostWatched — channelId of the Most Watched winner
class BadgeApiService {
  static const _tag = 'BadgeApiService';

  Future<List<ChannelBadgeData>> fetchChapterBadges({
    required String courseId,
    required String chapterId,
  }) async {
    final sb = StringBuffer(
      '${AppConstants.mediaBaseUrl}/badges/chapter-badges?courseId=$courseId',
    );
    if (chapterId.isNotEmpty) sb.write('&chapterId=$chapterId');
    final url = sb.toString();

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

  // ── Parser ────────────────────────────────────────────────────────────────

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

    // ── Navigate to response.winners ─────────────────────────────────────
    final response = decoded['response'];
    if (response is! Map<String, dynamic>) {
      AppLogger.warning(_tag, 'response is not a map');
      return [];
    }

    final winnersObj = response['winners'];
    if (winnersObj is! Map<String, dynamic>) {
      AppLogger.warning(_tag, 'response.winners is not a map');
      return [];
    }

    // ── Studios array ─────────────────────────────────────────────────────
    final studios = winnersObj['studios'];
    if (studios is! List) {
      AppLogger.warning(_tag, 'response.winners.studios is not a list');
      return [];
    }

    // ── Diagnostic: log first studio's ID fields ─────────────────────────
    if (studios.isNotEmpty && studios.first is Map<String, dynamic>) {
      final first = studios.first as Map<String, dynamic>;
      AppLogger.info(
        _tag,
        'Studio[0] id fields → '
        '_id=${first['_id']}  '
        'channelId=${first['channelId']}  '
        'studioId=${first['studioId']}  '
        'studio_id=${first['studio_id']}',
      );
    }

    // ── Definitive winner channel IDs ─────────────────────────────────────
    // response.winners.winners = { mostLoved: "<id>", mostWatched: "<id>" }
    final definitive = winnersObj['winners'];
    String? mostLovedId;
    String? mostWatchedId;
    if (definitive is Map<String, dynamic>) {
      mostLovedId   = definitive['mostLoved']?.toString();
      mostWatchedId = definitive['mostWatched']?.toString();
    }

    AppLogger.info(
      _tag,
      'Definitive winners → mostLoved=$mostLovedId  mostWatched=$mostWatchedId',
    );

    // ── Parse studios ─────────────────────────────────────────────────────
    final all = studios
        .whereType<Map<String, dynamic>>()
        .map(ChannelBadgeData.fromJson)
        .where((b) => b.channelId.isNotEmpty)
        .toList();

    AppLogger.info(
      _tag,
      'Parsed ${all.length} studios:\n'
      '${all.map((b) => '  channelId=${b.channelId}  docId=${b.docId}').join('\n')}',
    );

    // ── Assign badges from response.winners.winners (single source of truth) ──
    //
    // A winner ID is matched against BOTH b.channelId (the channel reference
    // field) AND b.docId (the badge document's own _id). This handles cases
    // where some studios are missing the channelId field and fall back to _id,
    // as well as cases where winners.winners uses a different ID namespace.
    final hasAuthoritativeWinners = mostLovedId != null || mostWatchedId != null;

    return all.map((b) {
      if (!hasAuthoritativeWinners) return b;

      final isLoved = b.channelId == mostLovedId ||
          (b.docId.isNotEmpty && b.docId == mostLovedId);
      final isWatched = b.channelId == mostWatchedId ||
          (b.docId.isNotEmpty && b.docId == mostWatchedId);

      AppLogger.info(
        _tag,
        'Studio ${b.channelId}: isLoved=$isLoved  isWatched=$isWatched',
      );

      final badges = <BadgeInfo>[
        if (isLoved)
          BadgeInfo.synthetic(
            type: 'MOST_LOVED', label: 'Most Loved', score: b.mostLovedScore,
          ),
        if (isWatched)
          BadgeInfo.synthetic(
            type: 'MOST_WATCHED', label: 'Most Watched', score: b.mostWatchedScore,
          ),
      ];

      return b.withBadges(badges);
    }).toList();
  }

  Never _handleError(Object e, StackTrace st) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, 'fetchChapterBadges error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) throw const NetworkException();
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
