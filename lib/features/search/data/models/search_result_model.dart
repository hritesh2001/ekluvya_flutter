import '../../../../core/constants/app_constants.dart';

class SearchResultModel {
  const SearchResultModel({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.slug,
    required this.hlsUrl,
    required this.courseId,
    required this.classId,
    required this.subjectId,
    required this.chapterId,
    required this.monetization,
  });

  final String id;
  final String title;
  final String thumbnailUrl;

  /// Episode slug — used with WatchApiService.fetchEpisode(slug).
  /// Non-empty only when this result is an individual playable episode.
  final String slug;

  /// Direct HLS playlist URL — present when the search index includes it.
  /// Non-empty means this result can be played without a separate fetch.
  final String hlsUrl;

  /// Course / class / subject IDs needed to call ChannelApiService.fetchChannels.
  /// Present when the search result is a series belonging to a known course.
  final String courseId;
  final String classId;
  final String subjectId;
  final String chapterId;

  final int monetization;

  /// Can be played directly — HLS URL is already available.
  bool get hasDirectUrl => hlsUrl.isNotEmpty;

  /// Has enough context to fetch the channel/series video list.
  bool get hasChannelContext => courseId.isNotEmpty;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    // ── Thumbnail ─────────────────────────────────────────────────────────────
    String thumbnailPath = '';
    final thumbImages = json['new_thumbnail_images'];
    if (thumbImages is Map<String, dynamic>) {
      final webp = thumbImages['webp'];
      if (webp is Map<String, dynamic>) {
        thumbnailPath = webp['to']?.toString() ?? '';
      }
      if (thumbnailPath.isEmpty) {
        final def = thumbImages['default'];
        if (def is Map<String, dynamic>) {
          thumbnailPath = def['to']?.toString() ?? '';
        }
      }
    }

    return SearchResultModel(
      id:           json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title:        json['title']?.toString() ?? '',
      thumbnailUrl: _toAbsoluteUrl(thumbnailPath),
      slug:         json['slug']?.toString() ?? '',
      hlsUrl:       json['hls_playlist_url']?.toString() ?? '',
      courseId:     json['course_id']?.toString() ?? '',
      classId:      json['class_id']?.toString() ?? '',
      subjectId:    json['subject_id']?.toString() ?? '',
      chapterId:    json['chapter_id']?.toString() ?? '',
      monetization: (json['monetization'] as num?)?.toInt() ?? 0,
    );
  }

  static String _toAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppConstants.thumbnailCdnBaseUrl;
    if (base.endsWith('/') && path.startsWith('/')) {
      return '$base${path.substring(1)}';
    }
    return '$base$path';
  }
}
