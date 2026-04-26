/// Rating data returned by the video rating APIs.
///
/// Covers both:
///   POST /ratings/create  → submission confirmation
///   GET  /ratings/overall/{id} → community stats + user's own vote
class VideoRatingModel {
  final double userRating;    // user's own vote (0 = not yet rated)
  final double overallRating; // community average (0–5)
  final int totalRatings;     // total vote count

  const VideoRatingModel({
    required this.userRating,
    required this.overallRating,
    required this.totalRatings,
  });

  bool get hasOverallRating => overallRating > 0 && totalRatings > 0;
  bool get hasUserRating    => userRating > 0;

  /// "1.2K" or "24" — compact count label for the UI.
  String get formattedTotal {
    if (totalRatings >= 1000) {
      return '${(totalRatings / 1000).toStringAsFixed(1)}K';
    }
    return totalRatings.toString();
  }

  factory VideoRatingModel.fromJson(Map<String, dynamic> json) {
    // Both endpoints wrap their data in a 'response' key.
    final data = json['response'] is Map<String, dynamic>
        ? json['response'] as Map<String, dynamic>
        : json;

    // user_rating: the authenticated user's own rating points
    final userRaw =
        data['user_rating'] ?? data['rating_points'] ?? data['userRating'];
    // overall: community average — field name differs between endpoints
    final overallRaw = data['overall_rating'] ??
        data['average_rating'] ??
        data['averageRating'] ??
        data['avg_rating'];
    // total count
    final totalRaw = data['total_ratings'] ??
        data['total_reviews'] ??
        data['totalRatings'] ??
        data['count'];

    return VideoRatingModel(
      userRating:    (userRaw    as num?)?.toDouble() ?? 0,
      overallRating: (overallRaw as num?)?.toDouble() ?? 0,
      totalRatings:  (totalRaw   as num?)?.toInt()    ?? 0,
    );
  }
}
