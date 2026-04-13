import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/banner_model.dart';
import '../viewmodel/banner_viewmodel.dart';
import 'banner_shimmer_widget.dart';

/// Full-width banner carousel with auto-scroll, indicators, shimmer loading,
/// error state with a Retry button, and empty state handling.
///
/// Consumed via [Consumer<BannerViewModel>] — make sure [BannerViewModel]
/// is registered above this widget in the Provider tree.
class BannerCarouselWidget extends StatefulWidget {
  const BannerCarouselWidget({super.key});

  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  /// How long each banner stays visible before sliding to the next.
  static const _autoScrollInterval = Duration(seconds: 3);

  /// Slide animation duration.
  static const _slideDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    // Delay until the first frame so context.read is safe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BannerViewModel>().loadBanners();
    });
  }

  // ── Auto-scroll ────────────────────────────────────────────────────────

  void _startAutoScroll(int count) {
    _autoScrollTimer?.cancel();
    if (count <= 1) return; // no point scrolling a single banner

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_pageController.hasClients) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(
        next,
        duration: _slideDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoScroll() => _autoScrollTimer?.cancel();

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── State widgets ──────────────────────────────────────────────────────

  Widget _buildShimmer() => const BannerShimmerWidget();

  Widget _buildError(String? message, VoidCallback onRetry) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.redAccent),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message ?? 'Failed to load banners',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'No banners available',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  // ── Banner page ────────────────────────────────────────────────────────

  Widget _buildBannerPage(BannerModel banner) {
    return GestureDetector(
      onTap: () {
        // TODO: wire deep-link navigation when the course/video module is ready
        // if (banner.hasLink) { Navigator.pushNamed(context, '/course', arguments: banner.bannerUrl); }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          banner.fullImageUrl,
          width: double.infinity,
          fit: BoxFit.fill,
          // Show shimmer while the individual image downloads
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const BannerShimmerWidget();
          },
          // Show the attempted URL so we can verify it is correct
          errorBuilder: (context, error, stackTrace) {
            debugPrint('BannerImage FAILED → ${banner.fullImageUrl} | $error');
            return Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        size: 32, color: Colors.grey),
                    const SizedBox(height: 4),
                    SelectableText(
                      banner.fullImageUrl,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.blueGrey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Indicator dots ─────────────────────────────────────────────────────

  Widget _buildIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE91E63)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── Carousel ───────────────────────────────────────────────────────────

  Widget _buildCarousel(List<BannerModel> banners) {
    // Kick off auto-scroll after the carousel renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoScroll(banners.length);
    });

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Pause while user is actively dragging
              if (notification is ScrollStartNotification) _stopAutoScroll();
              // Resume once they let go
              if (notification is ScrollEndNotification) {
                _startAutoScroll(banners.length);
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) =>
                  setState(() => _currentPage = index),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildBannerPage(banners[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildIndicators(banners.length),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) return _buildShimmer();
        if (vm.hasError) return _buildError(vm.errorMessage, vm.retry);
        if (vm.isEmpty) return _buildEmpty();
        if (vm.hasData) return _buildCarousel(vm.banners);
        // BannerState.initial — also show shimmer until first load
        return _buildShimmer();
      },
    );
  }
}
