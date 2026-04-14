import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// OTT-style course card.
///
/// Fully decoupled from any data model — accepts plain [title] and [imageUrl]
/// strings so it can be reused across School, College, Life Skills sections
/// (or any future section) without modification.
///
/// Visual spec:
///   - Rounded corners (12 px radius).
///   - Full-image background with [BoxFit.cover].
///   - Solid semi-transparent black box pinned to the bottom.
///   - [title] centered in the box — single line with ellipsis.
///   - Responsive: [cardWidth] is injected by the parent via LayoutBuilder.
///
/// Edge cases handled:
///   - Empty / null [imageUrl] → grey placeholder with play icon.
///   - Broken image URL → same placeholder (errorWidget).
///   - Empty / null [title] → shows "—" fallback.
class CourseCardWidget extends StatelessWidget {
  const CourseCardWidget({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    required this.cardWidth,
  });

  /// Course display name — shown in the bottom label box.
  final String title;

  /// Remote image URL — loaded by CachedNetworkImage.
  final String imageUrl;

  final VoidCallback onTap;

  /// Card width injected by the parent LayoutBuilder.
  /// Card height = [cardWidth] × [_aspectRatio].
  final double cardWidth;

  /// Height : width ratio — slightly taller than square.
  /// Public so [CourseSectionWidget] can derive the list height from the
  /// same constant, keeping dimensions in sync without duplication.
  static const double aspectRatio = 1.15;

  // ── Colours (const — not subject to theme) ────────────────────────────────

  /// The bottom label box background.
  /// 0xBB = ~73 % opacity black — opaque enough to read on any image.
  static const _labelBoxColor = Color(0xBB000000);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final cardHeight = cardWidth * aspectRatio;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Full-image background ──────────────────────────────
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, url) => _placeholder(colors),
                      errorWidget: (_, url, err) => _placeholder(colors),
                    )
                  : _placeholder(colors),

              // ── Solid label box at bottom ──────────────────────────
              // Distinct solid box (not a gradient) — matches reference UI.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: const BoxDecoration(
                    color: _labelBoxColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    title.isNotEmpty ? title : '—',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors colors) {
    return Container(
      color: colors.imagePlaceholder,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 40,
          color: colors.metaText.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
