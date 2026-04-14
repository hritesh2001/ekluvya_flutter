import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// Animated shimmer placeholder shown while banner images are loading.
///
/// Accepts an optional [height] so the caller can match the responsive
/// banner height exactly. Defaults to 180 if not supplied.
class BannerShimmerWidget extends StatefulWidget {
  const BannerShimmerWidget({super.key, this.height = 180});

  final double height;

  @override
  State<BannerShimmerWidget> createState() => _BannerShimmerWidgetState();
}

class _BannerShimmerWidgetState extends State<BannerShimmerWidget>
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    // RepaintBoundary isolates the 60 fps animation repaint from the parent
    // widget tree so static ancestors are never unnecessarily dirtied.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
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
              ),
            ),
          );
        },
      ),
    );
  }
}
