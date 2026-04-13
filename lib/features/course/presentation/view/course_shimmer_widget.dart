import 'package:flutter/material.dart';

/// Shimmer skeleton shown while course data is loading.
/// Renders a realistic preview of a full section (header + 3 cards).
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

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 12,
    double radius = 6,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_animation.value - 1, 0),
            end: Alignment(_animation.value, 0),
            colors: const [
              Color(0xFFE0E0E0),
              Color(0xFFF5F5F5),
              Color(0xFFEEEEEE),
              Color(0xFFF5F5F5),
              Color(0xFFE0E0E0),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          _shimmerBox(height: 105, radius: 10),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 11),
                const SizedBox(height: 6),
                _shimmerBox(width: 90, height: 9),
                const SizedBox(height: 4),
                _shimmerBox(width: 70, height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 120, height: 14),
              const SizedBox(height: 6),
              _shimmerBox(width: 180, height: 10),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Cards row
        SizedBox(
          height: 165,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(3, (_) => _shimmerCard()),
          ),
        ),
      ],
    );
  }
}
