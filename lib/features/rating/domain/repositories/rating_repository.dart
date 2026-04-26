import '../../data/models/rating_model.dart';
import '../../data/models/video_rating_model.dart';

abstract class RatingRepository {
  Future<List<ChannelRatingModel>> getChannelRatings({
    required String courseId,
    required String classId,
    required String subjectId,
    required String chapterId,
  });

  /// Submits a 1–5 star rating for a video.
  /// Throws on network / auth failure so the caller can revert optimistic UI.
  Future<VideoRatingModel?> submitVideoRating({
    required String token,
    required String masterDetailsId,
    required int ratingPoints,
  });

  /// Fetches the community average + the user's own vote.
  /// Returns null on failure (non-fatal).
  Future<VideoRatingModel?> fetchVideoRating({
    required String masterDetailsId,
    String token = '',
  });
}
