import '../../../../core/utils/logger.dart';
import '../../domain/repositories/class_subject_repository.dart';
import '../models/chapter_model.dart';
import '../models/class_model.dart';
import '../models/subject_item_model.dart';
import '../remote/class_subject_api_service.dart';

class ClassSubjectRepositoryImpl implements ClassSubjectRepository {
  static const _tag = 'ClassSubjectRepositoryImpl';

  final ClassSubjectApiService _api;

  ClassSubjectRepositoryImpl({required ClassSubjectApiService apiService})
      : _api = apiService;

  final Map<String, List<ClassModel>> _classesCache = {};
  final Map<String, List<SubjectItemModel>> _subjectsCache = {};
  final Map<String, List<ChapterModel>> _chaptersCache = {};

  final Map<String, Future<List<ClassModel>>> _classesFlight = {};
  final Map<String, Future<List<SubjectItemModel>>> _subjectsFlight = {};
  final Map<String, Future<List<ChapterModel>>> _chaptersFlight = {};

  @override
  Future<List<ClassModel>> getClasses({required String courseId}) {
    if (_classesFlight.containsKey(courseId)) {
      return _classesFlight[courseId]!;
    }
    final future = _fetchClasses(courseId);
    _classesFlight[courseId] = future;
    return future;
  }

  Future<List<ClassModel>> _fetchClasses(String courseId) async {
    try {
      final classes = await _api.fetchClasses(courseId: courseId);
      _classesCache[courseId] = classes;
      AppLogger.info(_tag, 'Fetched ${classes.length} classes for $courseId');
      return classes;
    } catch (e) {
      AppLogger.error(_tag, 'fetchClasses failed for $courseId: $e');
      final cached = _classesCache[courseId];
      if (cached != null) {
        AppLogger.info(_tag, 'Returning stale classes cache');
        return cached;
      }
      rethrow;
    } finally {
      _classesFlight.remove(courseId);
    }
  }

  @override
  Future<List<SubjectItemModel>> getSubjects({
    required String courseId,
    required String classId,
  }) {
    final key = '$courseId:$classId';
    if (_subjectsFlight.containsKey(key)) {
      return _subjectsFlight[key]!;
    }
    final future = _fetchSubjects(courseId, classId, key);
    _subjectsFlight[key] = future;
    return future;
  }

  Future<List<SubjectItemModel>> _fetchSubjects(
      String courseId, String classId, String key) async {
    try {
      final subjects =
          await _api.fetchSubjects(courseId: courseId, classId: classId);
      _subjectsCache[key] = subjects;
      AppLogger.info(_tag, 'Fetched ${subjects.length} subjects for $key');
      return subjects;
    } catch (e) {
      AppLogger.error(_tag, 'fetchSubjects failed for $key: $e');
      final cached = _subjectsCache[key];
      if (cached != null) {
        AppLogger.info(_tag, 'Returning stale subjects cache');
        return cached;
      }
      rethrow;
    } finally {
      _subjectsFlight.remove(key);
    }
  }

  @override
  Future<List<ChapterModel>> getChapters({
    required String courseId,
    required String classId,
    required String subjectId,
  }) {
    final key = '$courseId:$classId:$subjectId';
    if (_chaptersFlight.containsKey(key)) return _chaptersFlight[key]!;
    final future = _fetchChapters(courseId, classId, subjectId, key);
    _chaptersFlight[key] = future;
    return future;
  }

  Future<List<ChapterModel>> _fetchChapters(
      String courseId, String classId, String subjectId, String key) async {
    try {
      final chapters = await _api.fetchChapters(
        courseId: courseId,
        classId: classId,
        subjectId: subjectId,
      );
      _chaptersCache[key] = chapters;
      AppLogger.info(_tag, 'Fetched ${chapters.length} chapters for $key');
      return chapters;
    } catch (e) {
      AppLogger.error(_tag, 'fetchChapters failed for $key: $e');
      final cached = _chaptersCache[key];
      if (cached != null) {
        AppLogger.info(_tag, 'Returning stale chapters cache');
        return cached;
      }
      rethrow;
    } finally {
      _chaptersFlight.remove(key);
    }
  }
}
