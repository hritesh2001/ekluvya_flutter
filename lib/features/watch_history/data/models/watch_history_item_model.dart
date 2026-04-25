import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// One entry from GET /useractions/api/v1/watch-history
class WatchHistoryItemModel {
  const WatchHistoryItemModel({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.thumbnailUrl,
    required this.videoDuration,
    required this.watchedDuration,
  });

  final String id;
  final String mediaId;
  final String title;
  final String thumbnailUrl;
  final int videoDuration;    // seconds
  final int watchedDuration;  // seconds

  WatchHistoryItemModel copyWith({String? thumbnailUrl}) =>
      WatchHistoryItemModel(
        id:              id,
        mediaId:         mediaId,
        title:           title,
        thumbnailUrl:    thumbnailUrl ?? this.thumbnailUrl,
        videoDuration:   videoDuration,
        watchedDuration: watchedDuration,
      );

  // ── Derived ───────────────────────────────────────────────────────────────

  int get remainingSeconds =>
      (videoDuration - watchedDuration).clamp(0, videoDuration);

  double get progressFraction {
    if (videoDuration <= 0) return 0;
    return (watchedDuration / videoDuration).clamp(0.0, 1.0);
  }

  String get remainingLabel {
    final secs = remainingSeconds;
    final m   = secs ~/ 60;
    final sec = secs % 60;
    return '${m.toString().padLeft(2, '0')}m ${sec.toString().padLeft(2, '0')}s left';
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  factory WatchHistoryItemModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) {
      if (v == null) return '';
      final str = v.toString().trim();
      return str == 'null' ? '' : str;
    }

    int i(dynamic v) => v is num ? v.toInt() : (int.tryParse(s(v)) ?? 0);

    // master_details_id holds the video document
    final masterRaw = json['master_details_id'];
    final Map<String, dynamic> master =
        masterRaw is Map<String, dynamic> ? masterRaw : const {};

    // Title: episode name from root, fall back to master title
    final title = s(json['title']).isNotEmpty
        ? s(json['title'])
        : s(master['title']);

    // Thumbnail: master_details_id → new_thumbnail_images → default → tp
    // tp is the portrait-cropped variant used for video cards.
    // Fallback chain: tp → to → tl (all from default format only)
    final thumbnailPath = _pickThumb(master);
    final thumbnailUrl  = thumbnailPath.isEmpty
        ? ''
        : thumbnailPath.startsWith('http')
            ? thumbnailPath
            : '${AppConstants.thumbnailCdnBaseUrl}$thumbnailPath';

    AppLogger.info(
      'WatchHistoryItemModel',
      'id=${s(json["_id"])} thumb=$thumbnailUrl',
    );

    return WatchHistoryItemModel(
      id:              s(json['_id']),
      mediaId:         s(json['media_id'] ?? master['_id']),
      title:           title,
      thumbnailUrl:    thumbnailUrl,
      videoDuration:   i(json['video_duration']),
      watchedDuration: i(json['watched_duration']),
    );
  }

  // Reads new_thumbnail_images.default.{tp,to,tl} from a video document map.
  static String _pickThumb(Map<String, dynamic> doc) {
    try {
      final nt  = doc['new_thumbnail_images'];
      if (nt is! Map) return '';
      final def = nt['default'];
      if (def is! Map) return '';
      for (final key in ['tp', 'to', 'tl']) {
        final url = def[key]?.toString().trim() ?? '';
        if (url.isNotEmpty && url != 'null') return url;
      }
    } catch (_) {}
    return '';
  }
}
