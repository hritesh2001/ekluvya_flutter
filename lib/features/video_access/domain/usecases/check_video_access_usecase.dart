import '../entities/video_access_status.dart';
import '../repositories/video_access_repository.dart';

/// Single-responsibility use case: determine whether a viewer can play a video.
///
/// Business rules (delegated to [VideoAccessRepository]):
///   • listPosition == 0                → free  (no auth required)
///   • monetization == 5, logged in     → free  (login-only content)
///   • monetization == 5, not logged in → requiresLogin
///   • not logged in                    → requiresLogin
///   • logged in, not subscribed        → requiresSubscription
///   • logged in + subscribed           → unlocked
///
/// Call site:
///   `useCase(episodeIndex: listPos, isLoggedIn: …, isSubscribed: …, monetization: v.monetization)`
class CheckVideoAccessUseCase {
  const CheckVideoAccessUseCase(this._repository);

  final VideoAccessRepository _repository;

  VideoAccessStatus call({
    required int episodeIndex,
    required bool isLoggedIn,
    required bool isSubscribed,
    int monetization = 0,
  }) =>
      _repository.getAccessStatus(
        episodeIndex: episodeIndex,
        isLoggedIn: isLoggedIn,
        isSubscribed: isSubscribed,
        monetization: monetization,
      );
}
