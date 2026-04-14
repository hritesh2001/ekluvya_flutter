import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'course_card_widget.dart';

/// Shimmer skeleton shown while course data is loading.
///
/// Mirrors the exact layout of [CourseSectionWidget] so the
/// transition from skeleton → real content is seamless.
///
/// Key improvements over the previous version:
///   - Card dimensions use EXACTLY the same formulas as [CourseSectionWidget]
///     (previously used different multiplier + clamp values, causing a
///     visible layout shift when real content replaced the skeleton).
///   - Single root [AnimatedBuilder] drives the entire widget instead of
///     one [AnimatedBuilder] per shimmer box — reduces per-frame rebuild
///     work from 5+ rebuilds to 1.
///   - Wrapped in [RepaintBoundary] so the 60 fps shimmer animation cannot
///     dirty the surrounding (static) widget tree.
class CourseShimmerWidget extends StatefulWidget {
  const CourseShimmerWidget({super.key});

  @override
  State<CourseShimmerWidget> createState() => _CourseShimmerWidgetState();
}

class _CourseShimmerWidgetState extends State<CourseShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Layout helpers — MUST match CourseSectionWidget exactly ──────────────

  /// Mirrors [CourseSectionWidget._cardWidth] 1-to-1.
  /// Using the same multiplier (0.44 / 0.28) and clamp ranges ensures the
  /// shimmer card size is pixel-perfect when real content replaces it.
  double _cardWidth(double availableWidth) {
    if (availableWidth >= 600) {
      return (availableWidth * 0.28).clamp(170.0, 210.0);
    }
    return (availableWidth * 0.44).clamp(160.0, 200.0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = _cardWidth(screenWidth);
    // Use the same aspect ratio constant as CourseCardWidget to stay in sync.
    final listHeight = cardWidth * CourseCardWidget.aspectRatio;

    // RepaintBoundary isolates the 60 fps shimmer repaint from the rest of
    // the scroll view — static sliver ancestors are never dirtied.
    return RepaintBoundary(
      // Single AnimatedBuilder at the root: the gradient is computed once per
      // frame and passed into every shimmer box as a parameter, replacing the
      // previous pattern where each box held its own AnimatedBuilder.
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final gradient = LinearGradient(
            begin: Alignment(_animation.value - 1, 0),
            end: Alignment(_animation.value, 0),
            colors: [
              colors.shimmerBase,
              colors.shimmerHighlight,
              colors.shimmerBase.withValues(alpha: 0.85),
              colors.shimmerHighlight,
              colors.shimmerBase,
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header skeleton ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(gradient, width: 110, height: 14),
                    const SizedBox(height: 7),
                    _box(gradient, width: 190, height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Cards row ───────────────────────────────────────────
              SizedBox(
                height: listHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _box(
                          gradient,
                          width: cardWidth,
                          height: listHeight,
                          radius: 12,
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Renders a single shimmer rectangle with the pre-built [gradient].
  Widget _box(
    LinearGradient gradient, {
    double width = double.infinity,
    double height = 12,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
      ),
    );
  }
}
