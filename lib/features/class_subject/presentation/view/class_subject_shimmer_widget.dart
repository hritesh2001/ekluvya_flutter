import 'package:flutter/material.dart';

/// Animated shimmer skeleton for the subject chips strip.
///
/// Uses **white semi-transparent** colours that are visible on any dark or
/// coloured backdrop (dark indigo, orange-purple gradient, etc.).
/// Avoids the previous [AppColors]-based palette, which produced near-invisible
/// dark-on-dark pills in dark mode.
///
/// Single [AnimationController] drives all pill boxes — 1 rebuild per frame.
class ClassSubjectShimmerWidget extends StatefulWidget {
  const ClassSubjectShimmerWidget({super.key});

  @override
  State<ClassSubjectShimmerWidget> createState() =>
      _ClassSubjectShimmerWidgetState();
}

class _ClassSubjectShimmerWidgetState extends State<ClassSubjectShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  // ── Shimmer tones — white at different opacities ──────────────────────────
  static const Color _base = Color(0x33FFFFFF);      // 20 % white
  static const Color _highlight = Color(0x66FFFFFF); // 40 % white
  static const Color _fade = Color(0x1AFFFFFF);      // 10 % white

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
    return SizedBox(
      height: 48,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (_, _) {
            final gradient = LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [_base, _highlight, _fade, _highlight, _base],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            );

            return ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              children: [
                for (final width in [72.0, 88.0, 68.0, 80.0, 76.0]) ...[
                  _pill(gradient, width: width),
                  const SizedBox(width: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pill(LinearGradient gradient, {required double width}) {
    return Container(
      width: width,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: gradient,
        // Subtle white border makes pills pop on both dark and gradient bgs.
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
    );
  }
}
