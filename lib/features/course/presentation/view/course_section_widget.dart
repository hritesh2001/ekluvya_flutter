import 'package:flutter/material.dart';

import '../../data/models/category_model.dart';
import '../../data/models/course_model.dart';
import 'course_card_widget.dart';

/// Renders one category section: header row + horizontal course card list.
///
/// Usage:
/// ```dart
/// CourseSectionWidget(category: categoryModel)
/// ```
class CourseSectionWidget extends StatelessWidget {
  final CategoryModel category;

  const CourseSectionWidget({super.key, required this.category});

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k+';
    return '$n';
  }

  void _onCourseTap(BuildContext context, CourseModel course, int index) {
    // Future scope:
    //   index == 0 → allow free preview (video player)
    //   index >= 1 → trigger login gate
    // For now: log course details to console.
    debugPrint(
      '[CourseTap] title="${course.title}" '
      'class="${course.classDetails?.title}" '
      'subject="${course.subjectTitle?.title}" '
      'image="${course.fullImageUrl}"',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!category.hasCourses) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${category.totalCourses} Courses',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (category.totalVideos != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.play_circle_outline,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatCount(category.totalVideos!)} Videos',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // View All button
              TextButton(
                onPressed: () {
                  // TODO: navigate to full category list when module is ready
                  debugPrint('[ViewAll] category="${category.title}"');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFFE91E63)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Horizontal course list ────────────────────────────────────
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: category.courses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => CourseCardWidget(
              course: category.courses[index],
              onTap: () =>
                  _onCourseTap(context, category.courses[index], index),
            ),
          ),
        ),
      ],
    );
  }
}
