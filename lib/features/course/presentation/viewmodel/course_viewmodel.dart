import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/category_model.dart';
import '../../domain/repositories/course_repository.dart';

enum CourseState { initial, loading, loaded, error }

/// Manages the home-screen category + course data.
///
/// Exposes typed state, the category list, and retry logic.
/// Depends on [CourseRepository] — never on the concrete impl.
class CourseViewModel extends ChangeNotifier {
  static const _tag = 'CourseViewModel';

  final CourseRepository _repository;

  CourseState _state = CourseState.initial;
  List<CategoryModel> _categories = [];
  String? _errorMessage;

  CourseViewModel(this._repository);

  // ── Getters ──────────────────────────────────────────────────────────

  CourseState get state => _state;
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == CourseState.loading;
  bool get hasError => _state == CourseState.error;
  bool get hasData =>
      _state == CourseState.loaded && _categories.isNotEmpty;
  bool get isEmpty =>
      _state == CourseState.loaded && _categories.isEmpty;

  // ── Actions ──────────────────────────────────────────────────────────

  /// Loads all categories. Guards against duplicate in-flight calls.
  Future<void> loadCategories() async {
    if (_state == CourseState.loading) return;

    _state = CourseState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _repository.getCategories();
      _state = CourseState.loaded;
      AppLogger.info(
          _tag, 'Loaded ${_categories.length} categories');
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _state = CourseState.error;
      AppLogger.warning(_tag, 'Network error: $e');
    } on RequestTimeoutException catch (e) {
      _errorMessage = e.message;
      _state = CourseState.error;
      AppLogger.warning(_tag, 'Timeout: $e');
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _state = CourseState.error;
      AppLogger.error(_tag, 'Server error: $e');
    } catch (e, st) {
      _errorMessage = 'Something went wrong. Please try again.';
      _state = CourseState.error;
      AppLogger.error(_tag, 'Unexpected error', e, st);
    } finally {
      notifyListeners();
    }
  }

  /// Wired to the Retry button in the error UI.
  void retry() => loadCategories();
}
