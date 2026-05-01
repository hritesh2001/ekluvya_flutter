import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../../../../features/subscription/presentation/view/subscription_plans_screen.dart';
import '../../../../features/video_access/domain/entities/video_access_status.dart';
import '../../../../features/video_access/domain/usecases/check_video_access_usecase.dart';
import '../../../../features/video_player/data/remote/watch_api_service.dart';
import '../../../../features/video_player/presentation/view/video_player_screen.dart';
import '../../data/models/watch_history_item_model.dart';
import '../viewmodel/watch_history_viewmodel.dart';

// ── Brand constants — match ContentCardWidget / channel partner screen ────────

const _kDark    = Color(0xFF1A1A1A);
const _kGray    = Color(0xFF9E9E9E);
const _kYellow  = Color(0xFFFFD600);
const _kBlue    = Color(0xFF2196F3);
const _kDivider = Color(0xFFF0F0F0);

// Match channel video grid: 16px horizontal padding, 10px gap between columns
const _kHPad       = 16.0;
const _kColGap     = 10.0;
// Thumbnail uses 16:9 ratio — same as ContentCardWidget.thumbAspect
const _kThumbRatio = 9.0 / 16.0;

// ─────────────────────────────────────────────────────────────────────────────

class WatchHistoryScreen extends StatelessWidget {
  const WatchHistoryScreen({super.key});

  static Route<void> route(BuildContext outerContext) =>
      MaterialPageRoute<void>(
        builder: (_) {
          // Reuse the global singleton VM and trigger a fresh fetch every open.
          final vm = outerContext.read<WatchHistoryViewModel>()
            ..refreshWatchHistory();
          return ChangeNotifierProvider.value(
            value: vm,
            child: const WatchHistoryScreen(),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: const _WatchHistoryBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 1),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _kDark,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My History',
          style: TextStyle(
            color: _kDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<WatchHistoryViewModel>(
            builder: (context, vm, _) {
              if (!vm.hasData || vm.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: vm.isBusy
                    ? null
                    : () => _showClearConfirm(context, vm),
                child: const Text(
                  'CLEAR ALL',
                  style: TextStyle(
                    color: _kBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.5, color: _kDivider),
        ),
      ),
    );
  }

  void _showClearConfirm(BuildContext context, WatchHistoryViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ───────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // ── Question ──────────────────────────────────────────────────
              const Text(
                'Are you sure, you want to delete all history ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // ── Buttons ───────────────────────────────────────────────────
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFEEEEEE),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Yes, Delete — brand gradient
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            vm.clearAll();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Yes, Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _WatchHistoryBody extends StatefulWidget {
  const _WatchHistoryBody();

  @override
  State<_WatchHistoryBody> createState() => _WatchHistoryBodyState();
}

class _WatchHistoryBodyState extends State<_WatchHistoryBody>
    with WidgetsBindingObserver {
  final _watchApi = WatchApiService();
  String? _loadingMediaId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WatchHistoryViewModel>().refreshWatchHistory();
    }
  }

  Future<void> _onVideoTap(WatchHistoryItemModel item) async {
    if (_loadingMediaId != null) return;

    final sessionVM = context.read<SessionViewModel>();
    final accessUC  = context.read<CheckVideoAccessUseCase>();
    final nav       = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // An unsubscribed user can only have history for a monetization-8 video if
    // it was the first (free) episode. Use episodeIndex 1 only when subscribed.
    final status = accessUC(
      episodeIndex: (item.monetization == 8 && sessionVM.isSubscribed) ? 1 : 0,
      isLoggedIn:   sessionVM.isLoggedIn,
      isSubscribed: sessionVM.isSubscribed,
      monetization: item.monetization,
    );
    switch (status) {
      case VideoAccessStatus.requiresLogin:
        nav.pushNamed('/login');
        return;
      case VideoAccessStatus.requiresSubscription:
        nav.push(SubscriptionPlansScreen.route(context));
        return;
      case VideoAccessStatus.free:
      case VideoAccessStatus.unlocked:
        break;
    }

    if (item.slug.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Video not available.')),
      );
      return;
    }

    setState(() => _loadingMediaId = item.mediaId);
    try {
      final episode = await _watchApi.fetchEpisode(item.slug);
      if (!mounted) return;
      await nav.push(VideoPlayerScreen.route(episode));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not load video. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMediaId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchHistoryViewModel>(
      builder: (context, vm, _) {
        // ── Loading ────────────────────────────────────────────────────────
        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _kYellow),
          );
        }

        // ── Error ──────────────────────────────────────────────────────────
        if (vm.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: _kGray),
                  const SizedBox(height: 12),
                  Text(
                    vm.error ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: _kGray),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: vm.load,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: _kYellow),
                    label: const Text('Retry',
                        style: TextStyle(color: _kYellow)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kYellow),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ── Empty ──────────────────────────────────────────────────────────
        if (vm.isEmpty) {
          return const _EmptyHistoryView();
        }

        // ── Grid ─────────────────────────────────────────────────────────────
        final screenWidth = MediaQuery.sizeOf(context).width;
        final cardWidth   = (screenWidth - _kHPad * 2 - _kColGap) / 2;
        // Cell height = 16:9 thumb + 6px gap + 2 title lines (14px × 1.4 × 2)
        final cellHeight  = cardWidth * _kThumbRatio + 6 + 14.0 * 1.4 * 2 + 6;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
              _kHPad, 16, _kHPad, 24),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _kColGap,
            mainAxisSpacing: 10,
            mainAxisExtent: cellHeight,
          ),
          itemCount: vm.items.length,
          itemBuilder: (context, index) {
            final item = vm.items[index];
            return _HistoryCard(
              item: item,
              cardWidth: cardWidth,
              onRemove: () => vm.removeItem(item.mediaId),
              onPlay: () => _onVideoTap(item),
              isLoading: _loadingMediaId == item.mediaId,
            );
          },
        );
      },
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.cardWidth,
    required this.onRemove,
    required this.onPlay,
    required this.isLoading,
  });

  final WatchHistoryItemModel item;
  final double cardWidth;
  final VoidCallback onRemove;
  final VoidCallback onPlay;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // 16:9 thumbnail — same ratio as ContentCardWidget.thumbAspect
    final thumbHeight = cardWidth * _kThumbRatio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onPlay,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Thumbnail + overlays ──────────────────────────────────────────
        SizedBox(
          width: cardWidth,
          height: thumbHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12), // matches ContentCardWidget
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail image
                _Thumbnail(url: item.thumbnailUrl),

                // Bottom gradient
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // ▶ Resume — bottom-left
                const Positioned(
                  left: 8,
                  bottom: 18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 2),
                      Text(
                        'Resume',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time left — bottom-right
                Positioned(
                  right: 8,
                  bottom: 18,
                  child: Text(
                    item.remainingLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Yellow progress bar — very bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ProgressBar(fraction: item.progressFraction),
                ),

                // Loading overlay — shown while fetchEpisode is in progress
                if (isLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x80000000),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: _kYellow,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                // X remove button — top-right
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // ── Title — matches ContentCardWidget typography ───────────────────
        Text(
          item.title.isNotEmpty ? item.title : '—',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _kDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
      ),
    );
  }
}

// ── Thumbnail widget ──────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});
  final String url;

  static const _bg = Color(0xFFF0F0F0);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: _bg,
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Color(0xFFBBBBBB), size: 28),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: _bg),
      errorWidget: (context, url, err) => Container(
        color: _bg,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Color(0xFFBBBBBB), size: 24),
        ),
      ),
    );
  }
}

// ── Empty history view ────────────────────────────────────────────────────────

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon ──────────────────────────────────────────────────────────
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer blob
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEDF4),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                // Document stack icon
                const Icon(
                  Icons.description_outlined,
                  size: 46,
                  color: Color(0xFF8B9DC8),
                ),
                // Small badge — bottom-right
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B8FCF), Color(0xFF9BAAD8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Headline ──────────────────────────────────────────────────────
          const Text(
            'Check back later',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),

          const SizedBox(height: 8),

          // ── Subtitle ──────────────────────────────────────────────────────
          const Text(
            'You do not have any viewing history!',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9E9E9E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total  = constraints.maxWidth;
        final filled = (total * fraction).clamp(0.0, total);
        return SizedBox(
          height: 3,
          child: Stack(
            children: [
              Container(color: Colors.white24),
              Container(width: filled, color: _kYellow),
            ],
          ),
        );
      },
    );
  }
}
