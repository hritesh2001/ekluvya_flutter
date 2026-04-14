import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

// ── Below-gradient surface (light, as in the design) ─────────────────────────
const Color _surfaceWhite = Color(0xFFF8F8F8);

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
    return ChangeNotifierProvider(
      create: (ctx) => ClassSubjectViewModel(
        repository: ctx.read<ClassSubjectRepository>(),
        courseId: courseId,
        courseTitle: courseTitle,
      )..initialize(),
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
        backgroundColor: _surfaceWhite,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Rows 1-3: gradient header band ───────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_gradOrange, _gradPink],
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

// ── Content scroll view ───────────────────────────────────────────────────────

class _ContentScrollView extends StatelessWidget {
  const _ContentScrollView();

  static List<ContentSectionData> _buildMockSections(String? chapterName) {
    final suffix =
        chapterName != null && chapterName.isNotEmpty ? ' · $chapterName' : '';
    return [
      ContentSectionData(
        id: 'ekluvya',
        sourceName: 'Ekluvya',
        sourceColor: const Color(0xFFE91E63),
        videoCount: 14,
        rating: 3.9,
        items: [
          ContentItemData(
            id: 'e1',
            title: 'IIT Class 7 Mathematics Chapter 1$suffix',
            videosLabel: '6 VIDEOS',
            rating: 4.5,
          ),
          ContentItemData(
            id: 'e2',
            title: 'IIT IIM COURSE$suffix',
            videosLabel: '4 VIDEOS',
            rating: 4.3,
          ),
          ContentItemData(
            id: 'e3',
            title: 'test$suffix',
            videosLabel: '4 VIDEOS',
          ),
        ],
      ),
      ContentSectionData(
        id: 'tutorials1',
        sourceName: 'Tutorials',
        sourceColor: const Color(0xFF7C3AED),
        videoCount: 4,
        rating: 4.4,
        items: [
          ContentItemData(
            id: 't1',
            title: 'Tutoria: Sample Test$suffix',
            videosLabel: '1 VIDEO',
          ),
          ContentItemData(
            id: 't2',
            title: 'The Railway Man — Official Trailer — Streaming Now$suffix',
            videosLabel: '1 VIDEO',
            rating: 4.1,
          ),
          ContentItemData(
            id: 't3',
            title: 'The Bala-Rite$suffix',
            videosLabel: '2 VIDEOS',
          ),
        ],
      ),
      ContentSectionData(
        id: 'tutorials2',
        sourceName: 'Tutorials',
        sourceColor: const Color(0xFF0EA5E9),
        videoCount: 15,
        rating: 4.2,
        items: [
          ContentItemData(
            id: 't4',
            title: '3D Geometry Full Course$suffix',
            videosLabel: '5 VIDEOS',
            rating: 4.4,
          ),
          ContentItemData(
            id: 't5',
            title: 'tu· Course Essentials$suffix',
            videosLabel: '5 VIDEOS',
            rating: 4.0,
          ),
          ContentItemData(
            id: 't6',
            title: 'Advanced Problem Set$suffix',
            videosLabel: '5 VIDEOS',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ClassSubjectViewModel, (String?, String?)>(
      selector: (_, vm) => (vm.classesError, vm.selectedChapter),
      builder: (context, data, _) {
        final (classesErr, selectedChapter) = data;

        if (classesErr != null &&
            context.read<ClassSubjectViewModel>().selectedClass == null) {
          return _ErrorState(
            message: classesErr,
            onRetry: context.read<ClassSubjectViewModel>().retryClasses,
          );
        }

        final sections = _buildMockSections(selectedChapter);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            for (int i = 0; i < sections.length; i++) ...[
              SliverToBoxAdapter(
                child: ContentSectionWidget(
                  section: sections[i],
                  onViewAll: () {},
                ),
              ),
              if (i < sections.length - 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
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
