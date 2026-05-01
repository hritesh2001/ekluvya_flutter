import 'dart:async';

import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../../channel/data/models/video_item_model.dart';
import '../../../rating/data/models/video_rating_model.dart';
import '../../../rating/domain/repositories/rating_repository.dart';
import '../../../watch_history/data/remote/watch_history_api_service.dart';
import '../../../watch_history/presentation/viewmodel/watch_history_viewmodel.dart';
import '../../data/models/watch_progress_model.dart';
import '../../data/services/playback_header_resolver.dart';
import '../../data/services/watch_progress_service.dart';

enum VideoPlayerState { idle, loading, playing, paused, buffering, error }

/// Owns the [BetterPlayerController] lifecycle for a single video or playlist.
class VideoPlayerViewModel extends ChangeNotifier {
  static const _tag = 'VideoPlayerViewModel';
  static const _saveIntervalSeconds = 5;
  static const _initializationTimeout = Duration(seconds: 20);

  VideoPlayerViewModel({
    WatchProgressService? progressService,
    PlaybackHeaderResolver? headerResolver,
    WatchHistoryApiService? watchHistoryApi,
    ApiService? remoteAuthApi,
    String profileId = '',
    WatchHistoryViewModel? watchHistoryVm,
    RatingRepository? ratingRepo,
  })  : _progressService = progressService ?? WatchProgressService(),
        _headerResolver = headerResolver ?? PlaybackHeaderResolver(),
        _watchHistoryApi = watchHistoryApi,
        _remoteAuthApi = remoteAuthApi,
        _profileId = profileId,
        _watchHistoryVm = watchHistoryVm,
        _ratingRepo = ratingRepo;

  final WatchProgressService _progressService;
  final PlaybackHeaderResolver _headerResolver;
  final WatchHistoryApiService? _watchHistoryApi;
  final ApiService? _remoteAuthApi;
  final String _profileId;
  final WatchHistoryViewModel? _watchHistoryVm;
  final RatingRepository? _ratingRepo;

  VideoPlayerState _state = VideoPlayerState.idle;
  String? _errorMessage;
  BetterPlayerController? _controller;
  VideoItemModel? _video;
  WatchProgressModel? _savedProgress;
  bool _resumeApplied = false;
  bool _isDisposed = false;
  Timer? _saveTimer;
  Timer? _initializationTimeoutTimer;
  int _lastSavedPosition = 0;
  int _initializationGeneration = 0;
  Map<String, String> _headers = const {};

  // ── Playlist / chapter ─────────────────────────────────────────────────────
  List<VideoItemModel> _playlist = const [];
  int _currentIndex = 0;
  String _chapterName = '';

  // ── Rating ─────────────────────────────────────────────────────────────────
  double _userRating = 0.0;
  bool _isSubmittingRating = false;
  VideoRatingModel? _videoRating; // community stats + user's own vote
  String? _ratingError;

  // ── Getters ────────────────────────────────────────────────────────────────
  VideoPlayerState get state => _state;
  String? get errorMessage => _errorMessage;
  BetterPlayerController? get controller => _controller;
  WatchProgressModel? get savedProgress => _savedProgress;

  List<VideoItemModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  String get chapterName => _chapterName;
  VideoItemModel? get currentVideo => _video;
  double get userRating => _userRating;
  bool get isSubmittingRating => _isSubmittingRating;
  VideoRatingModel? get videoRating => _videoRating;
  String? get ratingError => _ratingError;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Optionally set a playlist before calling [initialize].
  void setPlaylist(
    List<VideoItemModel> playlist,
    int initialIndex, {
    String chapterName = '',
  }) {
    _playlist = List.unmodifiable(playlist);
    _currentIndex = initialIndex.clamp(0, playlist.isEmpty ? 0 : playlist.length - 1);
    _chapterName = chapterName;
  }

  void setUserRating(double rating) {
    _userRating = rating.clamp(0.0, 5.0);
    notifyListeners();
  }

  /// Submits a 1–5 star rating with optimistic UI update.
  ///
  /// Flow:
  ///   1. Immediately update [userRating] and set [isSubmittingRating].
  ///   2. POST to the rating API.
  ///   3. On success → refresh [videoRating] with updated community stats.
  ///   4. On failure → revert [userRating] and expose [ratingError].
  Future<void> submitRating(int stars) async {
    final video = _video;
    final repo  = _ratingRepo;
    if (video == null || repo == null) return;
    if (_isSubmittingRating) return; // guard against double-tap
    if (stars < 1 || stars > 5) return;

    final prevRating = _userRating;
    _userRating = stars.toDouble(); // optimistic
    _isSubmittingRating = true;
    _ratingError = null;
    if (!_isDisposed) notifyListeners();

    try {
      final token = await _remoteAuthApi?.getToken() ?? '';
      await repo.submitVideoRating(
        token:           token,
        masterDetailsId: video.id,
        ratingPoints:    stars,
      );
      AppLogger.info(_tag, 'Rating submitted: $stars★ for ${video.id}');
      // Background-refresh community stats; don't await — UI already updated.
      unawaited(_fetchVideoRating(video.id));
    } catch (e) {
      AppLogger.warning(_tag, 'submitRating failed: $e');
      _userRating  = prevRating; // revert optimistic update
      _ratingError = 'Failed to submit rating. Please try again.';
    } finally {
      _isSubmittingRating = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void clearRatingError() {
    if (_ratingError == null) return;
    _ratingError = null;
    if (!_isDisposed) notifyListeners();
  }

  /// Loads community stats + user's existing vote for [masterDetailsId].
  /// Called automatically on [initialize] and after a successful submission.
  Future<void> _fetchVideoRating(String masterDetailsId) async {
    final repo = _ratingRepo;
    if (repo == null || masterDetailsId.isEmpty) return;
    try {
      final token  = await _remoteAuthApi?.getToken() ?? '';
      final result = await repo.fetchVideoRating(
        masterDetailsId: masterDetailsId,
        token:           token,
      );
      if (result != null && !_isDisposed) {
        _videoRating = result;
        // Pre-fill user's previous vote only when they haven't rated this session.
        if (result.userRating > 0 && _userRating == 0) {
          _userRating = result.userRating;
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning(_tag, '_fetchVideoRating failed: $e');
    }
  }

  Future<void> initialize(
    VideoItemModel video, {
    Map<String, String> headers = const {},
  }) async {
    _video = video;
    _headers = Map<String, String>.unmodifiable(headers);
    _resumeApplied = false;
    _errorMessage = null;
    _lastSavedPosition = 0;
    _savedProgress = null;

    final playbackUrl = video.hlsUrl.trim();
    if (playbackUrl.isEmpty) {
      AppLogger.warning(_tag, 'HLS URL empty for video ${video.id}');
      _setErrorState('This video is not available for playback right now.');
      return;
    }

    // Reset rating state for the new video.
    _userRating = 0.0;
    _videoRating = null;
    _ratingError = null;
    _isSubmittingRating = false;

    // Cache episode thumbnail so watch history can show the correct image.
    // The watch-history API only returns series-level thumbnails via
    // master_details_id; the episode thumbnail lives here on VideoItemModel.
    unawaited(_progressService.saveThumbnail(
      videoId: video.id,
      thumbnailUrl: video.thumbnailUrl,
    ));

    // Pre-load community rating and user's previous vote (fire-and-forget).
    unawaited(_fetchVideoRating(video.id));

    final generation = ++_initializationGeneration;
    _setState(VideoPlayerState.loading);
    _startInitializationTimeout();

    try {
      _savedProgress = await _progressService.getProgress(video.id);
      if (!_isActiveGeneration(generation)) return;

      if (_savedProgress != null) {
        AppLogger.info(
          _tag,
          'Resume position: ${_savedProgress!.positionSeconds}s '
          '(${_savedProgress!.completionPercent.toStringAsFixed(1)}%)',
        );
      }

      final resolvedHeaders = await _headerResolver.resolve(
        playbackUrl: playbackUrl,
        initialHeaders: headers,
      );
      if (!_isActiveGeneration(generation)) return;

      final isProtected = PlaybackHeaderResolver.requiresSignedCookies(playbackUrl);
      final controller = BetterPlayerController(_buildConfiguration(video));
      controller.addEventsListener(_onPlayerEvent);
      _controller = controller;

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        playbackUrl,
        videoFormat: BetterPlayerVideoFormat.hls,
        headers: resolvedHeaders.isEmpty ? null : resolvedHeaders,
        useAsmsSubtitles: !isProtected,
        useAsmsTracks: !isProtected,
        useAsmsAudioTracks: !isProtected,
        notificationConfiguration: const BetterPlayerNotificationConfiguration(
          showNotification: false,
        ),
        cacheConfiguration: isProtected
            ? null
            : const BetterPlayerCacheConfiguration(
                useCache: true,
                maxCacheSize: 100 * 1024 * 1024,
                maxCacheFileSize: 20 * 1024 * 1024,
              ),
      );

      await controller.setupDataSource(dataSource);
      if (!_isActiveGeneration(generation)) {
        controller.removeEventsListener(_onPlayerEvent);
        controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }

      _startProgressTimer();
      unawaited(WakelockPlus.enable());
    } on PlaybackAuthorizationException catch (e, st) {
      _handlePlaybackFailure(e.message, e, st);
    } on AppException catch (e, st) {
      _handlePlaybackFailure(e.message, e, st);
    } catch (e, st) {
      _handlePlaybackFailure(
        'Playback failed. Please check your connection and try again.',
        e,
        st,
      );
    }
  }

  void pause() {
    _controller?.pause();
  }

  void play() {
    _controller?.play();
  }

  void togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.isPlaying() == true) {
      c.pause();
    } else {
      c.play();
    }
  }

  void seekForward(Duration amount) {
    final c = _controller;
    if (c == null) return;
    final current = c.videoPlayerController?.value.position ?? Duration.zero;
    final duration = c.videoPlayerController?.value.duration ?? Duration.zero;
    final target = current + amount;
    c.seekTo(target > duration ? duration : target);
  }

  void seekBackward(Duration amount) {
    final c = _controller;
    if (c == null) return;
    final current = c.videoPlayerController?.value.position ?? Duration.zero;
    final target = current - amount;
    c.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  void seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    _currentIndex++;
    _disposeController();
    await initialize(_playlist[_currentIndex], headers: _headers);
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    _currentIndex--;
    _disposeController();
    await initialize(_playlist[_currentIndex], headers: _headers);
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _disposeController();
    await initialize(_playlist[_currentIndex], headers: _headers);
  }

  Future<void> retry() async {
    final video = _video;
    if (video == null) return;
    _errorMessage = null;
    _resumeApplied = false;
    await _saveCurrentProgress();
    _disposeController();
    await initialize(video, headers: _headers);
  }

  // ── Configuration ──────────────────────────────────────────────────────────

  BetterPlayerConfiguration _buildConfiguration(VideoItemModel video) {
    return BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.cover,
      autoPlay: true,
      looping: false,
      allowedScreenSleep: true,
      fullScreenByDefault: false,
      autoDetectFullscreenDeviceOrientation: false,
      autoDetectFullscreenAspectRatio: false,
      expandToFill: true,
      placeholder: const ColoredBox(color: Colors.black),
      deviceOrientationsOnFullScreen: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: const [
        DeviceOrientation.portraitUp,
      ],
      // Custom theme suppresses all built-in controls UI — our overlay handles everything.
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.custom,
        customControlsBuilder: (controller, onPlayerVisibilityChanged) =>
            const SizedBox.shrink(),
        showControlsOnInitialize: false,
      ),
    );
  }

  // ── Player events ──────────────────────────────────────────────────────────

  void _onPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        _cancelInitializationTimeout();
        _applyResumePosition();
        _controller?.play(); // guarantee autoplay even when seekTo interrupts auto-start
        _setState(VideoPlayerState.playing);

      case BetterPlayerEventType.play:
        _cancelInitializationTimeout();
        unawaited(WakelockPlus.enable());
        _setState(VideoPlayerState.playing);

      case BetterPlayerEventType.pause:
        unawaited(WakelockPlus.disable());
        unawaited(_saveCurrentProgress());
        _setState(VideoPlayerState.paused);

      case BetterPlayerEventType.bufferingStart:
        _setState(VideoPlayerState.buffering);

      case BetterPlayerEventType.bufferingEnd:
        _setState(
          (_controller?.isPlaying() ?? false)
              ? VideoPlayerState.playing
              : VideoPlayerState.paused,
        );

      case BetterPlayerEventType.finished:
        unawaited(_saveCurrentProgress());
        unawaited(WakelockPlus.disable());
        _setState(VideoPlayerState.paused);

      case BetterPlayerEventType.exception:
        final raw = event.parameters?['exception']?.toString().trim();
        _handlePlaybackFailure(
          raw?.isNotEmpty == true
              ? raw!
              : 'Playback failed. Please check your connection and retry.',
          raw,
          null,
        );

      default:
        break;
    }
  }

  // ── Resume position ────────────────────────────────────────────────────────

  void _applyResumePosition() {
    if (_resumeApplied) return;
    _resumeApplied = true;

    final p = _savedProgress;
    if (p == null || p.positionSeconds <= 5 || p.isCompleted) return;

    final duration = _controller?.videoPlayerController?.value.duration;
    if (duration == null || duration.inSeconds <= 0) return;

    try {
      _controller?.seekTo(Duration(seconds: p.positionSeconds));
      AppLogger.info(_tag, 'Resumed at ${p.positionSeconds}s');
      // Ensure playback continues after the seek — BetterPlayer may briefly
      // pause when seekTo() is called immediately after initialization.
      _controller?.play();
    } catch (e, st) {
      AppLogger.warning(_tag, 'Resume seek failed: $e');
      AppLogger.error(_tag, 'Resume seek stack trace', e, st);
    }
  }

  // ── Progress persistence ───────────────────────────────────────────────────

  void _startProgressTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(
      const Duration(seconds: _saveIntervalSeconds),
      (_) => unawaited(_saveCurrentProgress()),
    );
  }

  Future<void> _saveCurrentProgress() async {
    final video = _video;
    final controller = _controller;
    if (video == null || controller == null) return;

    final value = controller.videoPlayerController?.value;
    final position = value?.position.inSeconds ?? 0;
    final duration = value?.duration?.inSeconds ?? 0;
    if (position <= 0 || position == _lastSavedPosition) return;

    _lastSavedPosition = position;
    await _progressService.saveProgress(
      videoId: video.id,
      positionSeconds: position,
      durationSeconds: duration,
    );
    // Fire-and-forget: post progress to remote watch history API
    unawaited(_postRemoteWatchHistory(mediaId: video.id, positionSeconds: position));
  }

  Future<void> _postRemoteWatchHistory({
    required String mediaId,
    required int positionSeconds,
  }) async {
    final api  = _watchHistoryApi;
    final auth = _remoteAuthApi;
    if (api == null || auth == null || mediaId.isEmpty) return;
    try {
      final token = await auth.getToken() ?? '';
      if (token.isEmpty) return;
      await api.postWatchHistory(
        token:           token,
        mediaId:         mediaId,
        watchedDuration: positionSeconds,
        playTime:        positionSeconds,
        profileId:       _profileId,
      );
    } catch (e) {
      AppLogger.warning(_tag, 'postRemoteWatchHistory failed: $e');
    }
  }

  // ── Error handling ─────────────────────────────────────────────────────────

  void _handlePlaybackFailure(
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    _cancelInitializationTimeout();
    AppLogger.error(_tag, message, error, stackTrace);
    _setErrorState(message);
  }

  void _setErrorState(String message) {
    _errorMessage = message;
    _disposeController();
    _setState(VideoPlayerState.error);
  }

  // ── Controller disposal ────────────────────────────────────────────────────

  void _disposeController() {
    _cancelInitializationTimeout();
    _saveTimer?.cancel();
    _saveTimer = null;

    final controller = _controller;
    if (controller != null) {
      controller.removeEventsListener(_onPlayerEvent);
      controller.dispose();
      _controller = null;
    }

    unawaited(WakelockPlus.disable());
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  bool _isActiveGeneration(int generation) =>
      !_isDisposed && generation == _initializationGeneration;

  void _startInitializationTimeout() {
    _initializationTimeoutTimer?.cancel();
    _initializationTimeoutTimer = Timer(_initializationTimeout, () {
      if (_isDisposed) return;
      if (_state == VideoPlayerState.loading ||
          _state == VideoPlayerState.buffering) {
        _handlePlaybackFailure(
          'Video is taking too long to load. Please try again.',
          null,
          null,
        );
      }
    });
  }

  void _cancelInitializationTimeout() {
    _initializationTimeoutTimer?.cancel();
    _initializationTimeoutTimer = null;
  }

  void _setState(VideoPlayerState next) {
    if (_isDisposed || _state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _initializationGeneration++;
    _cancelInitializationTimeout();
    _saveTimer?.cancel();
    _saveTimer = null;

    // Capture playback position synchronously BEFORE _disposeController nulls
    // out the controller. Using a local copy guarantees we read a valid value
    // even though the rest of dispose runs after us in the event queue.
    final video       = _video;
    final capturedPos =
        _controller?.videoPlayerController?.value.position.inSeconds ?? 0;

    _controller?.pause();
    _disposeController();

    final histVm = _watchHistoryVm;

    // Post the final position (if it moved since the last timer tick), then
    // refresh history AFTER the POST so the backend entry exists before the
    // fetch runs. Without this sequencing the refresh races the write and the
    // new entry is invisible until the user manually revisits the History tab.
    unawaited(() async {
      if (video != null &&
          video.id.isNotEmpty &&
          capturedPos > 0 &&
          capturedPos != _lastSavedPosition) {
        await _progressService.saveProgress(
          videoId:         video.id,
          positionSeconds: capturedPos,
          durationSeconds: video.durationSeconds,
        );
        await _postRemoteWatchHistory(
          mediaId:        video.id,
          positionSeconds: capturedPos,
        );
      }
      // Always refresh — even when no new save is needed the timer's earlier
      // POSTs should already be on the backend by the time we close.
      histVm?.refreshWatchHistory();
    }());

    super.dispose();
  }
}
