import '../../../../core/utils/logger.dart';
import '../../domain/repositories/rating_repository.dart';
import '../models/rating_model.dart';
import '../models/video_rating_model.dart';
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

  // ── Video rating ─────────────────────────────────────────────────────────────

  // Per-video cache: invalidated after each successful submission.
  final Map<String, VideoRatingModel> _videoRatingCache = {};

  @override
  Future<VideoRatingModel?> submitVideoRating({
    required String token,
    required String masterDetailsId,
    required int ratingPoints,
  }) async {
    // Intentionally no cache read — submissions always hit the server.
    final result = await _api.submitVideoRating(
      token: token,
      masterDetailsId: masterDetailsId,
      ratingPoints: ratingPoints,
    );
    // Invalidate so the next fetchVideoRating gets fresh data.
    _videoRatingCache.remove(masterDetailsId);
    AppLogger.info(_tag, 'submitVideoRating ok: id=$masterDetailsId pts=$ratingPoints');
    return result;
    // Throws propagate to ViewModel so it can revert the optimistic update.
  }

  @override
  Future<VideoRatingModel?> fetchVideoRating({
    required String masterDetailsId,
    String token = '',
  }) async {
    final cached = _videoRatingCache[masterDetailsId];
    if (cached != null) return cached;
    try {
      final result = await _api.fetchVideoRating(
        masterDetailsId: masterDetailsId,
        token: token,
      );
      if (result != null) _videoRatingCache[masterDetailsId] = result;
      return result;
    } catch (e) {
      AppLogger.warning(_tag, 'fetchVideoRating repo failed: $e');
      return null;
    }
  }
}
