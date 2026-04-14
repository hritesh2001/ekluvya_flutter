import 'package:flutter/material.dart';

import '../../../../../core/utils/logger.dart';
import '../../../class_subject/presentation/view/course_detail_screen.dart';
import '../../data/models/category_model.dart';
import '../../data/models/course_model.dart';
import 'course_card_widget.dart';
import 'section_header_widget.dart';

/// Renders one category section: [SectionHeaderWidget] + horizontal course list.
///
/// [CourseCardWidget] and [SectionHeaderWidget] are both fully reusable —
/// this widget only bridges the [CategoryModel] data to their plain-value APIs.
///
/// Card width (via LayoutBuilder):
///   Phone  (< 600 dp) → 44 % of available width, clamped to [160, 200] dp
///   Tablet (≥ 600 dp) → 28 % of available width, clamped to [170, 210] dp
class CourseSectionWidget extends StatelessWidget {
  const CourseSectionWidget({super.key, required this.category});

  final CategoryModel category;

  // ── Layout helpers ────────────────────────────────────────────────────────

  double _cardWidth(double availableWidth) {
    if (availableWidth >= 600) {
      return (availableWidth * 0.28).clamp(170.0, 210.0);
    }
    return (availableWidth * 0.44).clamp(160.0, 200.0);
  }

  // Must match CourseCardWidget.aspectRatio exactly.
  double _listHeight(double cardWidth) => cardWidth * CourseCardWidget.aspectRatio;

  void _onCourseTap(BuildContext context, CourseModel course, int index) {
    AppLogger.info(
      'CourseTap',
      'title="${course.title}" '
      'class="${course.classDetails?.title}" '
      'subject="${course.subjectTitle?.title}"',
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailScreen(
          courseId: course.id,
          courseTitle: course.title,
          courseImageUrl: course.fullImageUrl,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!category.hasCourses) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _cardWidth(constraints.maxWidth);
        final listHeight = _listHeight(cardWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header (reusable) ───────────────────────────
            SectionHeaderWidget(
              title: category.title,
              courseCount: category.totalCourses,
              videoCount: category.totalVideos,
              onViewAllTap: () {
                AppLogger.info('ViewAll', 'category="${category.title}"');
              },
            ),

            const SizedBox(height: 10),

            // ── Horizontal course list ──────────────────────────────
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: category.courses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final course = category.courses[index];
                  return CourseCardWidget(
                    // Pass primitive values — CourseCardWidget stays
                    // decoupled from CourseModel.
                    title: course.title,
                    imageUrl: course.fullImageUrl,
                    cardWidth: cardWidth,
                    onTap: () => _onCourseTap(context, course, index),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
