import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/class_subject_repository.dart';
import '../models/class_model.dart';
import '../models/subject_item_model.dart';
import '../remote/class_subject_api_service.dart';

/// Concrete implementation of [ClassSubjectRepository].
///
/// Adds:
///   - In-memory per-key caching (survives app session, cleared on restart).
///   - Request deduplication: a second call for the same key while the first
///     is in-flight waits for the same [Future] rather than firing a new HTTP
///     request.
///   - Offline detection with graceful stale-cache fallback.
class ClassSubjectRepositoryImpl implements ClassSubjectRepository {
  static const _tag = 'ClassSubjectRepositoryImpl';

  final ClassSubjectApiService _api;

  ClassSubjectRepositoryImpl({required ClassSubjectApiService apiService})
      : _api = apiService;

  // ── Caches ─────────────────────────────────────────────────────────────────

  /// Key: courseId
  final Map<String, List<ClassModel>> _classesCache = {};

  /// Key: '$courseId:$classId'
  final Map<String, List<SubjectItemModel>> _subjectsCache = {};

  // ── In-flight deduplication ────────────────────────────────────────────────

  final Map<String, Future<List<ClassModel>>> _classesFlight = {};
  final Map<String, Future<List<SubjectItemModel>>> _subjectsFlight = {};

  // ── ClassSubjectRepository ─────────────────────────────────────────────────

  @override
  Future<List<ClassModel>> getClasses({required String courseId}) async {
    final isConnected = await ConnectivityService.isConnected();

    if (!isConnected) {
      AppLogger.warning(_tag, 'Offline — checking classes cache for $courseId');
      final cached = _classesCache[courseId];
      if (cached != null) return cached;
      throw const NetworkException();
    }

    // Return in-flight future directly (deduplication)
    if (_classesFlight.containsKey(courseId)) {
      AppLogger.info(_tag, 'Reusing in-flight classes request for $courseId');
      return _classesFlight[courseId]!;
    }

    final future = _api
        .fetchClasses(courseId: courseId)
        .then((classes) {
          _classesCache[courseId] = classes;
          AppLogger.info(
              _tag, 'Cached ${classes.length} classes for course $courseId');
          return classes;
        })
        .catchError((Object e) {
          AppLogger.error(_tag, 'fetchClasses failed for $courseId', e);
          final cached = _classesCache[courseId];
          if (cached != null) {
            AppLogger.info(_tag, 'Returning stale classes cache');
            return cached;
          }
          throw e;
        })
        .whenComplete(() => _classesFlight.remove(courseId));

    _classesFlight[courseId] = future;
    return future;
  }

  @override
  Future<List<SubjectItemModel>> getSubjects({
    required String courseId,
    required String classId,
  }) async {
    final cacheKey = '$courseId:$classId';
    final isConnected = await ConnectivityService.isConnected();

    if (!isConnected) {
      AppLogger.warning(_tag, 'Offline — checking subjects cache for $cacheKey');
      final cached = _subjectsCache[cacheKey];
      if (cached != null) return cached;
      throw const NetworkException();
    }

    if (_subjectsFlight.containsKey(cacheKey)) {
      AppLogger.info(
          _tag, 'Reusing in-flight subjects request for $cacheKey');
      return _subjectsFlight[cacheKey]!;
    }

    final future = _api
        .fetchSubjects(courseId: courseId, classId: classId)
        .then((subjects) {
          _subjectsCache[cacheKey] = subjects;
          AppLogger.info(
              _tag, 'Cached ${subjects.length} subjects for $cacheKey');
          return subjects;
        })
        .catchError((Object e) {
          AppLogger.error(_tag, 'fetchSubjects failed for $cacheKey', e);
          final cached = _subjectsCache[cacheKey];
          if (cached != null) {
            AppLogger.info(_tag, 'Returning stale subjects cache');
            return cached;
          }
          throw e;
        })
        .whenComplete(() => _subjectsFlight.remove(cacheKey));

    _subjectsFlight[cacheKey] = future;
    return future;
  }
}
