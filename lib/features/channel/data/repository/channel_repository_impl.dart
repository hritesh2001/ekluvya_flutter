import '../../../../core/utils/logger.dart';
import '../../domain/repositories/channel_repository.dart';
import '../models/channel_model.dart';
import '../remote/channel_api_service.dart';

/// Concrete implementation of [ChannelRepository].
///
/// Strategies:
///   • In-memory cache keyed by "courseId:classId:subjectId:chapterId".
///   • In-flight deduplication — concurrent calls with identical params share
///     a single HTTP request rather than issuing duplicates.
///   • Stale-cache fallback — a network/server failure returns cached data
///     when available, so the UI never goes blank for returning users.
class ChannelRepositoryImpl implements ChannelRepository {
  static const _tag = 'ChannelRepositoryImpl';

  final ChannelApiService _api;

  ChannelRepositoryImpl({required ChannelApiService apiService})
      : _api = apiService;

  final Map<String, List<ChannelModel>> _cache = {};
  final Map<String, Future<List<ChannelModel>>> _inFlight = {};

  @override
  Future<List<ChannelModel>> getChannels({
    required String courseId,
    required String classId,
    required String subjectId,
    String chapterId = '',
    String? token,
  }) {
    final key = '$courseId:$classId:$subjectId:$chapterId';

    // Return existing in-flight request if one is already running.
    if (_inFlight.containsKey(key)) {
      AppLogger.info(_tag, 'Joining in-flight request for $key');
      return _inFlight[key]!;
    }

    final future = _fetch(courseId, classId, subjectId, chapterId, key, token);
    _inFlight[key] = future;
    return future;
  }

  Future<List<ChannelModel>> _fetch(
    String courseId,
    String classId,
    String subjectId,
    String chapterId,
    String key,
    String? token,
  ) async {
    try {
      final channels = await _api.fetchChannels(
        courseId: courseId,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        token: token,
      );
      _cache[key] = channels;
      AppLogger.info(_tag, 'Fetched ${channels.length} channels for $key');
      return channels;
    } catch (e) {
      AppLogger.error(_tag, 'Fetch failed for $key: $e');
      final cached = _cache[key];
      if (cached != null) {
        AppLogger.info(_tag, 'Serving stale cache (${cached.length} channels)');
        return cached;
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }
}
