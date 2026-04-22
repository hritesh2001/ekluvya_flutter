import '../../domain/entities/video_access_status.dart';
import '../../domain/repositories/video_access_repository.dart';

/// Concrete implementation of [VideoAccessRepository].
///
/// Rule: first video in every series (episodeIndex == 0) is always free for
/// all education partners — demo/trial purpose.  All subsequent videos require
/// a logged-in, active subscription.
///
/// To change the rule (e.g. first 3 free, or partner-specific overrides),
/// extend this class or provide a different implementation — callers are
/// unaffected because they depend on the abstract interface, not this class.
class VideoAccessRepositoryImpl implements VideoAccessRepository {
  const VideoAccessRepositoryImpl();

  @override
  VideoAccessStatus getAccessStatus({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
  }) {
    // Guard: treat negative indices as 0 (defensive — APIs can misbehave).
    final safeIndex = episodeIndex < 0 ? 0 : episodeIndex;

    if (safeIndex == 0) return VideoAccessStatus.free;
    if (!isLoggedIn) return VideoAccessStatus.requiresLogin;
    if (!isSubscribed) return VideoAccessStatus.requiresSubscription;
    return VideoAccessStatus.unlocked;
  }
}
