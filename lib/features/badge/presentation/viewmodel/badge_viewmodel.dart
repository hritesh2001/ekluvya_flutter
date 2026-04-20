import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/badge_model.dart';
import '../../domain/repositories/badge_repository.dart';

/// Holds badge data for every channel in the current chapter.
///
/// Call [load] with courseId + chapterId whenever the chapter changes.
/// Guarantees:
///   • Stale badges are cleared the moment new params arrive (no ghost icons).
///   • Race conditions are guarded — a slow response from an old chapter
///     cannot overwrite a newer load's result.
///   • Multi-key indexing — each studio is indexed by both its channelId
///     (the channel reference field) and its docId (the badge document's own
///     _id), so badgesForChannel(ch.id) succeeds regardless of which ID
///     namespace the channel API and badge API share.
class BadgeViewModel extends ChangeNotifier {
  static const _tag = 'BadgeViewModel';

  final BadgeRepository _repo;

  BadgeViewModel({required BadgeRepository repository}) : _repo = repository;

  // Multi-key map: both channelId and docId point to the same ChannelBadgeData.
  // This ensures badgesForChannel(ch.id) succeeds even when the channel API's
  // _id field and the badge API's channelId field have naming inconsistencies.
  Map<String, ChannelBadgeData> _data = {};

  String? _lastCourseId;
  String? _lastChapterId;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns winning badges for [channelId], or empty list if none.
  List<BadgeInfo> badgesForChannel(String channelId) {
    final result = _data[channelId]?.badges ?? [];
    AppLogger.info(
      _tag,
      'badgesForChannel($channelId) → '
      '${result.isEmpty ? "[]" : result.map((b) => b.type).join(", ")}  '
      '(data keys: ${_data.keys.take(6).join(", ")}${_data.length > 6 ? "…" : ""})',
    );
    return result;
  }

  /// Returns the mostLovedScore (0–5) for [channelId], or 0.0 if unavailable.
  double lovedScoreForChannel(String channelId) =>
      _data[channelId]?.mostLovedScore ?? 0.0;

  /// Loads badges for the given course + chapter.
  ///
  /// No-op when called with identical params (idempotent).
  /// Clears stale data immediately on param change so the UI never shows
  /// badges from a previous chapter while the new request is in-flight.
  Future<void> load({
    required String courseId,
    required String chapterId,
  }) async {
    if (courseId.isEmpty) return;

    if (courseId == _lastCourseId && chapterId == _lastChapterId) return;

    _lastCourseId  = courseId;
    _lastChapterId = chapterId;

    _data = {};
    notifyListeners();

    try {
      final list = await _repo.getChapterBadges(
        courseId:  courseId,
        chapterId: chapterId,
      );

      if (courseId != _lastCourseId || chapterId != _lastChapterId) {
        AppLogger.info(_tag, 'Discarding stale badge response for $courseId:$chapterId');
        return;
      }

      // Build a multi-key index: each studio is reachable by channelId AND
      // docId. This makes badgesForChannel(ch.id) resilient to ID field
      // variations between the channel API and the badge API.
      final map = <String, ChannelBadgeData>{};
      for (final b in list) {
        for (final id in b.allIds) {
          map[id] = b;
        }
      }
      _data = map;

      final winners = list.where((b) => b.hasBadges).toList();
      AppLogger.info(
        _tag,
        'Loaded ${list.length} studios, ${winners.length} winner(s):\n'
        '${winners.map((b) => '  ${b.channelId} → [${b.badges.map((x) => x.type).join(",")}]').join("\n")}\n'
        'Index keys: ${_data.keys.join(", ")}',
      );
    } catch (e) {
      if (courseId != _lastCourseId || chapterId != _lastChapterId) return;
      AppLogger.warning(_tag, 'Badge load failed (non-fatal): $e');
      _data = {};
    } finally {
      if (courseId == _lastCourseId && chapterId == _lastChapterId) {
        notifyListeners();
      }
    }
  }
}
