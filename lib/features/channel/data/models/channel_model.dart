import 'video_item_model.dart';

/// Immutable model for a content partner / channel returned by channel-list API.
///
/// Each channel contains a paginated list of its videos ([videos])
/// plus metadata about the total available ([totalVideos]).
class ChannelModel {
  const ChannelModel({
    required this.id,
    required this.title,
    required this.type,
    required this.rowCount,
    required this.totalVideos,
    required this.videos,
  });

  final String id;

  /// Display name of the partner/channel, e.g. "Ekluvya", "Tutorac".
  final String title;

  /// Channel type from the API (1 = standard, etc.).
  final int type;

  /// row_count from the API — used for layout hints.
  final int rowCount;

  /// Total number of videos available for this channel (may exceed [videos.length]
  /// when the response is paginated via inside_limit).
  final int totalVideos;

  /// Videos included in this response page (up to inside_limit items).
  final List<VideoItemModel> videos;

  bool get isEmpty => videos.isEmpty;
  bool get isNotEmpty => videos.isNotEmpty;
  bool get hasValidId => id.isNotEmpty;

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final videos = rawData is List
        ? rawData
            .whereType<Map<String, dynamic>>()
            .map(VideoItemModel.fromJson)
            .where((v) => v.hasValidId)
            .toList()
        : <VideoItemModel>[];

    // total / count — API returns different keys; take whichever is present.
    final totalVideos = (json['total'] as num?)?.toInt() ??
        (json['count'] as num?)?.toInt() ??
        videos.length;

    return ChannelModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: (json['type'] as num?)?.toInt() ?? 0,
      rowCount: (json['row_count'] as num?)?.toInt() ?? 0,
      totalVideos: totalVideos,
      videos: videos,
    );
  }
}
