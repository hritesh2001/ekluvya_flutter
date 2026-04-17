/// Per-channel rating returned by the chapter channel-ratings API.
class ChannelRatingModel {
  final String channelId;
  final double averageRating;
  final int totalRatings;

  const ChannelRatingModel({
    required this.channelId,
    required this.averageRating,
    required this.totalRatings,
  });

  bool get hasRating => averageRating > 0;

  factory ChannelRatingModel.fromJson(Map<String, dynamic> json) =>
      ChannelRatingModel(
        channelId: json['channelId']?.toString() ?? '',
        averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
        totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      );
}
