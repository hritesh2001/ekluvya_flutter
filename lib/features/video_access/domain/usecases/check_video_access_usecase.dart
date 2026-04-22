import '../entities/video_access_status.dart';
import '../repositories/video_access_repository.dart';

/// Single-responsibility use case: determine whether a viewer can play a video.
///
/// Business rule (enforced here in the domain, not scattered across UI):
///   • episode 0           → always [VideoAccessStatus.free]
///   • episode > 0, no auth → [VideoAccessStatus.requiresLogin]
///   • episode > 0, no sub  → [VideoAccessStatus.requiresSubscription]
///   • episode > 0, subscribed → [VideoAccessStatus.unlocked]
///
/// Call site: `useCase(episodeIndex: v.episodeIndex, isLoggedIn: …, isSubscribed: …)`
class CheckVideoAccessUseCase {
  const CheckVideoAccessUseCase(this._repository);

  final VideoAccessRepository _repository;

  VideoAccessStatus call({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
  }) =>
      _repository.getAccessStatus(
        episodeIndex: episodeIndex,
        isLoggedIn: isLoggedIn,
        isSubscribed: isSubscribed,
      );
}
