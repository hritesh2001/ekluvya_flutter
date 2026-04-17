import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/rating_model.dart';
import '../../domain/repositories/rating_repository.dart';

/// Holds per-channel average ratings for the current chapter.
///
/// Call [load] when courseId / classId / subjectId / chapterId changes.
/// Idempotent — skips if same params already loaded.
class RatingViewModel extends ChangeNotifier {
  static const _tag = 'RatingViewModel';

  final RatingRepository _repo;

  RatingViewModel({required RatingRepository repository}) : _repo = repository;

  // channelId → ChannelRatingModel
  Map<String, ChannelRatingModel> _data = {};

  String? _lastCourseId;
  String? _lastClassId;
  String? _lastSubjectId;
  String? _lastChapterId;

  /// Returns the average rating (0–5) for [channelId], or 0.0 if unavailable.
  double ratingForChannel(String channelId) =>
      _data[channelId]?.averageRating ?? 0.0;

  Future<void> load({
    required String courseId,
    required String classId,
    required String subjectId,
    required String chapterId,
  }) async {
    if (courseId == _lastCourseId &&
        classId == _lastClassId &&
        subjectId == _lastSubjectId &&
        chapterId == _lastChapterId) {
      return;
    }

    _lastCourseId  = courseId;
    _lastClassId   = classId;
    _lastSubjectId = subjectId;
    _lastChapterId = chapterId;

    try {
      final list = await _repo.getChannelRatings(
        courseId: courseId,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
      );
      _data = {for (final r in list) r.channelId: r};
      AppLogger.info(_tag, 'Loaded ratings for ${list.length} channels');
    } catch (e) {
      // Rating load failures are non-fatal — sections still show without ratings.
      AppLogger.warning(_tag, 'Rating load failed (non-fatal): $e');
      _data = {};
    } finally {
      notifyListeners();
    }
  }
}
