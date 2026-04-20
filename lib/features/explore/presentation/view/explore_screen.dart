import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../widgets/custom_bottom_nav_bar.dart';
import '../../../course/data/models/category_model.dart';
import '../../../course/presentation/viewmodel/course_viewmodel.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const Color  _titleBarColor = Color(0xFF1A1A1A);
const Color  _dividerColor  = Color(0xFFEEEEEE);
const double _cardRadius    = 16.0;
const double _cardHeight    = 155.0;
const double _cardMarginH   = 16.0;
const double _cardMarginV   = 8.0;

// ── Entry point ───────────────────────────────────────────────────────────────

/// Standalone explore tab — embedded in IndexedStack, NOT a Scaffold.
/// Reads the app-wide [CourseViewModel] to display collection cards.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger load the first time this tab is shown.  CourseViewModel guards
    // against duplicate in-flight calls, so this is safe to call repeatedly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<CourseViewModel>();
      if (!vm.hasData && !vm.isLoading) {
        vm.loadCategories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad =
        kNavBarTotalHeight + MediaQuery.viewPaddingOf(context).bottom + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topPad),
        // ── Header ────────────────────────────────────────────────────
        const _ExploreHeader(),
        const Divider(height: 1, thickness: 1, color: _dividerColor),
        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: Consumer<CourseViewModel>(
            builder: (_, vm, _) => switch (vm.state) {
              CourseState.initial ||
              CourseState.loading => _ExploreShimmer(bottomPad: bottomPad),
              CourseState.error   => _ExploreError(
                  message: vm.errorMessage ?? 'Could not load courses.',
                  onRetry: vm.retry,
                ),
              CourseState.loaded when vm.categories.isEmpty =>
                const _ExploreEmpty(),
              CourseState.loaded => _CategoryList(
                  categories: vm.categories,
                  bottomPad: bottomPad,
                ),
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Explore Courses',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _titleBarColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Category list ─────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.bottomPad});

  final List<CategoryModel> categories;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        _cardMarginH,
        _cardMarginV,
        _cardMarginH,
        bottomPad,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: _cardMarginV * 2),
        child: _CategoryCard(
          key: ValueKey(categories[i].id),
          category: categories[i],
          onTap: () => _navigate(context, categories[i]),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, CategoryModel category) {
    context.read<CourseViewModel>().selectCategory(category.id);
    Navigator.of(context).pop();
  }
}

// ── Collection card ───────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: SizedBox(
          height: _cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image ─────────────────────────────────
              _CardBackground(imageUrl: category.fullImageUrl),

              // ── Dark gradient overlay ────────────────────────────
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000), // transparent
                      Color(0xB3000000), // ~70 % black
                    ],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),

              // ── Text + arrow overlay ─────────────────────────────
              Positioned(
                left: 16,
                right: 12,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _CardContent(category: category)),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card background image ─────────────────────────────────────────────────────

class _CardBackground extends StatelessWidget {
  const _CardBackground({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const ColoredBox(color: Color(0xFF2A2A2A));

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFF2A2A2A)),
      errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFF2A2A2A)),
    );
  }
}

// ── Card text content ─────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final videoCount = category.totalVideos ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          category.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _StatBadge(
              icon: Icons.table_chart_outlined,
              label: '${category.totalCourses} Courses',
            ),
            const SizedBox(width: 14),
            _StatBadge(
              icon: Icons.play_circle_outline_rounded,
              label: '$videoCount VIDEOS',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _ExploreShimmer extends StatefulWidget {
  const _ExploreShimmer({required this.bottomPad});
  final double bottomPad;

  @override
  State<_ExploreShimmer> createState() => _ExploreShimmerState();
}

class _ExploreShimmerState extends State<_ExploreShimmer>
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
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _block() => AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Container(
          height: _cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _cardMarginH,
        _cardMarginV,
        _cardMarginH,
        widget.bottomPad,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: _cardMarginV * 2),
        child: _block(),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ExploreError extends StatelessWidget {
  const _ExploreError({required this.message, required this.onRetry});

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
                size: 52, color: Color(0xFFEE4166)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEE4166),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _ExploreEmpty extends StatelessWidget {
  const _ExploreEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_rounded, size: 52, color: Color(0xFFCCCCCC)),
          SizedBox(height: 14),
          Text(
            'No courses available.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}
