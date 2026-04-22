import 'dart:async';
import 'dart:math' as math;

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

// ── Brand colors ──────────────────────────────────────────────────────────────
const _kBrand = Color(0xFFE91E63);
const _kBrandOrange = Color(0xFFFF5722);

// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen OTT video player — landscape-only.
///
/// Pass an optional [playlist] + [initialIndex] to enable prev/next navigation.
/// Pass [chapterName] to display the chapter label in the top bar.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.headers = const {},
    this.playlist = const [],
    this.initialIndex = 0,
    this.chapterName = '',
  });

  final VideoItemModel video;
  final Map<String, String> headers;
  final List<VideoItemModel> playlist;
  final int initialIndex;
  final String chapterName;

  static Route<void> route(
    VideoItemModel video, {
    Map<String, String> headers = const {},
    List<VideoItemModel> playlist = const [],
    int initialIndex = 0,
    String chapterName = '',
  }) =>
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(
          video: video,
          headers: headers,
          playlist: playlist,
          initialIndex: initialIndex,
          chapterName: chapterName,
        ),
      );

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const _tag = 'VideoPlayerScreen';

  late final VideoPlayerViewModel _vm;
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
    if (widget.playlist.isNotEmpty) {
      _vm.setPlaylist(
        widget.playlist,
        widget.initialIndex,
        chapterName: widget.chapterName,
      );
    }
    _enterPlaybackMode();
  }

  SignedCookieRepository? _tryReadSignedCookieRepository() {
    try {
      return context.read<SignedCookieRepository>();
    } on ProviderNotFoundException catch (e, st) {
      AppLogger.warning(_tag, 'SignedCookieRepository not found.');
      AppLogger.error(_tag, 'Provider lookup failed', e, st);
      return null;
    }
  }

  Future<void> _enterPlaybackMode() async {
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

  void _restoreSystemChrome() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  void _exit() {
    if (_isExiting || !mounted) return;
    _isExiting = true;
    _vm.pause();
    _restoreSystemChrome();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vm.dispose();
    _restoreSystemChrome();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: ChangeNotifierProvider<VideoPlayerViewModel>.value(
        value: _vm,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerBody(
            onBack: _exit,
            chapterName: widget.chapterName,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerBody
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerBody extends StatefulWidget {
  const _PlayerBody({required this.onBack, required this.chapterName});

  final VoidCallback onBack;
  final String chapterName;

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  Timer? _hideTimer;

  // Seek-flash feedback
  _SeekFlash _seekFlash = _SeekFlash.none;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _showControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _flashTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _showControls({bool autoHide = true}) {
    _anim.forward();
    _hideTimer?.cancel();
    if (autoHide) {
      _hideTimer = Timer(const Duration(seconds: 3), _hideControls);
    }
  }

  void _hideControls() {
    _anim.reverse();
  }

  void _toggleControls() {
    if (_anim.isCompleted || _anim.isAnimating) {
      _hideTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _onDoubleTapLeft() {
    final vm = context.read<VideoPlayerViewModel>();
    vm.seekBackward(const Duration(seconds: 10));
    setState(() => _seekFlash = _SeekFlash.backward);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFlash = _SeekFlash.none);
    });
    _showControls();
  }

  void _onDoubleTapRight() {
    final vm = context.read<VideoPlayerViewModel>();
    vm.seekForward(const Duration(seconds: 10));
    setState(() => _seekFlash = _SeekFlash.forward);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFlash = _SeekFlash.none);
    });
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video surface — AbsorbPointer so BetterPlayer never eats our gestures
        Selector<VideoPlayerViewModel, BetterPlayerController?>(
          selector: (_, vm) => vm.controller,
          builder: (_, controller, _) => AbsorbPointer(
            child: controller == null
                ? const ColoredBox(color: Colors.black)
                : SizedBox.expand(child: BetterPlayer(controller: controller)),
          ),
        ),

        // 2. Tap / double-tap gesture layer
        _GestureLayer(
          onTap: _toggleControls,
          onDoubleTapLeft: _onDoubleTapLeft,
          onDoubleTapRight: _onDoubleTapRight,
          onDrag: (_showControls),
        ),

        // 3. Seek flash feedback (no controls dependency)
        if (_seekFlash != _SeekFlash.none)
          _SeekFlashOverlay(direction: _seekFlash),

        // 4. Controls overlay (fades in/out)
        FadeTransition(
          opacity: _fade,
          child: IgnorePointer(
            ignoring: false,
            child: _ControlsOverlay(
              onBack: widget.onBack,
              chapterName: widget.chapterName,
              onShowControls: _showControls,
            ),
          ),
        ),

        // 5. Buffering spinner — always visible, not part of controls
        Selector<VideoPlayerViewModel, bool>(
          selector: (_, vm) =>
              vm.state == VideoPlayerState.loading ||
              vm.state == VideoPlayerState.buffering,
          builder: (_, show, _) =>
              show ? const _LoadingOverlay() : const SizedBox.shrink(),
        ),

        // 6. Error overlay
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
      ],
    );
  }
}

enum _SeekFlash { none, forward, backward }

// ─────────────────────────────────────────────────────────────────────────────
// _GestureLayer — single-tap + double-tap detection with side zones
// ─────────────────────────────────────────────────────────────────────────────

class _GestureLayer extends StatelessWidget {
  const _GestureLayer({
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onDrag,
  });

  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final VoidCallback onDrag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      return Stack(
        children: [
          // Left double-tap zone
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: w / 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onDoubleTapLeft,
              onTap: onTap,
            ),
          ),
          // Center / full single-tap
          Positioned(
            left: w / 3, top: 0, bottom: 0,
            width: w / 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
            ),
          ),
          // Right double-tap zone
          Positioned(
            right: 0, top: 0, bottom: 0,
            width: w / 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onDoubleTapRight,
              onTap: onTap,
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeekFlashOverlay — quick +10s / -10s visual feedback
// ─────────────────────────────────────────────────────────────────────────────

class _SeekFlashOverlay extends StatelessWidget {
  const _SeekFlashOverlay({required this.direction});

  final _SeekFlash direction;

  @override
  Widget build(BuildContext context) {
    final isForward = direction == _SeekFlash.forward;
    return Align(
      alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width / 3,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: isForward ? Alignment.centerLeft : Alignment.centerRight,
            radius: 1.2,
            colors: [Colors.white24, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isForward
                  ? Icons.fast_forward_rounded
                  : Icons.fast_rewind_rounded,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 4),
            const Text(
              '10 sec',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ControlsOverlay — top bar + center controls + bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.onBack,
    required this.chapterName,
    required this.onShowControls,
  });

  final VoidCallback onBack;
  final String chapterName;
  final VoidCallback onShowControls;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top gradient + bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: _TopBar(onBack: onBack, chapterName: chapterName),
        ),

        // Center play/pause + skip
        const Center(child: _CenterControls()),

        // Bottom gradient + bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomBar(onShowControls: onShowControls),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopBar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.chapterName});

  final VoidCallback onBack;
  final String chapterName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left: back + chapter/title
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
                const SizedBox(width: 6),
                Expanded(
                  child: Selector<VideoPlayerViewModel, VideoItemModel?>(
                    selector: (_, vm) => vm.currentVideo,
                    builder: (_, video, _) {
                      final chapter = chapterName.isNotEmpty
                          ? chapterName
                          : (video?.seriesSlug ?? '');
                      final title = video?.title ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chapter.isNotEmpty)
                            Text(
                              chapter.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (title.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                // Spacer to push logo to center — logo is in Stack center
                const SizedBox(width: 80),
              ],
            ),

            // Center: Ekluvya logo
            Image.asset(
              'assets/icons/logo.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const SizedBox.shrink(),
            ),

            // Right: cast button
            Positioned(
              right: 0,
              child: _IconBtn(
                icon: Icons.cast_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cast feature coming soon'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CenterControls — play/pause + ±10s skip
// ─────────────────────────────────────────────────────────────────────────────

class _CenterControls extends StatelessWidget {
  const _CenterControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rewind
        _SkipButton(
          icon: Icons.fast_rewind_rounded,
          label: '10',
          onTap: () => context.read<VideoPlayerViewModel>()
              .seekBackward(const Duration(seconds: 10)),
        ),
        const SizedBox(width: 28),

        // Play / Pause
        Selector<VideoPlayerViewModel, VideoPlayerState>(
          selector: (_, vm) => vm.state,
          builder: (ctx, state, _) {
            final isPlaying = state == VideoPlayerState.playing;
            final isLoading = state == VideoPlayerState.loading ||
                state == VideoPlayerState.buffering;
            return GestureDetector(
              onTap: isLoading
                  ? null
                  : () => context.read<VideoPlayerViewModel>().togglePlayPause(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: Icon(
                  isLoading
                      ? Icons.hourglass_empty_rounded
                      : (isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  color: Colors.white,
                  size: 36,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 28),

        // Forward
        _SkipButton(
          icon: Icons.fast_forward_rounded,
          label: '10',
          onTap: () => context.read<VideoPlayerViewModel>()
              .seekForward(const Duration(seconds: 10)),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomBar — seek bar + all controls
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onShowControls});

  final VoidCallback onShowControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 32, 12, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar row
            Selector<VideoPlayerViewModel, BetterPlayerController?>(
              selector: (_, vm) => vm.controller,
              builder: (_, controller, _) {
                if (controller?.videoPlayerController == null) {
                  return const _StaticSeekBar();
                }
                return ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller!.videoPlayerController!,
                  builder: (ctx, value, _) {
                    final pos = value.position;
                    final dur = value.duration ?? Duration.zero;
                    final buffered = _maxBuffered(value.buffered, dur);
                    final progress = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;
                    return _GradientSeekBar(
                      progress: progress,
                      buffered: buffered,
                      onSeek: (p) {
                        controller.seekTo(
                          Duration(milliseconds: (dur.inMilliseconds * p).round()),
                        );
                        onShowControls();
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 6),

            // Time + action buttons row
            Row(
              children: [
                // Time
                Selector<VideoPlayerViewModel, BetterPlayerController?>(
                  selector: (_, vm) => vm.controller,
                  builder: (_, controller, _) {
                    if (controller?.videoPlayerController == null) {
                      return const Text('00:00 / 00:00',
                          style: TextStyle(color: Colors.white70, fontSize: 12));
                    }
                    return ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller!.videoPlayerController!,
                      builder: (_, value, _) => Text(
                        '${_fmt(value.position)} / ${_fmt(value.duration ?? Duration.zero)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(),

                // Rating
                const _RatingButton(),
                const SizedBox(width: 4),

                // Previous episode
                Selector<VideoPlayerViewModel, bool>(
                  selector: (_, vm) => vm.hasPrevious,
                  builder: (ctx, hasPrev, _) => hasPrev
                      ? _IconBtn(
                          icon: Icons.skip_previous_rounded,
                          onTap: () =>
                              context.read<VideoPlayerViewModel>().playPrevious(),
                          size: 22,
                        )
                      : const SizedBox.shrink(),
                ),

                // Next episode
                Selector<VideoPlayerViewModel, bool>(
                  selector: (_, vm) => vm.hasNext,
                  builder: (ctx, hasNext, _) => hasNext
                      ? _IconBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: () =>
                              context.read<VideoPlayerViewModel>().playNext(),
                          size: 22,
                        )
                      : const SizedBox.shrink(),
                ),

                // Episodes list
                Selector<VideoPlayerViewModel, bool>(
                  selector: (_, vm) => vm.playlist.isNotEmpty,
                  builder: (ctx, hasPlaylist, _) => hasPlaylist
                      ? _IconBtn(
                          icon: Icons.playlist_play_rounded,
                          onTap: () => _showEpisodesSheet(ctx),
                          size: 22,
                        )
                      : const SizedBox.shrink(),
                ),

                // Speed
                _SpeedButton(onShowControls: onShowControls),

                // Audio & Subtitles
                _TextBtn(
                  label: 'Audio & Subs',
                  onTap: () => _showAudioSubsSheet(context),
                ),

                // Quality
                _IconBtn(
                  icon: Icons.settings_rounded,
                  onTap: () => _showQualitySheet(context),
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static double _maxBuffered(List<dynamic> buffered, Duration duration) {
    if (buffered.isEmpty || duration.inMilliseconds <= 0) return 0.0;
    var maxEndMs = 0;
    for (final range in buffered) {
      final endMs = (range.end as Duration).inMilliseconds;
      if (endMs > maxEndMs) maxEndMs = endMs;
    }
    return (maxEndMs / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static void _showEpisodesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider<VideoPlayerViewModel>.value(
        value: context.read<VideoPlayerViewModel>(),
        child: const _EpisodesSheet(),
      ),
    );
  }

  static void _showAudioSubsSheet(BuildContext context) {
    final vm = context.read<VideoPlayerViewModel>();
    final controller = vm.controller;
    if (controller == null) return;

    final audioTracks = controller.betterPlayerAsmsAudioTracks ?? <BetterPlayerAsmsAudioTrack>[];
    final subtitleSources = controller.betterPlayerSubtitlesSourceList;
    final hasAudio = audioTracks.length > 1;
    final hasSubs = subtitleSources.isNotEmpty;

    if (!hasAudio && !hasSubs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No alternate audio tracks or subtitles available'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AudioSubsSheet(
        controller: controller,
        audioTracks: audioTracks,
        subtitleSources: subtitleSources,
      ),
    );
  }

  static void _showQualitySheet(BuildContext context) {
    final vm = context.read<VideoPlayerViewModel>();
    final controller = vm.controller;
    if (controller == null) return;

    final tracks = controller.betterPlayerAsmsTracks;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quality selection not available for this video'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _QualitySheet(controller: controller, tracks: tracks),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GradientSeekBar — custom painted seek bar with gradient
// ─────────────────────────────────────────────────────────────────────────────

class _GradientSeekBar extends StatefulWidget {
  const _GradientSeekBar({
    required this.progress,
    required this.buffered,
    required this.onSeek,
  });

  final double progress;
  final double buffered;
  final void Function(double) onSeek;

  @override
  State<_GradientSeekBar> createState() => _GradientSeekBarState();
}

class _GradientSeekBarState extends State<_GradientSeekBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final display = _dragging ? _dragValue : widget.progress;
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          setState(() {
            _dragging = true;
            _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
          });
        },
        onHorizontalDragUpdate: (d) {
          setState(() {
            _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
          });
        },
        onHorizontalDragEnd: (_) {
          widget.onSeek(_dragValue);
          setState(() => _dragging = false);
        },
        onTapDown: (d) {
          final p = (d.localPosition.dx / w).clamp(0.0, 1.0);
          widget.onSeek(p);
        },
        child: SizedBox(
          height: 28,
          width: w,
          child: CustomPaint(
            painter: _SeekBarPainter(
              progress: display,
              buffered: widget.buffered,
              dragging: _dragging,
            ),
          ),
        ),
      );
    });
  }
}

class _StaticSeekBar extends StatelessWidget {
  const _StaticSeekBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _SeekBarPainter(progress: 0, buffered: 0, dragging: false),
      ),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  _SeekBarPainter({
    required this.progress,
    required this.buffered,
    required this.dragging,
  });

  final double progress;
  final double buffered;
  final bool dragging;

  static const _trackH = 3.0;
  static const _thumbR = 6.0;
  static const _thumbRActive = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final trackRect = Rect.fromLTWH(0, y - _trackH / 2, size.width, _trackH);
    const rr = Radius.circular(2);

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, rr),
      Paint()..color = Colors.white24,
    );

    // Buffered
    if (buffered > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y - _trackH / 2, size.width * buffered, _trackH),
          rr,
        ),
        Paint()..color = Colors.white38,
      );
    }

    // Played — gradient
    final playedW = math.max(0.0, size.width * progress);
    if (playedW > 0) {
      final playedRect =
          Rect.fromLTWH(0, y - _trackH / 2, playedW, _trackH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(playedRect, rr),
        Paint()
          ..shader = const LinearGradient(
            colors: [_kBrand, _kBrandOrange],
          ).createShader(Rect.fromLTWH(0, 0, size.width, _trackH)),
      );
    }

    // Thumb
    final thumbX = size.width * progress;
    final thumbR = dragging ? _thumbRActive : _thumbR;
    canvas.drawCircle(
      Offset(thumbX, y),
      thumbR,
      Paint()..color = _kBrand,
    );
    if (dragging) {
      canvas.drawCircle(
        Offset(thumbX, y),
        thumbR + 3,
        Paint()
          ..color = _kBrand.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.dragging != dragging;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RatingButton
// ─────────────────────────────────────────────────────────────────────────────

class _RatingButton extends StatelessWidget {
  const _RatingButton();

  @override
  Widget build(BuildContext context) {
    return Selector<VideoPlayerViewModel, double>(
      selector: (_, vm) => vm.userRating,
      builder: (ctx, rating, _) {
        return GestureDetector(
          onTap: () => _showRatingPicker(ctx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${rating == rating.floorToDouble() ? rating.toInt() : rating.toStringAsFixed(1)}/5',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRatingPicker(BuildContext context) {
    final vm = context.read<VideoPlayerViewModel>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider<VideoPlayerViewModel>.value(
        value: vm,
        child: const _RatingSheet(),
      ),
    );
  }
}

class _RatingSheet extends StatelessWidget {
  const _RatingSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Rate this video',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Selector<VideoPlayerViewModel, double>(
            selector: (_, vm) => vm.userRating,
            builder: (ctx, rating, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () {
                    context.read<VideoPlayerViewModel>().setUserRating(star.toDouble());
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpeedButton
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.onShowControls});

  final VoidCallback onShowControls;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onShowControls();
        _showSheet(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.speed_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final vm = context.read<VideoPlayerViewModel>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _SpeedSheet(
        speeds: _speeds,
        onSelect: (speed) {
          vm.controller?.setSpeed(speed);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.speeds, required this.onSelect});

  final List<double> speeds;
  final void Function(double) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Playback Speed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ...speeds.map((s) => ListTile(
            title: Text(
              s == 1.0 ? 'Normal (1x)' : '${s}x',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => onSelect(s),
            trailing: s == 1.0
                ? const Icon(Icons.check_rounded, color: _kBrand)
                : null,
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EpisodesSheet
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodesSheet extends StatelessWidget {
  const _EpisodesSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoPlayerViewModel>(
      builder: (ctx, vm, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Episodes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${vm.currentIndex + 1} / ${vm.playlist.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: vm.playlist.length,
              itemBuilder: (_, i) {
                final ep = vm.playlist[i];
                final isCurrent = i == vm.currentIndex;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent ? _kBrand : Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    ep.title,
                    style: TextStyle(
                      color: isCurrent ? _kBrand : Colors.white,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: ep.formattedDuration.isNotEmpty
                      ? Text(
                          ep.formattedDuration,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        )
                      : null,
                  trailing: isCurrent
                      ? const Icon(Icons.play_circle_filled_rounded,
                          color: _kBrand, size: 22)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    vm.playAt(i);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AudioSubsSheet
// ─────────────────────────────────────────────────────────────────────────────

class _AudioSubsSheet extends StatelessWidget {
  const _AudioSubsSheet({
    required this.controller,
    required this.audioTracks,
    required this.subtitleSources,
  });

  final BetterPlayerController controller;
  final List<BetterPlayerAsmsAudioTrack> audioTracks;
  final List<BetterPlayerSubtitlesSource> subtitleSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (audioTracks.length > 1) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Audio Track',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            ...audioTracks.map((t) => ListTile(
              title: Text(t.label ?? 'Track ${audioTracks.indexOf(t) + 1}',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                controller.setAudioTrack(t);
                Navigator.pop(context);
              },
            )),
          ],
          if (subtitleSources.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Subtitles',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              title: const Text('Off', style: TextStyle(color: Colors.white)),
              onTap: () {
                controller.setupSubtitleSource(
                  BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
                );
                Navigator.pop(context);
              },
            ),
            ...subtitleSources.map((s) => ListTile(
              title: Text(s.name ?? 'Subtitle ${subtitleSources.indexOf(s) + 1}',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                controller.setupSubtitleSource(s);
                Navigator.pop(context);
              },
            )),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QualitySheet
// ─────────────────────────────────────────────────────────────────────────────

class _QualitySheet extends StatelessWidget {
  const _QualitySheet({required this.controller, required this.tracks});

  final BetterPlayerController controller;
  final List<BetterPlayerAsmsTrack> tracks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text('Video Quality',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            title: const Text('Auto', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Adaptive bitrate', style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () {
              controller.setTrack(BetterPlayerAsmsTrack.defaultTrack());
              Navigator.pop(context);
            },
          ),
          ...tracks.where((t) => t.height != null && t.height! > 0).map((t) {
            final label = _qualityLabel(t);
            return ListTile(
              title: Text(label, style: const TextStyle(color: Colors.white)),
              subtitle: t.bitrate != null
                  ? Text('${(t.bitrate! / 1000).toStringAsFixed(0)} kbps',
                      style: const TextStyle(color: Colors.white38, fontSize: 12))
                  : null,
              onTap: () {
                controller.setTrack(t);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _qualityLabel(BetterPlayerAsmsTrack t) {
    final h = t.height ?? 0;
    if (h >= 1080) return '1080p HD';
    if (h >= 720) return '720p HD';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    if (h >= 240) return '240p';
    return '${h}p';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.size = 24});

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(
          color: _kBrand,
          strokeWidth: 3,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error overlay
// ─────────────────────────────────────────────────────────────────────────────

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
              const Icon(Icons.error_outline_rounded, color: _kBrand, size: 48),
              const SizedBox(height: 16),
              Text(
                message ?? 'Playback failed. Please check your connection.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: const Text('Try again', style: TextStyle(color: Colors.white, fontSize: 14)),
                style: TextButton.styleFrom(
                  backgroundColor: _kBrand,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
