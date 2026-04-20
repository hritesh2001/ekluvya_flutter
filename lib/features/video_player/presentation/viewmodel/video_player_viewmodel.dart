import 'dart:async';

import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../channel/data/models/video_item_model.dart';
import '../../data/models/watch_progress_model.dart';
import '../../data/services/playback_header_resolver.dart';
import '../../data/services/watch_progress_service.dart';

enum VideoPlayerState { idle, loading, playing, paused, buffering, error }

/// Owns the [BetterPlayerController] lifecycle for a single video.
class VideoPlayerViewModel extends ChangeNotifier {
  static const _tag = 'VideoPlayerViewModel';
  static const _saveIntervalSeconds = 5;
  static const _initializationTimeout = Duration(seconds: 20);

  VideoPlayerViewModel({
    WatchProgressService? progressService,
    PlaybackHeaderResolver? headerResolver,
  })  : _progressService = progressService ?? WatchProgressService(),
        _headerResolver = headerResolver ?? PlaybackHeaderResolver();

  final WatchProgressService _progressService;
  final PlaybackHeaderResolver _headerResolver;

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

  VideoPlayerState get state => _state;
  String? get errorMessage => _errorMessage;
  BetterPlayerController? get controller => _controller;
  WatchProgressModel? get savedProgress => _savedProgress;

  // ── Public API ─────────────────────────────────────────────────────────────

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

  /// Pauses playback. Called by the screen before it navigates away so
  /// ExoPlayer stops rendering before the surface is torn down.
  void pause() {
    _controller?.pause();
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
      // Let WakelockPlus own screen-wake exclusively — BetterPlayer's
      // internal wakelock mechanism adds redundant overhead.
      allowedScreenSleep: true,
      fullScreenByDefault: false,
      // We manage orientation ourselves; these flags add listener overhead
      // and are irrelevant since BetterPlayer fullscreen is disabled.
      autoDetectFullscreenDeviceOrientation: false,
      autoDetectFullscreenAspectRatio: false,
      expandToFill: true,
      // Black container instead of Image.network: avoids a competing HTTP
      // request during the critical HLS-manifest fetch window.
      placeholder: const ColoredBox(color: Colors.black),
      deviceOrientationsOnFullScreen: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: const [
        DeviceOrientation.portraitUp,
      ],
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        progressBarPlayedColor: Color(0xFFE91E63),
        progressBarHandleColor: Color(0xFFE91E63),
        progressBarBufferedColor: Color(0x55E91E63),
        progressBarBackgroundColor: Color(0x40FFFFFF),
        controlBarColor: Color(0xCC000000),
        iconsColor: Color(0xFFFFFFFF),
        textColor: Color(0xFFFFFFFF),
        loadingColor: Color(0xFFE91E63),
        enableSkips: true,
        forwardSkipTimeInMilliseconds: 10000,
        backwardSkipTimeInMilliseconds: 10000,
        enablePlaybackSpeed: true,
        // controlsHideTime drives the AnimatedOpacity fade duration for
        // every control widget in BetterPlayer's material controls source
        // (6 AnimatedOpacity wrappers all read this value).  200 ms gives
        // a crisp OTT-level appear/disappear without feeling abrupt.
        // The auto-hide idle timer is hardcoded at 3 000 ms in the source
        // and is independent of this value.
        controlsHideTime: Duration(milliseconds: 200),
        enableQualities: true,
        enableSubtitles: false,
        enableAudioTracks: false,
        enableFullscreen: false,
        enableMute: true,
        enableOverflowMenu: true,
        enableProgressText: true,
        enableRetry: true,
        enablePip: false,
        // Controls only appear on tap — eliminates the grey overlay flash
        // on every video start.
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
    _initializationGeneration++; // invalidates any in-flight initialize() call
    _cancelInitializationTimeout();
    _saveTimer?.cancel();
    _saveTimer = null;
    // Pause before disposal — stops ExoPlayer rendering before the platform
    // texture is torn down, preventing surface-release exceptions.
    _controller?.pause();
    unawaited(_saveCurrentProgress());
    _disposeController();
    super.dispose();
  }
}
