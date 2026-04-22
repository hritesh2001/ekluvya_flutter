/// Describes what access level a viewer has for a specific video.
///
/// Determined entirely by two facts:
///   • the video's position in its series  (episodeIndex)
///   • the viewer's current auth+subscription state
///
/// The UI uses this to decide lock overlay, FREE badge, and tap routing.
enum VideoAccessStatus {
  /// Episode 0 — always free, no auth required, shows "FREE" badge.
  free,

  /// Episode > 0 and viewer is a logged-in subscriber — fully playable.
  unlocked,

  /// Episode > 0 and viewer is not logged in — lock overlay, taps → /login.
  requiresLogin,

  /// Episode > 0, viewer is logged in but not subscribed — lock overlay,
  /// taps → subscription paywall.
  requiresSubscription,
}

extension VideoAccessStatusX on VideoAccessStatus {
  bool get isPlayable =>
      this == VideoAccessStatus.free || this == VideoAccessStatus.unlocked;

  bool get isLocked => !isPlayable;

  bool get isFree => this == VideoAccessStatus.free;

  bool get needsLogin => this == VideoAccessStatus.requiresLogin;

  bool get needsSubscription =>
      this == VideoAccessStatus.requiresSubscription;
}
