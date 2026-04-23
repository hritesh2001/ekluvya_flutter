import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../data/models/channel_model.dart';
import '../../domain/repositories/channel_repository.dart';

enum ChannelLoadState { initial, loading, loaded, error }

/// Manages the list of partner channels and their videos for a course-detail
/// screen.
///
/// Lifecycle:
///   1. Call [load] when the filter params are ready (courseId + classId +
///      subjectId). Re-call whenever any param changes.
///   2. [load] is idempotent for identical params — it skips the HTTP call if
///      the same combination is already loaded or currently in-flight.
///   3. [retry] re-issues the last load with the same params.
class ChannelViewModel extends ChangeNotifier {
  static const _tag = 'ChannelViewModel';

  final ChannelRepository _repo;
  final ApiService? _apiService;

  ChannelViewModel({
    required ChannelRepository repository,
    ApiService? apiService,
  })  : _repo = repository,
        _apiService = apiService;

  // ── State ─────────────────────────────────────────────────────────────────

  ChannelLoadState _state = ChannelLoadState.initial;
  List<ChannelModel> _channels = [];
  String? _error;

  ChannelLoadState get state => _state;
  List<ChannelModel> get channels => List.unmodifiable(_channels);
  String? get error => _error;

  bool get isLoading => _state == ChannelLoadState.loading;
  bool get hasData =>
      _state == ChannelLoadState.loaded && _channels.isNotEmpty;
  bool get hasError => _state == ChannelLoadState.error;

  // ── Last load params (for retry + deduplication) ──────────────────────────

  String? _lastCourseId;
  String? _lastClassId;
  String? _lastSubjectId;
  String? _lastChapterId;

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Loads channels for the given filter combination.
  ///
  /// No-op when called with the same params while already loaded or loading.
  /// Always fetches fresh data when params change (e.g. subject switch).
  Future<void> load({
    required String courseId,
    required String classId,
    required String subjectId,
    String chapterId = '',
  }) async {
    // Skip if params unchanged and data is fresh or still loading.
    final sameParams = courseId == _lastCourseId &&
        classId == _lastClassId &&
        subjectId == _lastSubjectId &&
        chapterId == _lastChapterId;

    if (sameParams &&
        (_state == ChannelLoadState.loaded ||
            _state == ChannelLoadState.loading)) {
      return;
    }

    // Params changed or first load — update tracking state and fetch.
    _lastCourseId = courseId;
    _lastClassId = classId;
    _lastSubjectId = subjectId;
    _lastChapterId = chapterId;

    _state = ChannelLoadState.loading;
    _error = null;
    _channels = [];
    notifyListeners();

    try {
      final token = await _apiService?.getToken();
      final channels = await _repo.getChannels(
        courseId: courseId,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        token: token,
      );
      _channels = channels;
      _state = ChannelLoadState.loaded;
      AppLogger.info(_tag, 'Loaded ${channels.length} channels');
    } on NetworkException catch (e) {
      _error = e.message;
      _state = ChannelLoadState.error;
      AppLogger.warning(_tag, 'Network error: $e');
    } on RequestTimeoutException catch (e) {
      _error = e.message;
      _state = ChannelLoadState.error;
      AppLogger.warning(_tag, 'Timeout: $e');
    } on ServerException catch (e) {
      _error = e.message;
      _state = ChannelLoadState.error;
      AppLogger.error(_tag, 'Server error: $e');
    } catch (e, st) {
      _error = 'Something went wrong. Please try again.';
      _state = ChannelLoadState.error;
      AppLogger.error(_tag, 'Unexpected error', e, st);
    } finally {
      notifyListeners();
    }
  }

  /// Re-runs the last [load] call. No-op if load was never called.
  void retry() {
    final courseId = _lastCourseId;
    final classId = _lastClassId;
    final subjectId = _lastSubjectId;
    if (courseId == null || classId == null || subjectId == null) return;

    // Reset state so [load] doesn't skip due to idempotency check.
    _state = ChannelLoadState.initial;
    load(
      courseId: courseId,
      classId: classId,
      subjectId: subjectId,
      chapterId: _lastChapterId ?? '',
    );
  }
}
