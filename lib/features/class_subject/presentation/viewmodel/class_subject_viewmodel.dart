import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/chapter_model.dart';
import '../../data/models/class_model.dart';
import '../../data/models/subject_item_model.dart';
import '../../domain/repositories/class_subject_repository.dart';

enum ClassSubjectLoadState { initial, loading, loaded, error }

/// Manages classes + subjects + chapters state for a single course detail screen.
///
/// Lifecycle:
///   1. Call [initialize] once (done automatically by [CourseDetailScreen]).
///   2. [initialize] loads classes → selects the first → loads subjects.
///   3. Subjects load → auto-selects first → loads chapters for that subject.
///   4. [selectClass] switches the active class and reloads subjects.
///   5. [selectSubject] updates the active subject and reloads chapters.
///   6. [selectChapter] updates the active chapter (triggers channel reload in UI).
class ClassSubjectViewModel extends ChangeNotifier {
  static const _tag = 'ClassSubjectViewModel';

  final ClassSubjectRepository _repository;

  final String courseId;
  final String courseTitle;

  ClassSubjectViewModel({
    required ClassSubjectRepository repository,
    required this.courseId,
    required this.courseTitle,
  }) : _repository = repository;

  // ── Classes state ──────────────────────────────────────────────────────────

  ClassSubjectLoadState _classesState = ClassSubjectLoadState.initial;
  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  String? _classesError;

  ClassSubjectLoadState get classesState => _classesState;
  List<ClassModel> get classes => List.unmodifiable(_classes);
  ClassModel? get selectedClass => _selectedClass;
  String? get classesError => _classesError;

  bool get classesLoading => _classesState == ClassSubjectLoadState.loading;
  bool get classesHasData =>
      _classesState == ClassSubjectLoadState.loaded && _classes.isNotEmpty;
  bool get classesHasError => _classesState == ClassSubjectLoadState.error;

  // ── Subjects state ─────────────────────────────────────────────────────────

  ClassSubjectLoadState _subjectsState = ClassSubjectLoadState.initial;
  List<SubjectItemModel> _subjects = [];
  SubjectItemModel? _selectedSubject;
  String? _subjectsError;

  ClassSubjectLoadState get subjectsState => _subjectsState;
  List<SubjectItemModel> get subjects => List.unmodifiable(_subjects);
  SubjectItemModel? get selectedSubject => _selectedSubject;
  String? get subjectsError => _subjectsError;

  bool get subjectsLoading => _subjectsState == ClassSubjectLoadState.loading;
  bool get subjectsHasData =>
      _subjectsState == ClassSubjectLoadState.loaded && _subjects.isNotEmpty;
  bool get subjectsHasError => _subjectsState == ClassSubjectLoadState.error;

  // ── Chapters state ─────────────────────────────────────────────────────────

  ClassSubjectLoadState _chaptersState = ClassSubjectLoadState.initial;
  List<ChapterModel> _chapters = [];
  ChapterModel? _selectedChapter;
  String? _chaptersError;

  ClassSubjectLoadState get chaptersState => _chaptersState;
  List<ChapterModel> get chapters => List.unmodifiable(_chapters);
  ChapterModel? get selectedChapter => _selectedChapter;
  String? get chaptersError => _chaptersError;

  bool get chaptersLoading => _chaptersState == ClassSubjectLoadState.loading;
  bool get chaptersHasData =>
      _chaptersState == ClassSubjectLoadState.loaded && _chapters.isNotEmpty;
  bool get chaptersHasError => _chaptersState == ClassSubjectLoadState.error;

  // ── Actions ────────────────────────────────────────────────────────────────

  void initialize() {
    if (_classesState != ClassSubjectLoadState.initial) return;
    _loadClasses();
  }

  void selectClass(ClassModel cls) {
    if (_selectedClass?.id == cls.id) return;
    _selectedClass = cls;
    _selectedSubject = null;
    _subjects = [];
    _subjectsState = ClassSubjectLoadState.initial;
    _selectedChapter = null;
    _chapters = [];
    _chaptersState = ClassSubjectLoadState.initial;
    notifyListeners();
    _loadSubjects(cls);
  }

  void selectSubject(SubjectItemModel? subject) {
    if (_selectedSubject?.id == subject?.id) return;
    _selectedSubject = subject;
    _selectedChapter = null;
    _chapters = [];
    _chaptersState = ClassSubjectLoadState.initial;
    notifyListeners();
    final cls = _selectedClass;
    if (subject != null && cls != null) {
      _loadChapters(cls, subject);
    }
  }

  void selectChapter(ChapterModel chapter) {
    if (_selectedChapter?.id == chapter.id) return;
    _selectedChapter = chapter;
    notifyListeners();
  }

  void retryClasses() {
    _classesState = ClassSubjectLoadState.initial;
    _classesError = null;
    _loadClasses();
  }

  void retrySubjects() {
    final cls = _selectedClass;
    if (cls == null) return;
    _subjectsState = ClassSubjectLoadState.initial;
    _subjectsError = null;
    _loadSubjects(cls);
  }

  void retryChapters() {
    final cls = _selectedClass;
    final subject = _selectedSubject;
    if (cls == null || subject == null) return;
    _chaptersState = ClassSubjectLoadState.initial;
    _chaptersError = null;
    _loadChapters(cls, subject);
  }

  // ── Private loaders ────────────────────────────────────────────────────────

  Future<void> _loadClasses() async {
    if (_classesState == ClassSubjectLoadState.loading) return;

    _classesState = ClassSubjectLoadState.loading;
    _classesError = null;
    notifyListeners();

    try {
      final classes = await _repository.getClasses(courseId: courseId);
      _classes = classes;
      _classesState = ClassSubjectLoadState.loaded;
      AppLogger.info(_tag, 'Loaded ${classes.length} classes for $courseId');

      if (_selectedClass == null ||
          !_classes.any((c) => c.id == _selectedClass!.id)) {
        _selectedClass = _classes.isNotEmpty ? _classes.first : null;
      }

      notifyListeners();

      if (_selectedClass != null) {
        _loadSubjects(_selectedClass!);
      }
    } on NetworkException catch (e) {
      _classesError = e.message;
      _classesState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Network error loading classes: $e');
      notifyListeners();
    } on RequestTimeoutException catch (e) {
      _classesError = e.message;
      _classesState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Timeout loading classes: $e');
      notifyListeners();
    } on ServerException catch (e) {
      _classesError = e.message;
      _classesState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Server error loading classes: $e');
      notifyListeners();
    } catch (e, st) {
      _classesError = 'Something went wrong. Please try again.';
      _classesState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Unexpected error loading classes', e, st);
      notifyListeners();
    }
  }

  Future<void> _loadSubjects(ClassModel cls) async {
    if (_subjectsState == ClassSubjectLoadState.loading) return;

    _subjectsState = ClassSubjectLoadState.loading;
    _subjectsError = null;
    notifyListeners();

    try {
      final subjects = await _repository.getSubjects(
        courseId: courseId,
        classId: cls.id,
      );
      _subjects = subjects;
      _subjectsState = ClassSubjectLoadState.loaded;
      AppLogger.info(
          _tag, 'Loaded ${subjects.length} subjects for class ${cls.id}');

      _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
      notifyListeners();

      if (_selectedSubject != null) {
        _loadChapters(cls, _selectedSubject!);
      }
    } on NetworkException catch (e) {
      _subjectsError = e.message;
      _subjectsState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Network error loading subjects: $e');
      notifyListeners();
    } on RequestTimeoutException catch (e) {
      _subjectsError = e.message;
      _subjectsState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Timeout loading subjects: $e');
      notifyListeners();
    } on ServerException catch (e) {
      _subjectsError = e.message;
      _subjectsState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Server error loading subjects: $e');
      notifyListeners();
    } catch (e, st) {
      _subjectsError = 'Something went wrong. Please try again.';
      _subjectsState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Unexpected error loading subjects', e, st);
      notifyListeners();
    }
  }

  Future<void> _loadChapters(ClassModel cls, SubjectItemModel subject) async {
    if (_chaptersState == ClassSubjectLoadState.loading) return;

    _chaptersState = ClassSubjectLoadState.loading;
    _chaptersError = null;
    _chapters = [];
    _selectedChapter = null;
    notifyListeners();

    try {
      final chapters = await _repository.getChapters(
        courseId: courseId,
        classId: cls.id,
        subjectId: subject.id,
      );
      _chapters = chapters;
      _chaptersState = ClassSubjectLoadState.loaded;
      AppLogger.info(
          _tag, 'Loaded ${chapters.length} chapters for subject ${subject.id}');

      _selectedChapter = _chapters.isNotEmpty ? _chapters.first : null;
      notifyListeners();
    } on NetworkException catch (e) {
      _chaptersError = e.message;
      _chaptersState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Network error loading chapters: $e');
      notifyListeners();
    } on RequestTimeoutException catch (e) {
      _chaptersError = e.message;
      _chaptersState = ClassSubjectLoadState.error;
      AppLogger.warning(_tag, 'Timeout loading chapters: $e');
      notifyListeners();
    } on ServerException catch (e) {
      _chaptersError = e.message;
      _chaptersState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Server error loading chapters: $e');
      notifyListeners();
    } catch (e, st) {
      _chaptersError = 'Something went wrong. Please try again.';
      _chaptersState = ClassSubjectLoadState.error;
      AppLogger.error(_tag, 'Unexpected error loading chapters', e, st);
      notifyListeners();
    }
  }
}
