import '../../../../core/utils/logger.dart';
import '../../domain/repositories/badge_repository.dart';
import '../models/badge_model.dart';
import '../remote/badge_api_service.dart';

class BadgeRepositoryImpl implements BadgeRepository {
  static const _tag = 'BadgeRepositoryImpl';

  final BadgeApiService _api;

  BadgeRepositoryImpl({required BadgeApiService apiService})
      : _api = apiService;

  final Map<String, List<ChannelBadgeData>> _cache = {};
  final Map<String, Future<List<ChannelBadgeData>>> _inFlight = {};

  @override
  Future<List<ChannelBadgeData>> getChapterBadges({
    required String courseId,
    required String chapterId,
  }) {
    final key = '$courseId:$chapterId';
    if (_inFlight.containsKey(key)) return _inFlight[key]!;
    final future = _fetch(courseId, chapterId, key);
    _inFlight[key] = future;
    return future;
  }

  Future<List<ChannelBadgeData>> _fetch(
      String courseId, String chapterId, String key) async {
    try {
      final data = await _api.fetchChapterBadges(
        courseId: courseId,
        chapterId: chapterId,
      );
      _cache[key] = data;
      AppLogger.info(_tag, 'Fetched badges for $key');
      return data;
    } catch (e) {
      AppLogger.error(_tag, 'Badge fetch failed for $key: $e');
      final cached = _cache[key];
      if (cached != null) return cached;
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }
}
