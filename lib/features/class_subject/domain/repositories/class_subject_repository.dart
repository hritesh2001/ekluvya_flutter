import '../../data/models/chapter_model.dart';
import '../../data/models/class_model.dart';
import '../../data/models/subject_item_model.dart';

/// Domain contract for classes + subjects + chapters data access.
/// The ViewModel depends on this abstraction only — never on the concrete impl.
abstract class ClassSubjectRepository {
  /// Returns the list of classes available for [courseId].
  Future<List<ClassModel>> getClasses({required String courseId});

  /// Returns subjects for the given [courseId] + [classId] pair.
  Future<List<SubjectItemModel>> getSubjects({
    required String courseId,
    required String classId,
  });

  /// Returns chapters for the given [courseId] + [classId] + [subjectId].
  Future<List<ChapterModel>> getChapters({
    required String courseId,
    required String classId,
    required String subjectId,
  });
}
