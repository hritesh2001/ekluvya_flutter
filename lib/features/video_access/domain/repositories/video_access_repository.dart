import '../entities/video_access_status.dart';

/// Contract for the access-check logic.
///
/// Kept abstract so the rule can be swapped without touching callers
/// (e.g. A/B test: 3 free videos instead of 1, partner-specific rules).
abstract interface class VideoAccessRepository {
  /// Returns the [VideoAccessStatus] for a single video.
  ///
  /// Pure function — no side effects, no network calls, no state mutation.
  /// Safe to call on every build frame.
  VideoAccessStatus getAccessStatus({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
  });
}
