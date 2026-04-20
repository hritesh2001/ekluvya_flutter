import 'dart:async';

import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/logger.dart';
import '../../../channel/data/models/video_item_model.dart';
import '../../../signed_cookie/domain/repositories/signed_cookie_repository.dart';
import '../../data/services/playback_cookie_store.dart';
import '../../data/services/playback_header_resolver.dart';
import '../viewmodel/video_player_viewmodel.dart';

/// Full-screen OTT video player — landscape-only.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.headers = const {},
  });

  final VideoItemModel video;
  final Map<String, String> headers;

  static Route<void> route(
    VideoItemModel video, {
    Map<String, String> headers = const {},
  }) =>
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(video: video, headers: headers),
      );

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const _tag = 'VideoPlayerScreen';

  late final VideoPlayerViewModel _vm;

  // Guards against double-pop (rapid taps or hardware back + button tap).
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _vm = VideoPlayerViewModel(
      headerResolver: PlaybackHeaderResolver(
        playbackCookieStore: PlaybackCookieStore(),
        signedCookieRepository: _tryReadSignedCookieRepository(),
      ),
    );
    _enterPlaybackMode();
  }

  SignedCookieRepository? _tryReadSignedCookieRepository() {
    try {
      return context.read<SignedCookieRepository>();
    } on ProviderNotFoundException catch (e, st) {
      AppLogger.warning(_tag, 'SignedCookieRepository not found; using provided headers.');
      AppLogger.error(_tag, 'Provider lookup failed', e, st);
      return null;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _enterPlaybackMode() async {
    // Fire both platform-channel calls without awaiting — each is an async
    // round-trip that can take 100–200 ms, and neither needs to complete
    // before the video can start buffering.  ExoPlayer/AVPlayer decode into
    // their own texture; the surface resizes to landscape before the first
    // decoded frame is composed, which happens well after the manifest fetch.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await _vm.initialize(widget.video, headers: widget.headers);
    if (!mounted || _vm.state == VideoPlayerState.error) return;
    _maybeShowResumeSnackbar();
  }

  /// Restores portrait mode and system UI.  Called fire-and-forget — never
  /// awaited before navigation so the UI thread is never stalled.
  void _restoreSystemChrome() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Single exit path used by the on-screen back button AND the hardware back
  /// key (via PopScope).  Must stay synchronous so it cannot be blocked.
  void _exit() {
    if (_isExiting || !mounted) return;
    _isExiting = true;

    // 1. Pause immediately — stops ExoPlayer rendering before surface teardown.
    _vm.pause();

    // 2. Restore chrome as fire-and-forget.  Queued in the platform channel
    //    and processed after the frame that shows the previous route, so the
    //    user sees the portrait UI restored without any stall on this thread.
    _restoreSystemChrome();

    // 3. Use Navigator.pop() — NOT maybePop().
    //    maybePop() respects PopScope(canPop: false) and silently does nothing,
    //    which is the root cause of the back-button freeze reported.
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vm.dispose();
    // Fallback restore in case the OS tears down the route without going
    // through _exit() (e.g. killed from recent apps).
    _restoreSystemChrome();
    super.dispose();
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

  void _maybeShowResumeSnackbar() {
    final p = _vm.savedProgress;
    if (p == null || p.positionSeconds <= 5 || p.isCompleted) return;

    final m = p.positionSeconds ~/ 60;
    final s = p.positionSeconds % 60;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m > 0 ? 'Resuming from ${m}m ${s}s' : 'Resuming from ${s}s'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xCC000000),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false — intercept hardware back so _exit() always runs first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: ChangeNotifierProvider<VideoPlayerViewModel>.value(
        value: _vm,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerBody(onBack: _exit),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Selector rebuilds only when the controller reference changes.
        // BetterPlayer is never reconstructed on play/pause/buffer transitions.
        Selector<VideoPlayerViewModel, BetterPlayerController?>(
          selector: (_, vm) => vm.controller,
          builder: (_, controller, _) => _VideoLayer(controller: controller),
        ),

        // Spinner only while loading or buffering.
        Selector<VideoPlayerViewModel, bool>(
          selector: (_, vm) =>
              vm.state == VideoPlayerState.loading ||
              vm.state == VideoPlayerState.buffering,
          builder: (_, show, _) =>
              show ? const _LoadingOverlay() : const SizedBox.shrink(),
        ),

        // Error overlay.
        Selector<VideoPlayerViewModel, (bool, String?)>(
          selector: (_, vm) =>
              (vm.state == VideoPlayerState.error, vm.errorMessage),
          builder: (_, record, _) {
            final (isError, message) = record;
            if (!isError) return const SizedBox.shrink();
            return _ErrorOverlay(
              message: message,
              onRetry: context.read<VideoPlayerViewModel>().retry,
            );
          },
        ),

        _BackButton(onBack: onBack),
      ],
    );
  }
}

// ── Video layer ───────────────────────────────────────────────────────────────

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});

  final BetterPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller == null) return const ColoredBox(color: Colors.black);
    return SizedBox.expand(child: BetterPlayer(controller: controller!));
  }
}

// ── Loading overlay ───────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE91E63),
          strokeWidth: 3,
        ),
      );
}

// ── Error overlay ─────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE91E63),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'Playback failed. Please check your connection.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Try again',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      child: SafeArea(
        bottom: false,
        right: false,
        child: GestureDetector(
          onTap: onBack,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
