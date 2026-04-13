import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/course_model.dart';

/// A single course card displayed inside a horizontal scroll list.
///
/// Layout:
/// ┌──────────────────┐
/// │   Course image   │  (CachedNetworkImage, fills top ~105px)
/// ├──────────────────┤
/// │ Course title     │  (bold, max 2 lines)
/// │ Class name       │  (grey)
/// │ Subject name     │  (pink accent)
/// └──────────────────┘
class CourseCardWidget extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const CourseCardWidget({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
              child: SizedBox(
                height: 105,
                width: double.infinity,
                child: course.hasImage
                    ? CachedNetworkImage(
                        imageUrl: course.fullImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _placeholder(),
                        errorWidget: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),

            // ── Text info ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                  if (course.classDetails != null &&
                      course.classDetails!.title.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      course.classDetails!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  if (course.subjectTitle != null &&
                      course.subjectTitle!.title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      course.subjectTitle!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(Icons.play_circle_outline,
            size: 36, color: Color(0xFFCCCCCC)),
      ),
    );
  }
}
