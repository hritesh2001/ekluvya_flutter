import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../models/watch_progress_model.dart';

/// Persists and retrieves per-video watch progress using SharedPreferences.
///
/// Key format: `_kPrefix + videoId`
///
/// Progress is saved every [saveIntervalSeconds] during playback and on
/// dispose, so the user can resume from the correct position on re-open.
class WatchProgressService {
  static const _tag         = 'WatchProgressService';
  static const _kPrefix     = 'watch_progress_';
  static const _kThumbPrefix = 'watch_thumb_';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the saved progress for [videoId], or null if none found.
  Future<WatchProgressModel?> getProgress(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefix + videoId);
      if (raw == null) return null;
      return WatchProgressModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.warning(_tag, 'getProgress failed for $videoId: $e');
      return null;
    }
  }

  /// Saves the current playback position.
  ///
  /// [positionSeconds] and [durationSeconds] are both required so completion
  /// percentage can be computed without an additional API call on next open.
  Future<void> saveProgress({
    required String videoId,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (videoId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final model = WatchProgressModel(
        videoId: videoId,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        lastWatchedAt: DateTime.now(),
      );
      await prefs.setString(_kPrefix + videoId, jsonEncode(model.toJson()));
      AppLogger.info(
        _tag,
        'Saved progress: $videoId → ${positionSeconds}s '
        '/ ${durationSeconds}s (${model.completionPercent.toStringAsFixed(1)}%)',
      );
    } catch (e) {
      AppLogger.warning(_tag, 'saveProgress failed for $videoId: $e');
    }
  }

  /// Clears saved progress (e.g. after user explicitly restarts a video).
  Future<void> clearProgress(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefix + videoId);
    } catch (e) {
      AppLogger.warning(_tag, 'clearProgress failed for $videoId: $e');
    }
  }

  /// Caches the episode thumbnail URL keyed by [videoId].
  /// Called at playback start so the watch history screen can show the correct
  /// episode thumbnail instead of the series thumbnail from master_details_id.
  Future<void> saveThumbnail({
    required String videoId,
    required String thumbnailUrl,
  }) async {
    if (videoId.isEmpty || thumbnailUrl.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThumbPrefix + videoId, thumbnailUrl);
    } catch (e) {
      AppLogger.warning(_tag, 'saveThumbnail failed for $videoId: $e');
    }
  }

  /// Returns the cached episode thumbnail URL for [videoId], or null.
  Future<String?> getThumbnail(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kThumbPrefix + videoId);
    } catch (e) {
      AppLogger.warning(_tag, 'getThumbnail failed for $videoId: $e');
      return null;
    }
  }
}
