import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/video_item_model.dart';
import '../../../class_subject/presentation/view/content_card_widget.dart';
import '../../../video_player/data/remote/watch_api_service.dart';
import '../../../video_player/presentation/view/video_player_screen.dart';

const Color _gradPink   = Color(0xFFE91E63);
const Color _gradOrange = Color(0xFFFF5722);

/// Full video grid for a single channel partner.
///
/// Tapping a card calls the series-data API to validate access and get a fresh
/// HLS URL, then pushes [VideoPlayerScreen].
class ChannelVideosScreen extends StatefulWidget {
  const ChannelVideosScreen({
    super.key,
    required this.channel,
    this.headers = const {},
  });

  final ChannelModel channel;
  final Map<String, String> headers;

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen> {
  static const _tag = 'ChannelVideosScreen';
  final _watchApi = WatchApiService();

  // slug of the card currently being loaded — null when idle
  String? _loadingSlug;

  Future<void> _onVideoTap(VideoItemModel v) async {
    AppLogger.info(_tag, 'TAP id=${v.id} slug="${v.slug}" hls="${v.hlsUrl}"');

    if (_loadingSlug != null) {
      AppLogger.info(_tag, 'TAP debounced — already loading $_loadingSlug');
      return;
    }

    final slug = v.slug.isNotEmpty ? v.slug : null;
    final loadingKey = slug ?? v.id;

    if (slug != null) {
      setState(() => _loadingSlug = loadingKey);
      try {
        final episode = await _watchApi.fetchEpisode(slug);
        if (!mounted) return;
        await Navigator.of(context).push(
            VideoPlayerScreen.route(episode, headers: widget.headers));
      } catch (e) {
        AppLogger.error(_tag, 'Failed to load episode $slug', e);
        if (!mounted) return;
        if (v.hlsUrl.isNotEmpty) {
          await Navigator.of(context).push(
              VideoPlayerScreen.route(v, headers: widget.headers));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load video. Please try again.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loadingSlug = null);
      }
    } else if (v.hlsUrl.isNotEmpty) {
      await Navigator.of(context).push(
          VideoPlayerScreen.route(v, headers: widget.headers));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_gradPink, _gradOrange],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: topPad),
                  _Header(channel: widget.channel),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Video grid ───────────────────────────────────────────────
            Expanded(
              child: widget.channel.videos.isEmpty
                  ? const _EmptyState()
                  : _VideoGrid(
                      channel: widget.channel,
                      loadingSlug: _loadingSlug,
                      onTap: _onVideoTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.channel});

  final ChannelModel channel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  channel.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${channel.totalVideos} videos',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2-column video grid ───────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.channel,
    required this.loadingSlug,
    required this.onTap,
  });

  final ChannelModel channel;
  final String? loadingSlug;
  final void Function(VideoItemModel) onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    const hPad = 16.0;
    const gap  = 10.0;
    final cardWidth = (screenWidth - hPad * 2 - gap) / 2;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: gap,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: channel.videos.length,
      itemBuilder: (_, i) {
        final v = channel.videos[i];
        final isLoading = loadingSlug == v.slug || loadingSlug == v.id;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(v),
          child: Stack(
            children: [
              // Pass onTap:null so the inner GestureDetector doesn't compete
              ContentCardWidget(
                title: v.title,
                thumbnailUrl: v.thumbnailUrl,
                cardWidth: cardWidth,
              ),
              if (isLoading)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const ColoredBox(
                      color: Color(0x80000000),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Color(0xFFE91E63),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 48, color: Color(0xFFCCCCCC)),
            SizedBox(height: 12),
            Text(
              'No videos available yet.',
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF888888), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
