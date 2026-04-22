import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/logger.dart';
import '../../../../features/badge/domain/repositories/badge_repository.dart';
import '../../../../features/badge/presentation/viewmodel/badge_viewmodel.dart';
import '../../../../features/channel/data/models/channel_model.dart';
import '../../../../features/channel/data/models/video_item_model.dart';
import '../../../../features/channel/domain/repositories/channel_repository.dart';
import '../../../../features/channel/presentation/view/channel_videos_screen.dart';
import '../../../../features/channel/presentation/viewmodel/channel_viewmodel.dart';
import '../../../../features/rating/domain/repositories/rating_repository.dart';
import '../../../../features/rating/presentation/viewmodel/rating_viewmodel.dart';
import '../../../../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../../../../features/video_access/domain/entities/video_access_status.dart';
import '../../../../features/video_access/domain/usecases/check_video_access_usecase.dart';
import '../../../../features/signed_cookie/domain/repositories/signed_cookie_repository.dart';
import '../../../../features/signed_cookie/presentation/viewmodel/signed_cookie_viewmodel.dart';
import '../../../../features/video_player/data/remote/watch_api_service.dart';
import '../../../../features/video_player/presentation/view/video_player_screen.dart';
import '../../domain/repositories/class_subject_repository.dart';
import '../viewmodel/class_subject_viewmodel.dart';
import 'chapter_filter_widget.dart';
import 'class_selector_widget.dart';
import 'content_section_widget.dart';
import '../../../../features/search/presentation/view/search_screen.dart';
import '../../../../features/explore/presentation/view/explore_screen.dart';
import 'subject_chips_widget.dart';
import '../../../../../widgets/app_toast.dart';
import '../../../../../widgets/custom_bottom_nav_bar.dart';
import '../../../profile/presentation/view/edit_profile_screen.dart';
import '../../../subscription/presentation/view/subscription_plans_screen.dart';

// ── Brand gradient — exactly matches the EKLUVYA logo colours ─────────────────
//   Deep orange (#FF5722) on the left → brand pink (#E91E63) on the right.
const Color _gradOrange = Color(0xFFFF5722);
const Color _gradPink   = Color(0xFFE91E63);

// ─────────────────────────────────────────────────────────────────────────────

/// OTT-style course detail screen — pixel-matched to the provided design.
///
/// Header band (orange → pink gradient, 3 rows):
///   Row 1 — ≡  [app-logo.png icon]  EKLUVYA
///   Row 2 — IIT FOUNDATION (left)   CLASS 7 ▼ (right, no border)
///   Row 3 — Subject chips (TAMIL · PHYSICS · CHEMISTRY …)
///
/// Below the gradient (white surface):
///   Row 4 — Chapters  [BASIC MATHEMATICS ▼]
///   Rows 5+ — Scrollable content sections
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.courseImageUrl = '',
  });

  final String courseId;
  final String courseTitle;
  final String courseImageUrl;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    // Enforce portrait + visible system UI when this screen first mounts.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.isCurrent becomes true when a route on top of this one pops
    // (e.g. video player closes). Re-enforce portrait + edgeToEdge here so
    // that even if _restoreSystemChrome() in the video player raced with the
    // route transition, this screen always ends up in the correct state.
    if (ModalRoute.of(context)?.isCurrent == true) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Post-frame re-enforcement: the platform-channel response for
      // setEnabledSystemUIMode can arrive one frame after the route
      // becomes current.  Calling it again + triggering setState ensures
      // the Scaffold re-reads MediaQuery.padding.bottom and repositions
      // the bottom nav bar as soon as the system nav bar reappears.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => ClassSubjectViewModel(
            repository: ctx.read<ClassSubjectRepository>(),
            courseId: widget.courseId,
            courseTitle: widget.courseTitle,
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChannelViewModel(
            repository: ctx.read<ChannelRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => BadgeViewModel(
            repository: ctx.read<BadgeRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => RatingViewModel(
            repository: ctx.read<RatingRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SignedCookieViewModel(
            repository: ctx.read<SignedCookieRepository>(),
          ),
        ),
      ],
      child: _CourseDetailShell(
        courseTitle: widget.courseTitle,
        navIndex: _navIndex,
        onNavTapped: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ── Shell — holds navbar + tab pages ─────────────────────────────────────────

class _CourseDetailShell extends StatefulWidget {
  const _CourseDetailShell({
    required this.courseTitle,
    required this.navIndex,
    required this.onNavTapped,
  });

  final String courseTitle;
  final int navIndex;
  final ValueChanged<int> onNavTapped;

  @override
  State<_CourseDetailShell> createState() => _CourseDetailShellState();
}

class _CourseDetailShellState extends State<_CourseDetailShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drawerCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double>  _fadeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drawerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Drawer slides in from the left.
    _slideAnim = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic));
    // Overlay fades from transparent to 55 % black.
    _fadeAnim = Tween<double>(begin: 0, end: 0.55)
        .animate(CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drawerCtrl.dispose();
    super.dispose();
  }

  // Fired the instant the window insets change — e.g. when the system
  // navigation bar reappears after exiting the immersive video player.
  // setState forces Scaffold to re-read MediaQuery.padding.bottom and
  // reposition the bottom nav bar before the user sees the next frame.
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  void _openDrawer()  => _drawerCtrl.forward();
  void _closeDrawer() => _drawerCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main screen ──────────────────────────────────────────────
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: Colors.white,
            extendBody: true,
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: widget.navIndex,
              onItemTapped: widget.onNavTapped,
              // Smart home FAB:
              //   • On Search / Explore / Bookmark tab → switch back to Course
              //     tab (tab 0).  IndexedStack keeps all children alive, so the
              //     exact partner, chapter, scroll position are all restored with
              //     zero reload.
              //   • Already on Course tab → pop back to the courses landing page
              //     (HomeScreen) so the user can pick a different course.
              onHomeTapped: () {
                if (widget.navIndex > 0) {
                  widget.onNavTapped(0);
                } else {
                  Navigator.of(context).popUntil(
                    (route) =>
                        route.settings.name == '/home' || route.isFirst,
                  );
                }
              },
            ),
            body: IndexedStack(
              index: widget.navIndex,
              children: [
                _CourseContent(
                  courseTitle: widget.courseTitle,
                  onMenuTap: _openDrawer,
                  drawerAnim: _drawerCtrl,
                ),
                const SearchScreen(),
                const ExploreScreen(),
                const _NavPlaceholder(icon: Icons.bookmark_border_rounded, label: 'Bookmarks'),
              ],
            ),
          ),
        ),

        // ── Semi-transparent dim overlay ─────────────────────────────
        // Rendered only while the drawer is visible so there is zero
        // overhead when it is closed.
        AnimatedBuilder(
          animation: _drawerCtrl,
          builder: (_, _) {
            if (_drawerCtrl.isDismissed) return const SizedBox.shrink();
            return GestureDetector(
              onTap: _closeDrawer,
              child: ColoredBox(
                color: Color.fromRGBO(0, 0, 0, _fadeAnim.value),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),

        // ── Sliding drawer panel ─────────────────────────────────────
        SlideTransition(
          position: _slideAnim,
          child: Align(
            alignment: Alignment.topLeft,
            child: _DrawerPanel(onClose: _closeDrawer),
          ),
        ),
      ],
    );
  }
}

// ── Course content tab ────────────────────────────────────────────────────────

class _CourseContent extends StatelessWidget {
  const _CourseContent({
    required this.courseTitle,
    required this.onMenuTap,
    required this.drawerAnim,
  });

  final String courseTitle;
  final VoidCallback onMenuTap;
  final Animation<double> drawerAnim;

  @override
  Widget build(BuildContext context) {
    // Read directly so this widget re-renders with the live value whenever
    // MediaQuery updates (e.g. after orientation restores from landscape).
    final topPad = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Rows 1-3: gradient header band ─────────────────────────
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
              _BrandRow(onMenuTap: onMenuTap, drawerAnim: drawerAnim),
              _CourseTitleRow(courseTitle: courseTitle),
              const SizedBox(height: 2),
              const SubjectChipsWidget(),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ── Row 4: chapter filter ───────────────────────────────────
        const ColoredBox(
          color: Colors.white,
          child: _ChapterFilterRow(),
        ),

        // ── Rows 5+: partner/channel sections ──────────────────────
        const Expanded(child: _ContentScrollView()),
      ],
    );
  }
}

// ── Placeholder tab ───────────────────────────────────────────────────────────

class _NavPlaceholder extends StatelessWidget {
  const _NavPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(
            '$label coming soon',
            style: const TextStyle(fontSize: 15, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}

// ── Row 1 — Brand row ─────────────────────────────────────────────────────────

/// ≡   [app-logo icon]  EKLUVYA   (blank balance)
///
/// The icon is rendered with a white colour filter so it reads on the gradient.
/// "EKLUVYA" is white with wide letter-spacing, matching the design.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.onMenuTap, required this.drawerAnim});
  final VoidCallback onMenuTap;
  final Animation<double> drawerAnim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Menu icon — hamburger when closed, X when open ──────────
          GestureDetector(
            onTap: onMenuTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedBuilder(
                animation: drawerAnim,
                builder: (_, _) => drawerAnim.value > 0.5
                    ? const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24)
                    : Image.asset(
                        'assets/icons/hamburger-menu.png',
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
              ),
            ),
          ),

          // ── Centred logo + wordmark ────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon (app-logo.png) tinted white
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/icons/app-logo.png',
                    width: 26,
                    height: 26,
                  ),
                ),

                const SizedBox(width: 8),

                // "EKLUVYA" wordmark
                const Text(
                  'EKLUVYA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Right balance (same width as hamburger) ────────────────
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

// ── Row 2 — Course title + class selector ─────────────────────────────────────

/// IIT FOUNDATION (bold white, left)          CLASS 7 ▼ (right, no border)
class _CourseTitleRow extends StatelessWidget {
  const _CourseTitleRow({required this.courseTitle});
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Course title — left aligned, bold, expands
          Expanded(
            child: Text(
              courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Class selector — no border, plain text + chevron
          const ClassSelectorWidget(),
        ],
      ),
    );
  }
}

// ── Row 4 — Chapter filter (white background) ─────────────────────────────────

/// "Chapters"  [BASIC MATHEMATICS ▼]
///
/// Sits on the white surface below the gradient — uses dark text/chips.
class _ChapterFilterRow extends StatelessWidget {
  const _ChapterFilterRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ChapterFilterWidget(),
    );
  }
}

// ── Content scroll view — real API data ───────────────────────────────────────

/// Stateful so it can track the last-loaded filter params and trigger
/// [ChannelViewModel.load] when the subject or class selection changes —
/// without calling setState/notifyListeners during a build frame.
class _ContentScrollView extends StatefulWidget {
  const _ContentScrollView();

  @override
  State<_ContentScrollView> createState() => _ContentScrollViewState();
}

class _ContentScrollViewState extends State<_ContentScrollView> {
  static const _tag = 'CourseDetailScreen';
  final _watchApi = WatchApiService();
  final _scrollCtrl = ScrollController();
  String? _loadingId;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onItemTap(ContentItemData item) async {
    AppLogger.info(_tag,
        'TAP id=${item.id} slug="${item.slug}" hls="${item.hlsUrl}"');
    if (_loadingId != null) return;

    // Capture ALL context-derived values synchronously before any await.
    // This satisfies `use_build_context_synchronously` for the entire method.
    final sessionVM = context.read<SessionViewModel>();
    final cookieStr = context.read<SignedCookieViewModel>().cookieHeader;
    final nav       = Navigator.of(context);

    final cookieHeaders = cookieStr.isNotEmpty
        ? <String, String>{'Cookie': cookieStr}
        : <String, String>{};

    // Route on the domain-computed access status — no ad-hoc boolean logic here.
    switch (item.accessStatus) {
      case VideoAccessStatus.free:
      case VideoAccessStatus.unlocked:
        break; // fall through to playback

      case VideoAccessStatus.requiresLogin:
        sessionVM.setPendingVideo(
          VideoItemModel(
            id: item.id,
            title: item.title,
            description: '',
            hlsUrl: item.hlsUrl,
            durationSeconds: 0,
            viewCount: 0,
            episodeIndex: item.episodeIndex,
            thumbnailUrl: item.thumbnailUrl,
            slug: item.slug,
            seriesSlug: '',
            isSubscription: true,
            isUserSubscribed: false,
            isYellowStrip: false,
            monetization: 1,
          ),
          cookieHeaders,
        );
        if (mounted) nav.pushNamed('/login');
        return;

      case VideoAccessStatus.requiresSubscription:
        if (mounted) nav.push(SubscriptionPlansScreen.route(context));
        return;
    }

    // Prefer fetching fresh episode data via slug (validates access + fresh URL).
    if (item.slug.isNotEmpty) {
      setState(() => _loadingId = item.id);
      try {
        final episode = await _watchApi.fetchEpisode(item.slug);
        if (!mounted) return;
        await nav.push(VideoPlayerScreen.route(episode, headers: cookieHeaders));
        return;
      } catch (e) {
        AppLogger.error(_tag, 'Episode fetch failed, trying direct play: $e');
      } finally {
        if (mounted) setState(() => _loadingId = null);
      }
    }

    // Fallback: play directly with the HLS URL from the channel-list.
    if (item.hlsUrl.isNotEmpty) {
      if (!mounted) return;
      final video = VideoItemModel(
        id: item.id,
        title: item.title,
        description: '',
        hlsUrl: item.hlsUrl,
        durationSeconds: 0,
        viewCount: 0,
        episodeIndex: item.episodeIndex,
        thumbnailUrl: item.thumbnailUrl,
        slug: item.slug,
        seriesSlug: '',
        isSubscription: false,
        isUserSubscribed: false,
        isYellowStrip: false,
        monetization: 0,
      );
      await nav.push(VideoPlayerScreen.route(video, headers: cookieHeaders));
      return;
    }

    AppLogger.warning(_tag, 'No playable URL for item ${item.id}');
  }

  /// Converts a [ChannelModel] → [ContentSectionData], enriched with
  /// badge (Most Loved / Most Watched) and rating data.
  ContentSectionData _toSection(
    ChannelModel ch,
    BadgeViewModel badgeVM,
    RatingViewModel ratingVM,
  ) {
    final sessionVM = context.read<SessionViewModel>();
    final accessUC  = context.read<CheckVideoAccessUseCase>();

    // Use the video's POSITION in this partner's list (0 = first = always free),
    // NOT v.episodeIndex which is a global API field and is never reliably 0.
    final items = ch.videos.asMap().entries.map((entry) {
      final listPos = entry.key;   // 0 for first video, 1, 2… for the rest
      final v       = entry.value;
      return ContentItemData(
        id: v.id,
        slug: v.slug,
        hlsUrl: v.hlsUrl,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        episodeIndex: v.episodeIndex,
        accessStatus: accessUC(
          episodeIndex: listPos,
          isLoggedIn: sessionVM.isLoggedIn,
          isSubscribed: sessionVM.isSubscribed,
        ),
      );
    }).toList();

    final rating = ratingVM.ratingForChannel(ch.id);

    return ContentSectionData(
      id: ch.id,
      sourceName: ch.title,
      videoCount: ch.totalVideos,
      items: items,
      badges: badgeVM.badgesForChannel(ch.id),
      rating: rating > 0 ? rating : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-render whenever login / subscription state changes so lock icons and
    // FREE badges reflect the current session without requiring a full reload.
    context.watch<SessionViewModel>();

    return Consumer<SignedCookieViewModel>(
      builder: (ctx, signedCookieVM, _) =>
        Consumer4<ClassSubjectViewModel, ChannelViewModel, BadgeViewModel,
            RatingViewModel>(
          builder: (ctx, csVM, channelVM, badgeVM, ratingVM, _) {
        // ── Show class-level error when no class loaded yet ──────────────
        if (csVM.classesHasError && csVM.selectedClass == null) {
          return _ErrorState(
            message: csVM.classesError ?? 'Could not load classes.',
            onRetry: csVM.retryClasses,
          );
        }

        // ── Trigger channel / badge / rating / signed-cookie loads ───────
        final classId   = csVM.selectedClass?.id;
        final subjectId = csVM.selectedSubject?.id;
        final chapterId = csVM.selectedChapter?.id ?? '';

        // Always schedule loads when params are ready.
        // Each ViewModel's load() is idempotent — it skips if the same
        // params are already loaded or in-flight.  Calling every build
        // guarantees a refresh when the screen resumes from navigation
        // without relying on stale local tracking variables.
        if (classId != null && subjectId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            channelVM.load(
              courseId: csVM.courseId,
              classId: classId,
              subjectId: subjectId,
              chapterId: chapterId,
            );
            badgeVM.load(
              courseId: csVM.courseId,
              chapterId: chapterId,
            );
            ratingVM.load(
              courseId: csVM.courseId,
              classId: classId,
              subjectId: subjectId,
              chapterId: chapterId,
            );
            signedCookieVM.fetch();
          });
        }

        // ── Channel load states ──────────────────────────────────────────
        return switch (channelVM.state) {
          ChannelLoadState.initial ||
          ChannelLoadState.loading => const _ContentShimmer(),

          ChannelLoadState.error => _ErrorState(
              message: channelVM.error ?? 'Could not load content.',
              onRetry: channelVM.retry,
            ),

          ChannelLoadState.loaded when channelVM.channels.isEmpty =>
            const _EmptyContent(),

          ChannelLoadState.loaded => _ChannelList(
              channels: channelVM.channels,
              toSection: (ch, _) => _toSection(ch, badgeVM, ratingVM),
              onItemTap: _onItemTap,
              scrollController: _scrollCtrl,
            ),
        };
      },
        ),
    );
  }
}

// ── Channel list (real data) ──────────────────────────────────────────────────

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.toSection,
    this.onItemTap,
    this.scrollController,
  });

  final List<ChannelModel> channels;
  final ContentSectionData Function(ChannelModel, int) toSection;
  final void Function(ContentItemData)? onItemTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('content-channel-scroll'),
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        for (int i = 0; i < channels.length; i++) ...[
          SliverToBoxAdapter(
            child: ContentSectionWidget(
              section: toSection(channels[i], i),
              onItemTap: onItemTap,
              onViewAll: () {
                final hdrs =
                    context.read<SignedCookieViewModel>().cookieMap;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChannelVideosScreen(
                      channel: channels[i],
                      headers: hdrs,
                    ),
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _ContentShimmer extends StatelessWidget {
  const _ContentShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (_, _) => const _SectionShimmerBlock(),
    );
  }
}

class _SectionShimmerBlock extends StatefulWidget {
  const _SectionShimmerBlock();

  @override
  State<_SectionShimmerBlock> createState() => _SectionShimmerBlockState();
}

class _SectionShimmerBlockState extends State<_SectionShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar({double width = double.infinity, double height = 12, double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [Color(0xFFE8E8E8), Color(0xFFF8F8F8), Color(0xFFE8E8E8)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header shimmer
        Row(children: [
          _bar(width: 36, height: 36, radius: 18),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(width: 100, height: 12),
            const SizedBox(height: 6),
            _bar(width: 60, height: 10),
          ]),
        ]),
        const SizedBox(height: 12),
        // Card shimmer row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(3, (i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 150, height: 84, radius: 8),
                  const SizedBox(height: 6),
                  _bar(width: 130, height: 11),
                  const SizedBox(height: 4),
                  _bar(width: 80, height: 10),
                ],
              ),
            )),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: Color(0xFFCCCCCC)),
            SizedBox(height: 12),
            Text(
              'No content available\nfor this subject yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF888888), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: _gradPink),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _gradPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sliding drawer panel ──────────────────────────────────────────────────────

const Color _drawerAvatarBlue = Color(0xFF4A90E2);
const Color _drawerDivider    = Color(0xFFE0E0E0);
const Color _drawerTitleColor = Color(0xFF333333);
const Color _drawerSubColor   = Color(0xFF9E9E9E);
const Color _drawerIconColor  = Color(0xFF9E9E9E);

/// Sliding left-side drawer.
///
/// Adapts its content based on [SessionViewModel.isLoggedIn]:
///   • Logged out → Sign In header + basic OTHERS menu
///   • Logged in  → Profile header (avatar + name + edit) + MY UPDATES +
///                  full OTHERS menu (including Log out)
class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({required this.onClose});
  final VoidCallback onClose;

  // ── Logout handler ─────────────────────────────────────────────────────────

  Future<void> _handleLogout(BuildContext context) async {
    final nav       = Navigator.of(context);
    final sessionVM = context.read<SessionViewModel>();

    final confirmed = await ConfirmLogoutSheet.show(context);
    if (confirmed != true || !context.mounted) return;

    sessionVM.logout();
    onClose();
    AppToast.show(context, message: 'You have successfully logged out');
    nav.popUntil((r) => r.settings.name == '/home' || r.isFirst);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final drawerW   = (MediaQuery.sizeOf(context).width * 0.83).clamp(0.0, 320.0);

    return Consumer<SessionViewModel>(
      builder: (context, sessionVM, _) {
        final loggedIn = sessionVM.isLoggedIn;

        return Material(
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: drawerW,
            height: double.infinity,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Gradient header ──────────────────────────────────
                  _DrawerHeader(
                    topPad: topPad,
                    isLoggedIn: loggedIn,
                    userName: sessionVM.userName,
                    userInitials: sessionVM.userInitials,
                    onSignInTap: () {
                      onClose();
                      Navigator.of(context).pushNamed('/login');
                    },
                    onEditTap: () {
                      onClose();
                      Navigator.of(context)
                          .push(EditProfileScreen.route(context));
                    },
                  ),

                  // ── Scrollable menu body ─────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // MY UPDATES — only when logged in
                          if (loggedIn) ...[
                            const _DrawerSectionLabel('MY UPDATES'),
                            _DrawerItem(
                              icon: Icons.access_time_outlined,
                              title: 'My History',
                              subtitle: 'Know your viewing activity',
                              onTap: onClose,
                            ),
                            const _DrawerDivider(),
                            _DrawerItem(
                              icon: Icons.credit_card_outlined,
                              title: 'Transaction History',
                              subtitle: 'Know your payment transactions',
                              onTap: onClose,
                            ),
                            const _DrawerSectionDivider(),
                          ],

                          // OTHERS
                          const _DrawerSectionLabel('OTHERS'),
                          _DrawerItem(
                            icon: Icons.settings_outlined,
                            title: 'App Settings',
                            subtitle: 'Take control and customize your app',
                            onTap: onClose,
                          ),
                          const _DrawerDivider(),
                          _DrawerItem(
                            icon: Icons.star_border_rounded,
                            title: 'Rate us on Play Store',
                            subtitle: 'Let us know your rating for us',
                            onTap: onClose,
                          ),
                          const _DrawerDivider(),
                          _DrawerItem(
                            icon: Icons.devices_outlined,
                            title: 'Manage Devices',
                            subtitle: 'The devices and browsers you signed in are listed here',
                            onTap: onClose,
                          ),
                          const _DrawerDivider(),
                          _DrawerItem(
                            icon: Icons.description_outlined,
                            title: 'Privacy Policy',
                            subtitle: 'Our terms of use & Agreements',
                            onTap: onClose,
                          ),

                          // Log out — only when logged in
                          if (loggedIn) ...[
                            const _DrawerDivider(),
                            _DrawerItem(
                              icon: Icons.logout_rounded,
                              title: 'Log out',
                              subtitle: 'Sign out from the app',
                              iconColor: const Color(0xFFE91E63),
                              onTap: () => _handleLogout(context),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ── Version footer ───────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
                    child: const Text(
                      'Version – ST 1.10.0(10)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _drawerSubColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Drawer header ─────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.topPad,
    required this.isLoggedIn,
    required this.userName,
    required this.userInitials,
    required this.onSignInTap,
    this.onEditTap,
  });

  final double topPad;
  final bool isLoggedIn;
  final String userName;
  final String userInitials;
  final VoidCallback onSignInTap;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoggedIn ? onEditTap : onSignInTap,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF2D55), Color(0xFFFF7A00)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar circle — initials when logged in, person icon when not
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _drawerAvatarBlue,
              ),
              child: Center(
                child: isLoggedIn && userInitials.isNotEmpty
                    ? Text(
                        userInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // Name / sign-in text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoggedIn && userName.isNotEmpty
                        ? userName.toUpperCase()
                        : 'Sign In',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoggedIn ? 'Manage your account' : 'For better experience',
                    style: TextStyle(
                      color: Colors.white.withAlpha(179),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Edit icon (logged in) or chevron (logged out)
            Icon(
              isLoggedIn
                  ? Icons.edit_outlined
                  : Icons.chevron_right_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: _drawerSubColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Full-width separator between sections.
class _DrawerSectionDivider extends StatelessWidget {
  const _DrawerSectionDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 8,
        color: const Color(0xFFF5F5F5),
        margin: const EdgeInsets.symmetric(vertical: 6),
      );
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: _drawerDivider,
        indent: 20,
        endIndent: 20,
      );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0x14000000),
      highlightColor: const Color(0x0A000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: iconColor ?? _drawerIconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _drawerTitleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _drawerSubColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
