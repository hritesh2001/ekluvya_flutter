import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/class_model.dart';
import '../../data/models/subject_item_model.dart';
import '../../domain/repositories/class_subject_repository.dart';

enum ClassSubjectLoadState { initial, loading, loaded, error }

/// Manages classes + subjects state for a single course detail screen.
///
/// Lifecycle:
///   1. Call [initialize] once (done automatically by [CourseDetailScreen]).
///   2. [initialize] loads classes → selects the first → loads its subjects.
///   3. [selectClass] switches the active class and reloads subjects.
///   4. [selectSubject] updates the active subject tab.
///
/// Two independent load-states ([classesState] / [subjectsState]) allow the
/// UI to show the class selector immediately while subjects are still loading.
class ClassSubjectViewModel extends ChangeNotifier {
  static const _tag = 'ClassSubjectViewModel';

  final ClassSubjectRepository _repository;

  /// The course this screen is displaying — fixed for the lifetime of the VM.
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

  // ── Chapter filter state ───────────────────────────────────────────────────
  // Chapter names are seeded with mock data here and will be replaced by a
  // real /home/chapters API call in the next milestone.

  // TODO(chapters-api): replace with real API data from /home/chapters
  static const List<String> _mockChapters = [
    'BASIC MATHEMATICS',
    'ALGEBRA',
    'GEOMETRY',
    'NUMBER SYSTEM',
    'RATIO & PROPORTION',
    'STATISTICS',
    'MENSURATION',
  ];

  final List<String> _chapters = List.unmodifiable(_mockChapters);
  String? _selectedChapter = _mockChapters.first;

  List<String> get chapters => List.unmodifiable(_chapters);
  String? get selectedChapter => _selectedChapter;

  /// Updates the active chapter filter. No-op if already selected.
  void selectChapter(String chapter) {
    if (_selectedChapter == chapter) return;
    _selectedChapter = chapter;
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Entry point — call once when the screen mounts.
  /// Loads classes; on success auto-selects the first and loads subjects.
  void initialize() {
    if (_classesState != ClassSubjectLoadState.initial) return;
    _loadClasses();
  }

  /// Switches active class and triggers a fresh subject load.
  /// No-op if [cls] is already selected.
  void selectClass(ClassModel cls) {
    if (_selectedClass?.id == cls.id) return;
    _selectedClass = cls;
    _selectedSubject = null;
    _subjects = [];
    _subjectsState = ClassSubjectLoadState.initial;
    notifyListeners();
    _loadSubjects(cls);
  }

  /// Updates the active subject tab. Passing null clears the selection.
  void selectSubject(SubjectItemModel? subject) {
    if (_selectedSubject?.id == subject?.id) return;
    _selectedSubject = subject;
    notifyListeners();
  }

  /// Retries loading classes (e.g. after a network error).
  void retryClasses() {
    _classesState = ClassSubjectLoadState.initial;
    _classesError = null;
    _loadClasses();
  }

  /// Retries loading subjects for the currently selected class.
  void retrySubjects() {
    final cls = _selectedClass;
    if (cls == null) return;
    _subjectsState = ClassSubjectLoadState.initial;
    _subjectsError = null;
    _loadSubjects(cls);
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

      // Auto-select: prefer previously selected class (re-init guard),
      // otherwise default to the first.
      if (_selectedClass == null ||
          !_classes.any((c) => c.id == _selectedClass!.id)) {
        _selectedClass = _classes.isNotEmpty ? _classes.first : null;
      }

      notifyListeners();

      // Auto-load subjects for the auto-selected class
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

      // Auto-select the first subject
      _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
      notifyListeners();
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
}
