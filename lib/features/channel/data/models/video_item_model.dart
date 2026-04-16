import '../../../../core/constants/app_constants.dart';

/// Immutable model for a single video returned by the channel-list API.
///
/// All fields are non-nullable — the factory guards every value with a
/// null-safe fallback so a malformed JSON item never crashes the app.
class VideoItemModel {
  const VideoItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.hlsUrl,
    required this.durationSeconds,
    required this.viewCount,
    required this.episodeIndex,
    required this.thumbnailUrl,
    required this.slug,
    required this.seriesSlug,
    required this.isSubscription,
    required this.isUserSubscribed,
    required this.isYellowStrip,
    required this.monetization,
  });

  final String id;
  final String title;
  final String description;

  /// HLS playlist URL — ready to pass to a video player.
  final String hlsUrl;

  /// Total video length in seconds (parsed from the API's string field).
  final int durationSeconds;

  final int viewCount;
  final int episodeIndex;

  /// Full CDN URL for the thumbnail image (empty string if unavailable).
  final String thumbnailUrl;

  final String slug;
  final String seriesSlug;
  final bool isSubscription;
  final bool isUserSubscribed;

  /// API marks certain content with a yellow strip highlight.
  final bool isYellowStrip;

  /// Monetization type identifier from the API.
  final int monetization;

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// "m:ss" formatted duration string, e.g. "10:43". Empty if duration ≤ 0.
  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool get hasValidId => id.isNotEmpty;

  // ── Deserialization ───────────────────────────────────────────────────────

  factory VideoItemModel.fromJson(Map<String, dynamic> json) {
    return VideoItemModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      hlsUrl: json['hls_playlist_url']?.toString() ?? '',
      durationSeconds:
          int.tryParse(json['video_duration']?.toString() ?? '0') ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      episodeIndex: (json['episode_index'] as num?)?.toInt() ?? 0,
      thumbnailUrl: _extractThumbnailUrl(json),
      slug: json['slug']?.toString() ?? '',
      seriesSlug: json['seriesSlug']?.toString() ?? '',
      isSubscription: json['is_subscription'] == true,
      isUserSubscribed: json['is_user_subscribed'] == true,
      isYellowStrip: json['is_yellow_strip'] == true,
      monetization: (json['monetization'] as num?)?.toInt() ?? 0,
    );
  }

  /// Resolves the best available thumbnail URL from the API payload.
  ///
  /// Priority order:
  ///   1. `new_thumbnail_images.default.to`  (most recent upload)
  ///   2. `thumbnail_list[0].images.default.to`  (fallback)
  ///
  /// Relative paths are prefixed with [AppConstants.thumbnailCdnBaseUrl].
  /// Any exception during extraction returns an empty string gracefully.
  static String _extractThumbnailUrl(Map<String, dynamic> json) {
    try {
      // 1. new_thumbnail_images
      final newThumb = json['new_thumbnail_images'];
      if (newThumb is Map) {
        final def = newThumb['default'];
        if (def is Map) {
          final to = def['to']?.toString() ?? '';
          if (to.isNotEmpty) return _toAbsoluteUrl(to);
        }
      }

      // 2. thumbnail_list fallback
      final thumbList = json['thumbnail_list'];
      if (thumbList is List && thumbList.isNotEmpty) {
        final first = thumbList.first;
        if (first is Map) {
          final images = first['images'];
          if (images is Map) {
            final def = images['default'];
            if (def is Map) {
              final to = def['to']?.toString() ?? '';
              if (to.isNotEmpty) return _toAbsoluteUrl(to);
            }
          }
        }
      }
    } catch (_) {
      // Never crash — just return empty
    }
    return '';
  }

  static String _toAbsoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${AppConstants.thumbnailCdnBaseUrl}$path';
  }
}
