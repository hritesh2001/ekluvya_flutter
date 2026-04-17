import '../../data/models/rating_model.dart';

abstract class RatingRepository {
  Future<List<ChannelRatingModel>> getChannelRatings({
    required String courseId,
    required String classId,
    required String subjectId,
    required String chapterId,
  });
}
