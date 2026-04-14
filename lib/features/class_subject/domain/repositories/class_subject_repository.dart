import '../../data/models/class_model.dart';
import '../../data/models/subject_item_model.dart';

/// Domain contract for classes + subjects data access.
/// The ViewModel depends on this abstraction only — never on the concrete impl.
abstract class ClassSubjectRepository {
  /// Returns the list of classes available for [courseId].
  ///
  /// - Offline + cache hit  → returns cached list.
  /// - Offline + no cache   → throws [NetworkException].
  /// - API failure + cache  → returns stale cache.
  /// - API failure + no cache → rethrows [AppException].
  Future<List<ClassModel>> getClasses({required String courseId});

  /// Returns subjects for the given [courseId] + [classId] pair.
  ///
  /// Same offline / cache contract as [getClasses].
  Future<List<SubjectItemModel>> getSubjects({
    required String courseId,
    required String classId,
  });
}
