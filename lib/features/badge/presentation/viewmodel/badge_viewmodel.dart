import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/badge_model.dart';
import '../../domain/repositories/badge_repository.dart';

/// Holds badge data for every channel in the current chapter.
///
/// Call [load] with courseId + chapterId whenever the chapter changes.
/// Idempotent — skips the request if the same params are already loaded.
class BadgeViewModel extends ChangeNotifier {
  static const _tag = 'BadgeViewModel';

  final BadgeRepository _repo;

  BadgeViewModel({required BadgeRepository repository}) : _repo = repository;

  // channelId → ChannelBadgeData
  Map<String, ChannelBadgeData> _data = {};

  String? _lastCourseId;
  String? _lastChapterId;

  /// Returns winning badges for [channelId], or empty list if none.
  List<BadgeInfo> badgesForChannel(String channelId) =>
      _data[channelId]?.badges ?? [];

  /// Returns the mostLovedScore (0–5) for [channelId], or 0.0 if unavailable.
  double ratingForChannel(String channelId) =>
      _data[channelId]?.mostLovedScore ?? 0.0;

  Future<void> load({
    required String courseId,
    required String chapterId,
  }) async {
    if (chapterId.isEmpty) return;
    if (courseId == _lastCourseId && chapterId == _lastChapterId) return;

    _lastCourseId = courseId;
    _lastChapterId = chapterId;

    try {
      final list = await _repo.getChapterBadges(
        courseId: courseId,
        chapterId: chapterId,
      );
      _data = {for (final b in list) b.channelId: b};
      AppLogger.info(_tag, 'Loaded badges for ${list.length} channels');
    } catch (e) {
      // Badge load failures are non-fatal — content still shows without badges.
      AppLogger.warning(_tag, 'Badge load failed (non-fatal): $e');
      _data = {};
    } finally {
      notifyListeners();
    }
  }
}
