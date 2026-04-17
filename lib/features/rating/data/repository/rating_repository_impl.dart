import '../../../../core/utils/logger.dart';
import '../../domain/repositories/rating_repository.dart';
import '../models/rating_model.dart';
import '../remote/rating_api_service.dart';

class RatingRepositoryImpl implements RatingRepository {
  static const _tag = 'RatingRepositoryImpl';

  final RatingApiService _api;

  RatingRepositoryImpl({required RatingApiService apiService})
      : _api = apiService;

  final Map<String, List<ChannelRatingModel>> _cache = {};
  final Map<String, Future<List<ChannelRatingModel>>> _inFlight = {};

  @override
  Future<List<ChannelRatingModel>> getChannelRatings({
    required String courseId,
    required String classId,
    required String subjectId,
    required String chapterId,
  }) {
    final key = '$courseId:$classId:$subjectId:$chapterId';
    if (_inFlight.containsKey(key)) return _inFlight[key]!;
    final future = _fetch(courseId, classId, subjectId, chapterId, key);
    _inFlight[key] = future;
    return future;
  }

  Future<List<ChannelRatingModel>> _fetch(
    String courseId,
    String classId,
    String subjectId,
    String chapterId,
    String key,
  ) async {
    try {
      final data = await _api.fetchChannelRatings(
        courseId: courseId,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
      );
      _cache[key] = data;
      AppLogger.info(_tag, 'Fetched ratings for $key');
      return data;
    } catch (e) {
      AppLogger.error(_tag, 'Rating fetch failed for $key: $e');
      final cached = _cache[key];
      if (cached != null) return cached;
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }
}
