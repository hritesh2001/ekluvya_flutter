import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../features/banner/presentation/view/banner_carousel_widget.dart';
import '../features/course/presentation/view/course_section_widget.dart';
import '../features/course/presentation/view/course_shimmer_widget.dart';
import '../features/course/presentation/viewmodel/course_viewmodel.dart';
import '../features/video_player/presentation/view/video_player_screen.dart';

/// Landing screen — banners + course category cards.
/// No bottom navigation here; the navbar lives on CourseDetailScreen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  CourseViewModel? _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm = context.read<CourseViewModel>();
      _vm!.addListener(_onVmChanged);
      if (!_vm!.hasData && !_vm!.isLoading) _vm!.loadCategories();
      _resumePendingVideo();
    });
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _resumePendingVideo() {
    final sessionVM = context.read<SessionViewModel>();
    if (!sessionVM.hasPendingVideo || !sessionVM.isSubscribed) return;
    final video   = sessionVM.pendingVideo!;
    final headers = sessionVM.pendingVideoHeaders;
    sessionVM.clearPendingVideo();
    Navigator.of(context).push(VideoPlayerScreen.route(video, headers: headers));
  }

  void _onVmChanged() {
    final id = _vm?.pendingScrollCategoryId;
    if (id == null) return;
    _vm!.clearPendingScroll();
    // Schedule scroll for the frame after HomeScreen becomes current again.
    // Because ExploreScreen calls selectCategory() before Navigator.pop(),
    // this callback fires while HomeScreen is still behind the outgoing route.
    // The scroll silently completes during the pop animation so HomeScreen
    // appears at the correct position with no visible jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _categoryKeys[id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
      }
    });
  }

  Widget _buildShimmer() => Column(
        children: List.generate(
          2,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: CourseShimmerWidget(),
          ),
        ),
      );

  Widget _buildError(CourseViewModel vm, AppColors colors) => Padding(
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

  Widget _buildEmpty(AppColors colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No courses available',
            style: TextStyle(color: colors.metaText, fontSize: 14),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            color: colors.brand,
            onRefresh: () async =>
                context.read<CourseViewModel>().loadCategories(),
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: BannerCarouselWidget(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Consumer<CourseViewModel>(
                    builder: (context, vm, _) {
                      if (vm.isLoading) return _buildShimmer();
                      if (vm.hasError) return _buildError(vm, colors);
                      if (vm.isEmpty) return _buildEmpty(colors);
                      if (vm.hasData) {
                        return Column(
                          children: [
                            for (final cat in vm.categories) ...[
                              CourseSectionWidget(
                                key: _categoryKeys.putIfAbsent(
                                    cat.id, GlobalKey.new),
                                category: cat,
                              ),
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
