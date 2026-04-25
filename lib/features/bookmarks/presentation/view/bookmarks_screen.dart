import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../../widgets/app_toast.dart';
import '../../data/models/bookmark_item_model.dart';
import '../viewmodel/bookmark_viewmodel.dart';

// ── Brand constants ───────────────────────────────────────────────────────────

const _kDark    = Color(0xFF1A1A1A);
const _kGray    = Color(0xFF9E9E9E);
const _kYellow  = Color(0xFFFFD600);
const _kDivider = Color(0xFFF0F0F0);
const _kHPad    = 16.0;
const _kColGap  = 10.0;

// ─────────────────────────────────────────────────────────────────────────────

/// Bookmarks tab — embedded in CourseDetailScreen's IndexedStack.
/// Fetches the watch-later list on first build and keeps alive across tab switches.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookmarkViewModel>().fetchBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<BookmarkViewModel>(
      builder: (context, vm, _) {
        return Column(
          children: [
            _BookmarksHeader(isBusy: vm.isBusy, hasItems: !vm.isEmpty),
            Expanded(child: _BookmarksBody(vm: vm)),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _BookmarksHeader extends StatelessWidget {
  const _BookmarksHeader({required this.isBusy, required this.hasItems});

  final bool isBusy;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_kHPad, 16, _kHPad, 8),
          child: Row(
            children: [
              const Text(
                'Watch Later',
                style: TextStyle(
                  color: _kDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isBusy && hasItems)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: _kYellow,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: _kDivider),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _BookmarksBody extends StatelessWidget {
  const _BookmarksBody({required this.vm});

  final BookmarkViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kYellow));
    }

    if (vm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: _kGray),
              const SizedBox(height: 12),
              Text(
                vm.error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _kGray),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => vm.fetchBookmarks(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: _kYellow),
                label: const Text('Retry',
                    style: TextStyle(color: _kYellow)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kYellow),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.isEmpty) return const _EmptyBookmarksView();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth   = (screenWidth - _kHPad * 2 - _kColGap) / 2;
    final thumbHeight = cardWidth * (9 / 16);
    final cellHeight  = thumbHeight + 6 + 14.0 * 1.4 * 2 + 6;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          vm.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(_kHPad, 16, _kHPad, 24),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: _kColGap,
          mainAxisSpacing: 10,
          mainAxisExtent: cellHeight,
        ),
        itemCount: vm.items.length,
        itemBuilder: (context, index) {
          final item = vm.items[index];
          return _BookmarkCard(
            item: item,
            cardWidth: cardWidth,
            onRemove: () async {
              final result = await vm.requestToggle(
                episodeId: item.episodeId,
                seasonId: item.seasonId,
              );
              if (!context.mounted) return;
              if (result == BookmarkToggleResult.success) {
                final label =
                    item.title.trim().isEmpty ? 'Video' : item.title.trim();
                AppToast.show(context, message: '$label Bookmark Removed');
              }
            },
          );
        },
      ),
    );
  }
}

// ── Bookmark card ─────────────────────────────────────────────────────────────

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.item,
    required this.cardWidth,
    required this.onRemove,
  });

  final BookmarkItemModel item;
  final double cardWidth;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = cardWidth * (9 / 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cardWidth,
          height: thumbHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Thumbnail(url: item.thumbnailUrl),

                // Gradient overlay
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Bookmark icon (active) — tap to remove
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        'assets/icons/book_mark_selected.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          item.title.isNotEmpty ? item.title : '—',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _kDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});
  final String url;

  static const _bg = Color(0xFFF0F0F0);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: _bg,
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Color(0xFFBBBBBB), size: 28),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: _bg),
      errorWidget: (_, _, _) => Container(
        color: _bg,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Color(0xFFBBBBBB), size: 24),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBookmarksView extends StatelessWidget {
  const _EmptyBookmarksView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEDF4),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const Icon(
                  Icons.bookmark_border_rounded,
                  size: 46,
                  color: Color(0xFF8B9DC8),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'No bookmarks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Tap the bookmark icon on any video to save it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9E9E9E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
