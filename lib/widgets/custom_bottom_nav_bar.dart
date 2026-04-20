import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const Color _activeColor  = Color(0xFFEE4166);
const Color _inactiveColor = Color(0xFF9E9E9E);

// ── Dimensions ────────────────────────────────────────────────────────────────
const double _barHeight    = 72.0;
const double _fabSize      = 62.0;   // gradient circle — no white ring
const double _bottomMargin = 14.0;   // gap below bar from screen bottom
const double _fabOverhang  = _fabSize / 2; // 31 px — FAB centre sits on bar top edge

/// Base height of the pill+FAB content (excludes system nav bar inset).
/// The widget adds MediaQuery.viewPaddingOf(context).bottom on top at runtime.
const double kNavBarTotalHeight = _barHeight + _bottomMargin + _fabOverhang; // 117

// Notch arc radius matches FAB radius exactly → seamless cup with no air gap.
// The white bar wraps the lower half of the gradient circle (the 3/4-around look).
const double _notchRadius = _fabSize / 2; // 31 px

// ── Nav item data ─────────────────────────────────────────────────────────────

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.selectedAsset,
    required this.unselectedAsset,
    this.tintUnselected = false,
  });

  final String label;
  final String selectedAsset;
  final String unselectedAsset;
  final bool tintUnselected;
}

const List<_NavItemData> _items = [
  _NavItemData(
    label: 'Course',
    selectedAsset:   'assets/icons/course_selected.svg',
    unselectedAsset: 'assets/icons/course_unselected.svg',
  ),
  _NavItemData(
    label: 'Search',
    selectedAsset:   'assets/icons/search_selected.svg',
    unselectedAsset: 'assets/icons/search_unselected.svg',
  ),
  _NavItemData(
    label: 'Explore',
    selectedAsset:   'assets/icons/explore_selected.svg',
    unselectedAsset: 'assets/icons/explore_unselected.svg',
  ),
  _NavItemData(
    label: 'Bookmark',
    selectedAsset:   'assets/icons/book_mark_selected.svg',
    unselectedAsset: 'assets/icons/book_mark_select.svg',
    tintUnselected: true,
  ),
];

// ── Root widget ───────────────────────────────────────────────────────────────

/// Floating pill navigation bar with a curved notch and a centred gradient FAB.
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.onHomeTapped,
  });

  /// 0 = Course · 1 = Search · 2 = Explore · 3 = Bookmark
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final VoidCallback? onHomeTapped;

  @override
  Widget build(BuildContext context) {
    // Consume the bottom view-padding directly so the pill is always clear of
    // the system navigation bar regardless of Scaffold's internal positioning
    // timing (e.g., the one-frame race after exiting the immersive video player
    // where MediaQuery.padding.bottom may still be 0).
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // FAB centre sits exactly on the bar's top edge.
    // fabBottom = distance from widget bottom (after inset) to FAB centre bottom.
    final fabBottom = _bottomMargin + _barHeight - _fabSize / 2; // = 55 px

    return SizedBox(
      height: kNavBarTotalHeight + bottomInset,
      child: Padding(
        // Push the whole pill+FAB group up by the system nav bar height.
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── Notched pill ────────────────────────────────────────────
            Positioned(
              bottom: _bottomMargin,
              left: 16,
              right: 16,
              height: _barHeight,
              child: _NotchedPill(
                selectedIndex: selectedIndex,
                onItemTapped: onItemTapped,
              ),
            ),

            // ── Home FAB ────────────────────────────────────────────────
            Positioned(
              bottom: fabBottom,
              child: _HomeFab(onTap: onHomeTapped),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notched pill ──────────────────────────────────────────────────────────────

class _NotchedPill extends StatelessWidget {
  const _NotchedPill({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _NotchedNavbarPainter(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItemWidget(
            data: _items[0],
            isSelected: selectedIndex == 0,
            onTap: () => onItemTapped(0),
          ),
          _NavItemWidget(
            data: _items[1],
            isSelected: selectedIndex == 1,
            onTap: () => onItemTapped(1),
          ),
          // Centre gap — keeps tab items clear of the notch
          const SizedBox(width: _fabSize + 8),
          _NavItemWidget(
            data: _items[2],
            isSelected: selectedIndex == 2,
            onTap: () => onItemTapped(2),
          ),
          _NavItemWidget(
            data: _items[3],
            isSelected: selectedIndex == 3,
            onTap: () => onItemTapped(3),
          ),
        ],
      ),
    );
  }
}

// ── Notch painter ─────────────────────────────────────────────────────────────

/// Paints a pill-shaped navbar with a concave semicircular notch at the top-centre.
///
/// Geometry:
///   • Pill corners: radius 35 px
///   • Notch: arc radius = _notchRadius = 31 px (= FAB radius)
///     Spans from (cx − 31, 0) → (cx + 31, 0), dipping DOWN 31 px.
///     clockwise: false in Flutter y-down coords sweeps the bottom semicircle,
///     creating a concave cup that matches the FAB circle exactly.
class _NotchedNavbarPainter extends CustomPainter {
  const _NotchedNavbarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawShadow(path, const Color(0xFF000000), 10.0, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  Path _buildPath(Size size) {
    const r  = 35.0;
    const nR = _notchRadius; // 31
    final cx = size.width / 2;

    final notchLeft  = cx - nR;
    final notchRight = cx + nR;

    return Path()
      ..moveTo(r, 0)
      ..lineTo(notchLeft, 0)
      // clockwise: false → sweeps DOWNWARD in Flutter y-down, creating the concave cup
      ..arcToPoint(
        Offset(notchRight, 0),
        radius: const Radius.circular(nR),
        clockwise: false,
      )
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r),               radius: const Radius.circular(r))
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height), radius: const Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r),          radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0),                        radius: const Radius.circular(r))
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Individual nav item ───────────────────────────────────────────────────────

class _NavItemWidget extends StatelessWidget {
  const _NavItemWidget({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _activeColor : _inactiveColor;

    final ColorFilter? unselectedFilter = data.tintUnselected
        ? const ColorFilter.mode(_inactiveColor, BlendMode.srcIn)
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: _barHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              isSelected ? data.selectedAsset : data.unselectedAsset,
              width: 24,
              height: 24,
              colorFilter: isSelected ? null : unselectedFilter,
            ),
            const SizedBox(height: 5),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center FAB ────────────────────────────────────────────────────────────────

class _HomeFab extends StatelessWidget {
  const _HomeFab({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: Transform.scale(
          // Scale up so the gradient circle fills the clip boundary,
          // eliminating the transparent padding ring in the PNG that
          // would otherwise show the white bar behind as a halo.
          scale: 1.18,
          child: Image.asset(
            'assets/icons/home_button_vector.png',
            width: _fabSize,
            height: _fabSize,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
