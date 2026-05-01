import '../../domain/entities/video_access_status.dart';
import '../../domain/repositories/video_access_repository.dart';

/// Concrete implementation of [VideoAccessRepository].
///
/// Monetization values from the channel-list API:
///   5 → login-only  (free for any authenticated user, any position)
///   8 → subscription-gated (non-first videos require subscription)
///
/// Evaluation order (first match wins):
///   1. listPosition == 0                → free  (first video is always free)
///   2. monetization == 5, logged in     → free
///   3. monetization == 5, not logged in → requiresLogin
///   4. monetization == 8, not logged in → requiresLogin
///   5. monetization == 8, not subscribed→ requiresSubscription
///   6. monetization == 8, subscribed    → unlocked
///   7. not logged in (default)          → requiresLogin
///   8. not subscribed (default)         → requiresSubscription
///   9. subscribed (default)             → unlocked
class VideoAccessRepositoryImpl implements VideoAccessRepository {
  const VideoAccessRepositoryImpl();

  static const _kLoginOnly            = 5;
  static const _kSubscriptionRequired = 8;

  @override
  VideoAccessStatus getAccessStatus({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
    int monetization = 0,
  }) {
    final safeIndex = episodeIndex < 0 ? 0 : episodeIndex;

    // Rule 1 — first video is always free (no login or subscription required).
    if (safeIndex == 0) return VideoAccessStatus.free;

    // Rule 2 & 3 — monetization 5: free once logged in, login wall for guests.
    if (monetization == _kLoginOnly) {
      return isLoggedIn
          ? VideoAccessStatus.free
          : VideoAccessStatus.requiresLogin;
    }

    // Rule 4-6 — monetization 8: subscription required for non-first videos.
    if (monetization == _kSubscriptionRequired) {
      if (!isLoggedIn)   return VideoAccessStatus.requiresLogin;
      if (!isSubscribed) return VideoAccessStatus.requiresSubscription;
      return VideoAccessStatus.unlocked;
    }

    // Default — other monetization values.
    if (!isLoggedIn)   return VideoAccessStatus.requiresLogin;
    if (!isSubscribed) return VideoAccessStatus.requiresSubscription;
    return VideoAccessStatus.unlocked;
  }
}
