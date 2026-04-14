import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// Reusable section header used above every course category row.
///
/// Accepts all data as parameters — no hardcoded values anywhere.
/// Works for School, College, Life Skills, and any future section.
///
/// Layout:
///   LEFT  — [title] (bold, brand colour)
///           [courseCount] Courses  •  [videoCount] Videos  (meta row)
///   RIGHT — "View All >"  (tappable, brand colour)
///
/// Edge cases:
///   - Empty [title]      → shows "—"
///   - [courseCount] == 0 → shows "0 Courses"
///   - [videoCount] null  → video count row item is omitted entirely
///   - [videoCount] ≥ 1000 → formatted as "12k+ Videos"
class SectionHeaderWidget extends StatelessWidget {
  const SectionHeaderWidget({
    super.key,
    required this.title,
    required this.courseCount,
    required this.onViewAllTap,
    this.videoCount,
  });

  /// Category name shown as the section title (e.g. "SCHOOL").
  final String title;

  /// Total number of courses in this section.
  final int courseCount;

  /// Total number of videos — omitted from the stats row when null.
  final int? videoCount;

  /// Called when the user taps "View All".
  final VoidCallback onViewAllTap;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Formats large numbers: 17573 → "17k+", 525 → "525".
  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}k+' : '$n';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: title + stats ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Section title
                Text(
                  title.isNotEmpty ? title : '—',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.sectionTitleText,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Stats row
                Row(
                  children: [
                    // Course count
                    Icon(Icons.video_library_outlined,
                        size: 12, color: colors.metaText),
                    const SizedBox(width: 4),
                    Text(
                      '$courseCount Courses',
                      style:
                          TextStyle(fontSize: 11, color: colors.metaText),
                    ),
                    // Video count (only when provided)
                    if (videoCount != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.play_circle_outline,
                          size: 12, color: colors.metaText),
                      const SizedBox(width: 4),
                      Text(
                        '${_fmt(videoCount!)} Videos',
                        style: TextStyle(
                            fontSize: 11, color: colors.metaText),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Right: View All ─────────────────────────────────────────
          GestureDetector(
            onTap: onViewAllTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Extra tap area without extra visual space
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: colors.brand),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
