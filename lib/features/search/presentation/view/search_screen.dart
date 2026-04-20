import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../widgets/custom_bottom_nav_bar.dart';
import '../../data/models/search_result_model.dart';
import '../viewmodel/search_viewmodel.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const Color _barBg       = Color(0xFFF2F2F2); // search bar fill
const Color _hintColor   = Color(0xFF9E9E9E); // placeholder + icons
const Color _titleColor  = Color(0xFF1A1A1A); // result title
const Color _divColor    = Color(0xFFEEEEEE); // row divider
const Color _badgeBg     = Color(0xFFFFC107); // amber "Series" badge
const Color _badgeFg     = Color(0xFF1A1A1A); // badge text

// ── Entry point ───────────────────────────────────────────────────────────────

/// Standalone search tab — embedded in IndexedStack, NOT a Scaffold.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchViewModel _vm;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _vm    = SearchViewModel();
    _ctrl  = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _vm.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onClear() {
    _ctrl.clear();
    _vm.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ChangeNotifierProvider<SearchViewModel>.value(
      value: _vm,
      child: GestureDetector(
        // Dismiss keyboard when tapping outside the search bar / list.
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topPad),
            _SearchBar(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: _vm.onQueryChanged,
              onClear: _onClear,
            ),
            const Expanded(child: _SearchBody()),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _barBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded, color: _hintColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 15,
                  color: _titleColor,
                  height: 1.2,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: _hintColor,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
            // Clear button — only visible when text is non-empty.
            Selector<SearchViewModel, bool>(
              selector: (_, vm) => vm.query.isNotEmpty,
              builder: (_, hasText, _) => hasText
                  ? GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: _hintColor,
                          size: 18,
                        ),
                      ),
                    )
                  : const SizedBox(width: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body — switches between idle / loading / results / empty / error ──────────

class _SearchBody extends StatelessWidget {
  const _SearchBody();

  @override
  Widget build(BuildContext context) {
    return Selector<SearchViewModel, SearchState>(
      selector: (_, vm) => vm.state,
      builder: (_, state, _) => switch (state) {
        SearchState.idle    => const _IdleState(),
        SearchState.loading => const _LoadingState(),
        SearchState.loaded  => const _ResultsList(),
        SearchState.empty   => const _EmptyResults(),
        SearchState.error   => const _ErrorState(),
      },
    );
  }
}

// ── Idle / default state ──────────────────────────────────────────────────────

class _IdleState extends StatelessWidget {
  const _IdleState();

  @override
  Widget build(BuildContext context) {
    // Light theme → search_white.png  |  Dark theme → search_black.png
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            isDark
                ? 'assets/icons/search_black.png'
                : 'assets/icons/search_white.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for topic.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _titleColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: kNavBarTotalHeight +
            MediaQuery.viewPaddingOf(context).bottom +
            16,
      ),
      itemCount: 8,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: _divColor,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (_, _) => const _ShimmerRow(),
    );
  }
}

class _ShimmerRow extends StatefulWidget {
  const _ShimmerRow();

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _shimmer({double width = double.infinity, double height = 12, double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              Color(0xFFEAEAEA),
              Color(0xFFF8F8F8),
              Color(0xFFEAEAEA),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail placeholder
          _shimmer(width: 110, height: 65, radius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(height: 13),
                const SizedBox(height: 6),
                _shimmer(width: 160, height: 13),
                const SizedBox(height: 8),
                _shimmer(width: 50, height: 20, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList();

  @override
  Widget build(BuildContext context) {
    return Selector<SearchViewModel, List<SearchResultModel>>(
      selector: (_, vm) => vm.results,
      builder: (_, results, _) => ListView.separated(
        padding: EdgeInsets.only(
          bottom: kNavBarTotalHeight +
              MediaQuery.viewPaddingOf(context).bottom +
              16,
        ),
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: _divColor,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (_, i) => _ResultRow(
          key: ValueKey(results[i].id),
          item: results[i],
        ),
      ),
    );
  }
}

// ── Single result row ─────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({super.key, required this.item});

  final SearchResultModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Thumbnail ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 110,
              height: 65,
              child: item.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, _) => const ColoredBox(
                        color: Color(0xFFE8E8E8),
                      ),
                      errorWidget: (_, _, _) => const _ThumbFallback(),
                    )
                  : const _ThumbFallback(),
            ),
          ),
          const SizedBox(width: 12),
          // ── Text ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                const _SeriesBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Color(0xFFBBBBBB), size: 28),
        ),
      );
}

class _SeriesBadge extends StatelessWidget {
  const _SeriesBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _badgeBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Series',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _badgeFg,
            height: 1.2,
          ),
        ),
      );
}

// ── Empty results state ───────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: Color(0xFFCCCCCC)),
            SizedBox(height: 14),
            Text(
              'No results found.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a different search term.',
              style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchViewModel>(
      builder: (_, vm, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 52, color: Color(0xFFEE4166)),
              const SizedBox(height: 14),
              Text(
                vm.errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
