/// A single badge awarded to a channel for a chapter.
class BadgeInfo {
  final String type;  // MOST_LOVED | MOST_WATCHED
  final String label; // "Most Loved" | "Most Watched"
  final double score;
  final bool isWinner;

  const BadgeInfo({
    required this.type,
    required this.label,
    required this.score,
    required this.isWinner,
  });

  bool get isMostLoved => type == 'MOST_LOVED';
  bool get isMostWatched => type == 'MOST_WATCHED';

  /// Asset path for the badge icon.
  String get assetPath => isMostLoved
      ? 'assets/icons/mostloved.png'
      : 'assets/icons/mostwatched.png';

  factory BadgeInfo.fromJson(Map<String, dynamic> json) => BadgeInfo(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
        isWinner: json['isWinner'] == true,
      );
}

/// Badge data for a single channel returned by the chapter-badges API.
class ChannelBadgeData {
  final String channelId;
  final double mostWatchedScore;
  final double mostLovedScore;

  /// Only winner badges (isWinner == true) are included.
  final List<BadgeInfo> badges;

  const ChannelBadgeData({
    required this.channelId,
    required this.mostWatchedScore,
    required this.mostLovedScore,
    required this.badges,
  });

  bool get hasBadges => badges.isNotEmpty;

  factory ChannelBadgeData.fromJson(Map<String, dynamic> json) {
    final rawBadges = json['badges'];
    final badges = rawBadges is List
        ? rawBadges
            .whereType<Map<String, dynamic>>()
            .map(BadgeInfo.fromJson)
            .where((b) => b.type.isNotEmpty && b.isWinner)
            .toList()
        : <BadgeInfo>[];

    return ChannelBadgeData(
      channelId: json['channelId']?.toString() ?? '',
      mostWatchedScore:
          (json['mostWatchedScore'] as num?)?.toDouble() ?? 0,
      mostLovedScore:
          (json['mostLovedScore'] as num?)?.toDouble() ?? 0,
      badges: badges,
    );
  }
}
