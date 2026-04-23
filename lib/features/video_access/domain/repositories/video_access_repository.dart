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
  ///
  /// [monetization] is the API field from the channel-list response.
  /// monetization == 5 unlocks the video for any logged-in user (no subscription
  /// required), but still requires login for unauthenticated viewers.
  VideoAccessStatus getAccessStatus({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
    int monetization = 0,
  });
}
