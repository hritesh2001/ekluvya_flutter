import '../../../../core/constants/app_constants.dart';

class BookmarkItemModel {
  const BookmarkItemModel({
    required this.episodeId,
    required this.seasonId,
    required this.title,
    required this.thumbnailUrl,
    required this.isWatchLater,
    required this.monetization,
    required this.isUserSubscribed,
  });

  final String episodeId;
  final String seasonId;
  final String title;
  final String thumbnailUrl;
  final bool isWatchLater;
  final int monetization;
  final bool isUserSubscribed;

  factory BookmarkItemModel.fromJson(Map<String, dynamic> json) {
    return BookmarkItemModel(
      episodeId: json['episode_id']?.toString() ?? '',
      seasonId: json['season_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnailUrl: _extractThumbnail(json),
      isWatchLater:
          json['is_watch_later'] == 1 || json['is_watch_later'] == true,
      monetization: (json['monetization'] as num?)?.toInt() ?? 0,
      isUserSubscribed: json['is_user_subscribed'] == true,
    );
  }

  static String _extractThumbnail(Map<String, dynamic> json) {
    try {
      final newThumb = json['new_thumbnail_images'];
      if (newThumb is Map) {
        final def = newThumb['default'];
        if (def is Map) {
          final to = def['to']?.toString() ?? '';
          if (to.isNotEmpty) return _toAbsoluteUrl(to);
        }
      }
      final thumb = json['thumbnail']?.toString() ?? '';
      if (thumb.isNotEmpty) return _toAbsoluteUrl(thumb);
    } catch (_) {}
    return '';
  }

  static String _toAbsoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${AppConstants.thumbnailCdnBaseUrl}$path';
  }
}
