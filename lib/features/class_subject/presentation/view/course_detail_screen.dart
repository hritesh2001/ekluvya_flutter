import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/channel/data/models/channel_model.dart';
import '../../../../features/channel/domain/repositories/channel_repository.dart';
import '../../../../features/channel/presentation/viewmodel/channel_viewmodel.dart';
import '../../domain/repositories/class_subject_repository.dart';
import '../viewmodel/class_subject_viewmodel.dart';
import 'chapter_filter_widget.dart';
import 'class_selector_widget.dart';
import 'content_section_widget.dart';
import 'subject_chips_widget.dart';

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
class CourseDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Both ViewModels are scoped to this screen.
    // ChannelViewModel shares the global ChannelRepository (cached).
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => ClassSubjectViewModel(
            repository: ctx.read<ClassSubjectRepository>(),
            courseId: courseId,
            courseTitle: courseTitle,
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChannelViewModel(
            repository: ctx.read<ChannelRepository>(),
          ),
        ),
      ],
      child: _CourseDetailBody(courseTitle: courseTitle),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CourseDetailBody extends StatelessWidget {
  const _CourseDetailBody({required this.courseTitle});
  final String courseTitle;

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
            // ── Rows 1-3: gradient header band ───────────────────────
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
                  // Status-bar inset
                  SizedBox(height: topPad),

                  // Row 1 — App branding
                  _BrandRow(),

                  // Row 2 — Course title + class selector
                  _CourseTitleRow(courseTitle: courseTitle),

                  const SizedBox(height: 2),

                  // Row 3 — Subject chips
                  const SubjectChipsWidget(),

                  const SizedBox(height: 10),
                ],
              ),
            ),

            // ── Row 4: chapter filter (white surface) ────────────────
            const ColoredBox(
              color: Colors.white,
              child: _ChapterFilterRow(),
            ),

            // ── Rows 5+: scrollable content ───────────────────────────
            const Expanded(child: _ContentScrollView()),
          ],
        ),
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Hamburger menu ─────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
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

// ── Channel colour palette — cycled by index ──────────────────────────────────

const List<Color> _channelColors = [
  Color(0xFFE91E63), // brand pink
  Color(0xFF7C3AED), // purple
  Color(0xFF0EA5E9), // sky blue
  Color(0xFF16A34A), // green
  Color(0xFFF97316), // orange
  Color(0xFF0891B2), // cyan
];

Color _colorForIndex(int i) => _channelColors[i % _channelColors.length];

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
  // Tracks the last params passed to ChannelViewModel.load() to avoid
  // redundant calls when unrelated parts of ClassSubjectViewModel notify.
  String? _loadedClassId;
  String? _loadedSubjectId;
  String? _loadedChapterId;

  /// Converts a [ChannelModel] → [ContentSectionData] for the existing widget.
  ContentSectionData _toSection(ChannelModel ch, int index) {
    final items = ch.videos.map((v) {
      final label = v.durationSeconds > 0 ? v.formattedDuration : null;
      return ContentItemData(
        id: v.id,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        videosLabel: label,
      );
    }).toList();

    return ContentSectionData(
      id: ch.id,
      sourceName: ch.title,
      sourceColor: _colorForIndex(index),
      videoCount: ch.totalVideos,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ClassSubjectViewModel, ChannelViewModel>(
      builder: (ctx, csVM, channelVM, _) {
        // ── Show class-level error when no class loaded yet ──────────────
        if (csVM.classesHasError && csVM.selectedClass == null) {
          return _ErrorState(
            message: csVM.classesError ?? 'Could not load classes.',
            onRetry: csVM.retryClasses,
          );
        }

        // ── Trigger channel load when class + subject are ready ──────────
        // Load immediately even without a chapterId so content is visible.
        // When chapters load later and auto-select the first one, chapterId
        // changes → we re-load with the proper ID → correct filtered data.
        final classId = csVM.selectedClass?.id;
        final subjectId = csVM.selectedSubject?.id;
        final chapterId = csVM.selectedChapter?.id ?? '';

        if (classId != null && subjectId != null) {
          final paramsChanged = classId != _loadedClassId ||
              subjectId != _loadedSubjectId ||
              chapterId != (_loadedChapterId ?? '');
          if (paramsChanged) {
            _loadedClassId = classId;
            _loadedSubjectId = subjectId;
            _loadedChapterId = chapterId;
            // Post-frame to avoid mutating state during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              channelVM.load(
                courseId: csVM.courseId,
                classId: classId,
                subjectId: subjectId,
                chapterId: chapterId,
              );
            });
          }
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
              toSection: _toSection,
            ),
        };
      },
    );
  }
}

// ── Channel list (real data) ──────────────────────────────────────────────────

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.toSection,
  });

  final List<ChannelModel> channels;
  final ContentSectionData Function(ChannelModel, int) toSection;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        for (int i = 0; i < channels.length; i++) ...[
          SliverToBoxAdapter(
            child: ContentSectionWidget(
              section: toSection(channels[i], i),
              onViewAll: () {}, // TODO: navigate to full channel view
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
