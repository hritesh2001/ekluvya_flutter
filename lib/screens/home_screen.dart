import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/banner/presentation/view/banner_carousel_widget.dart';
import '../features/course/presentation/view/course_section_widget.dart';
import '../features/course/presentation/view/course_shimmer_widget.dart';
import '../features/course/presentation/viewmodel/course_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE91E63),
          onRefresh: () => context.read<CourseViewModel>().loadCategories(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Banner Carousel ───────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: BannerCarouselWidget(),
                ),

                const SizedBox(height: 20),

                // ── Course Categories ─────────────────────────────────
                Consumer<CourseViewModel>(
                  builder: (context, vm, _) {
                    if (vm.isLoading) return _buildShimmer();
                    if (vm.hasError) return _buildError(vm);
                    if (vm.isEmpty) return _buildEmpty();
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

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildError(CourseViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              vm.errorMessage ?? 'Failed to load courses',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: vm.retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text('No courses available',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}
