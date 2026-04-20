/// Persisted watch-progress record for a single video.
class WatchProgressModel {
  const WatchProgressModel({
    required this.videoId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatchedAt,
  });

  final String videoId;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime lastWatchedAt;

  /// 0–100 completion percentage.
  double get completionPercent {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds * 100).clamp(0.0, 100.0);
  }

  bool get isCompleted => completionPercent >= 90;

  /// Seconds remaining before the video ends.
  int get remainingSeconds => (durationSeconds - positionSeconds).clamp(0, durationSeconds);

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
      };

  factory WatchProgressModel.fromJson(Map<String, dynamic> json) =>
      WatchProgressModel(
        videoId: json['videoId'] as String,
        positionSeconds: json['positionSeconds'] as int,
        durationSeconds: json['durationSeconds'] as int,
        lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
      );
}
