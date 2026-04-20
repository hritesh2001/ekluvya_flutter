/// A single badge awarded to a channel for a chapter.
class BadgeInfo {
  final String type;   // MOST_LOVED | MOST_WATCHED
  final String label;  // "Most Loved" | "Most Watched"
  final double score;
  final bool isWinner;

  const BadgeInfo({
    required this.type,
    required this.label,
    required this.score,
    required this.isWinner,
  });

  bool get isMostLoved   => type == 'MOST_LOVED';
  bool get isMostWatched => type == 'MOST_WATCHED';

  String get assetPath => isMostLoved
      ? 'assets/icons/mostloved.png'
      : 'assets/icons/mostwatched.png';

  factory BadgeInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['isWinner'];
    final isWinner = raw == true ||
        raw == 1 ||
        raw?.toString().toLowerCase() == 'true';

    return BadgeInfo(
      type:     json['type']?.toString() ?? '',
      label:    json['label']?.toString() ?? '',
      score:    (json['score'] as num?)?.toDouble() ?? 0,
      isWinner: isWinner,
    );
  }

  factory BadgeInfo.synthetic({
    required String type,
    required String label,
    required double score,
  }) =>
      BadgeInfo(type: type, label: label, score: score, isWinner: true);
}

/// Badge data for a single channel returned by the chapter-badges API.
///
/// [channelId] is the canonical reference ID — the value the badge API stores
/// in its `channelId` field to point at the channel. When absent, we fall back
/// to [docId] (the badge document's own `_id`), but that value may not match
/// the channel API's `_id`.
///
/// [docId] is the badge document's own MongoDB `_id` and is kept as an
/// alternate lookup key so that [BadgeViewModel] can index by both values,
/// making the badge system resilient to per-studio field variations.
class ChannelBadgeData {
  final String channelId;
  final String docId;
  final double mostWatchedScore;
  final double mostLovedScore;

  /// Winner badges — empty means this channel is not a winner.
  final List<BadgeInfo> badges;

  const ChannelBadgeData({
    required this.channelId,
    required this.docId,
    required this.mostWatchedScore,
    required this.mostLovedScore,
    required this.badges,
  });

  bool get hasBadges => badges.isNotEmpty;

  /// All distinct, non-empty IDs this studio is known by.
  /// Used by [BadgeViewModel] to build a multi-key lookup map.
  List<String> get allIds {
    if (docId.isEmpty || docId == channelId) return [channelId];
    return [channelId, docId];
  }

  /// Creates a copy with a replacement badges list.
  ChannelBadgeData withBadges(List<BadgeInfo> b) => ChannelBadgeData(
        channelId:        channelId,
        docId:            docId,
        mostLovedScore:   mostLovedScore,
        mostWatchedScore: mostWatchedScore,
        badges:           b,
      );

  factory ChannelBadgeData.fromJson(Map<String, dynamic> json) {
    // docId = the badge document's own _id (may differ from channel _id).
    final docId = json['_id']?.toString() ?? '';

    // channelId = the reference to the channel (foreign key to channel's _id).
    // Prefer channelId/studioId over _id because those are explicit channel
    // references. Fall back to _id only when no reference field exists.
    final channelId =
        json['channelId']?.toString().trim().isNotEmpty == true
            ? json['channelId'].toString()
            : json['studioId']?.toString().trim().isNotEmpty == true
                ? json['studioId'].toString()
                : json['studio_id']?.toString().trim().isNotEmpty == true
                    ? json['studio_id'].toString()
                    : docId; // last resort

    final mostLovedScore   = (json['mostLovedScore']   as num?)?.toDouble() ?? 0.0;
    final mostWatchedScore = (json['mostWatchedScore'] as num?)?.toDouble() ?? 0.0;

    final rawBadges = json['badges'];
    final badges = rawBadges is List
        ? rawBadges
            .whereType<Map<String, dynamic>>()
            .map(BadgeInfo.fromJson)
            .where((b) => b.type.isNotEmpty && b.isWinner)
            .toList()
        : <BadgeInfo>[];

    return ChannelBadgeData(
      channelId:       channelId,
      docId:           docId,
      mostLovedScore:  mostLovedScore,
      mostWatchedScore: mostWatchedScore,
      badges:          badges,
    );
  }
}
