import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/banner/presentation/view/banner_carousel_widget.dart';
import '../features/course/presentation/view/course_section_widget.dart';
import '../features/course/presentation/view/course_shimmer_widget.dart';
import '../features/course/presentation/viewmodel/course_viewmodel.dart';

/// Landing screen.
///
/// Constraints:
///   - No AppBar, no navigation bar, no icons in the header.
///   - Screen starts directly with the banner.
///   - [AnnotatedRegion] controls status-bar icon brightness without an AppBar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseViewModel>().loadCategories();
    });
  }

  // ── Content states ────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Column(
      children: List.generate(
        2,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: CourseShimmerWidget(),
        ),
      ),
    );
  }

  Widget _buildError(CourseViewModel vm, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.brand),
            const SizedBox(height: 12),
            Text(
              vm.errorMessage ?? 'Failed to load courses',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.metaText),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: vm.retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
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

  Widget _buildEmpty(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'No courses available',
          style: TextStyle(color: colors.metaText, fontSize: 14),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // AnnotatedRegion is the correct way to control the status-bar style
    // when there is no AppBar to carry a SystemUiOverlayStyle.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        // No AppBar — screen starts directly with the banner.
        body: SafeArea(
          child: RefreshIndicator(
            color: colors.brand,
            onRefresh: () async {
              await context.read<CourseViewModel>().loadCategories();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Banner Carousel ───────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: BannerCarouselWidget(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Course Categories ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Consumer<CourseViewModel>(
                    builder: (context, vm, _) {
                      if (vm.isLoading) return _buildShimmer();
                      if (vm.hasError) return _buildError(vm, colors);
                      if (vm.isEmpty) return _buildEmpty(colors);
                      if (vm.hasData) {
                        return Column(
                          children: [
                            for (final category in vm.categories) ...[
                              CourseSectionWidget(category: category),
                              const SizedBox(height: 20),
                            ],
                          ],
                        );
                      }
                      return _buildShimmer();
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
