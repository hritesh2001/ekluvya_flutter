import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/logger.dart';
import '../../data/models/banner_model.dart';
import '../viewmodel/banner_viewmodel.dart';
import 'banner_shimmer_widget.dart';

/// Full-width banner image carousel.
///
/// - Shows [BannerModel.bannerImg] as a full-bleed [CachedNetworkImage].
/// - No text, no labels, no overlays — pure image only.
/// - Auto-scrolls every 5 s; pauses while the user drags.
/// - Rounded corners (16 px radius).
/// - Page indicator dots below.
/// - Height: 38 % of screen width, clamped to [130, 200] dp.
class BannerCarouselWidget extends StatefulWidget {
  const BannerCarouselWidget({super.key});

  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  static const _autoScrollInterval = Duration(seconds: 5);
  static const _slideDuration = Duration(milliseconds: 450);

  // ── Responsive height ─────────────────────────────────────────────────────

  double _bannerHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Smaller height so the full image is visible without cropping.
    // 0.28 × screen width ≈ 100 dp on small phones, 140 dp on large phones.
    return (width * 0.28).clamp(100.0, 150.0);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<BannerViewModel>();
      // Listen for the first loaded state to kick off auto-scroll exactly once.
      vm.addListener(_onBannerVmChange);
      vm.loadBanners();
    });
  }

  void _onBannerVmChange() {
    final vm = context.read<BannerViewModel>();
    if (vm.hasData) {
      // Banners just arrived — start auto-scroll (guarded against double-start).
      _startAutoScroll(vm.banners.length);
    } else {
      // Error / loading / empty — stop any running timer.
      _stopAutoScroll();
    }
  }

  @override
  void dispose() {
    // Remove the ViewModel listener to prevent callbacks after disposal.
    context.read<BannerViewModel>().removeListener(_onBannerVmChange);
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── Auto-scroll ───────────────────────────────────────────────────────────

  void _startAutoScroll(int count) {
    // Guard: don't cancel and recreate a perfectly healthy running timer.
    // Without this, every Consumer rebuild (e.g. on refresh) called
    // addPostFrameCallback → _startAutoScroll, nuking the timer and causing
    // a visible stutter / page-position reset mid-scroll.
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer?.cancel();
    if (count <= 1) return;
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(
        next,
        duration: _slideDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    // Null out so the isActive guard in _startAutoScroll lets the
    // next call restart correctly after a user drag.
    _autoScrollTimer = null;
  }

  // ── Fallback states ───────────────────────────────────────────────────────

  Widget _buildError(
      String? message, VoidCallback onRetry, AppColors colors, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.errorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 36, color: colors.brand),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message ?? 'Failed to load banners',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.metaText),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors colors, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.imagePlaceholder,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'No banners available',
          style: TextStyle(color: colors.metaText, fontSize: 14),
        ),
      ),
    );
  }

  Widget _imageFallback(AppColors colors, double height) {
    return Container(
      height: height,
      color: colors.imagePlaceholder,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 40,
          color: colors.metaText,
        ),
      ),
    );
  }

  // ── Single banner page — full-width image, no text ────────────────────────

  Widget _buildBannerPage(BannerModel banner, double height, AppColors colors) {
    return GestureDetector(
      onTap: () {
        // TODO: wire deep-link navigation when the course/video module is ready
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          // Full image — no overlay, no text, no gradient on top.
          child: banner.bannerImg.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: banner.fullImageUrl,
                  // BoxFit.contain → entire image visible, no cropping.
                  // BoxFit.cover would always crop to fill the fixed height.
                  fit: BoxFit.contain,
                  placeholder: (_, url) => BannerShimmerWidget(height: height),
                  errorWidget: (_, url, err) {
                    AppLogger.warning(
                        'BannerCarousel', 'Image failed → ${banner.fullImageUrl}');
                    return _imageFallback(colors, height);
                  },
                )
              : _imageFallback(colors, height),
        ),
      ),
    );
  }

  // ── Indicator dots ────────────────────────────────────────────────────────

  Widget _buildIndicators(int count, AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? colors.brand
                : colors.metaText.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── Carousel ──────────────────────────────────────────────────────────────

  Widget _buildCarousel(
      List<BannerModel> banners, double height, AppColors colors) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) _stopAutoScroll();
              if (n is ScrollEndNotification) _startAutoScroll(banners.length);
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) =>
                  _buildBannerPage(banners[index], height, colors),
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          _buildIndicators(banners.length, colors),
        ],
      ],
    );
  }

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final height = _bannerHeight(context);

    return Consumer<BannerViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) return BannerShimmerWidget(height: height);
        if (vm.hasError) {
          return _buildError(vm.errorMessage, vm.retry, colors, height);
        }
        if (vm.isEmpty) return _buildEmpty(colors, height);
        if (vm.hasData) return _buildCarousel(vm.banners, height, colors);
        return BannerShimmerWidget(height: height);
      },
    );
  }
}
