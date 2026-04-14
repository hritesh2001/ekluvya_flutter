import 'package:flutter/material.dart';

import 'content_card_widget.dart';

// ── Data model ────────────────────────────────────────────────────────────────

/// A single content item (video / chapter card) displayed inside a section.
///
/// Future: populate from the chapters / videos API response.
class ContentItemData {
  const ContentItemData({
    required this.id,
    required this.title,
    this.thumbnailUrl = '',
    this.videosLabel,
    this.rating,
  });

  final String id;
  final String title;
  final String thumbnailUrl;

  /// e.g. "14 VIDEOS"
  final String? videosLabel;
  final double? rating;
}

/// A collection of content items grouped by their source.
///
/// Future: map directly from the API `/home/chapters` or `/home/videos`
/// response envelope once that endpoint is integrated.
class ContentSectionData {
  const ContentSectionData({
    required this.id,
    required this.sourceName,
    required this.videoCount,
    required this.items,
    this.sourceColor,
    this.rating,
  });

  final String id;

  /// Channel / provider name: "Ekluvya", "Tutorials", etc.
  final String sourceName;

  /// Total video count for this section.
  final int videoCount;

  final List<ContentItemData> items;

  /// Accent colour used for the source avatar background.
  final Color? sourceColor;

  final double? rating;
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Renders one content provider section:
///   [Header row]  →  source avatar · name · video count · rating · View All
///   [Card row  ]  →  horizontal scrollable list of [ContentCardWidget]s
///
/// Card width is computed from [LayoutBuilder] so the widget is fully
/// responsive. Cards are capped at [_maxCardWidth] to avoid overly wide
/// cards on tablets.
class ContentSectionWidget extends StatelessWidget {
  const ContentSectionWidget({
    super.key,
    required this.section,
    this.onViewAll,
  });

  final ContentSectionData section;
  final VoidCallback? onViewAll;

  // Card sizing
  static const double _minCardWidth = 140.0;
  static const double _maxCardWidth = 180.0;

  double _cardWidth(double available) =>
      (available * 0.38).clamp(_minCardWidth, _maxCardWidth);

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = _cardWidth(constraints.maxWidth);
        // Card height = thumb (16:9) + title area (≈42) + meta (≈16)
        final thumbH = cardW * ContentCardWidget.thumbAspect;
        final listHeight = thumbH + 64;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ────────────────────────────────────────
            _SectionHeader(
              section: section,
              onViewAll: onViewAll,
            ),

            const SizedBox(height: 10),

            // ── Horizontal card list ──────────────────────────────────
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: section.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = section.items[index];
                  return ContentCardWidget(
                    title: item.title,
                    thumbnailUrl: item.thumbnailUrl,
                    cardWidth: cardW,
                    videosLabel: item.videosLabel,
                    rating: item.rating,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Section header — light surface palette ────────────────────────────────

/// Source name (e.g. "Ekluvya") uses the brand pink — matches the design.
const Color _headerTextColor = Color(0xFFE91E63); // brand pink
const Color _metaTextColor   = Color(0xFF666666); // medium grey on white
const Color _brandPink       = Color(0xFFE91E63);
const Color _starGold        = Color(0xFFF5B800);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, this.onViewAll});

  final ContentSectionData section;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Source avatar ─────────────────────────────────────────
          _SourceAvatar(
            name: section.sourceName,
            color: section.sourceColor ?? _brandPink,
          ),

          const SizedBox(width: 8),

          // ── Name + meta (expands to fill) ─────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.sourceName,
                  style: const TextStyle(
                    color: _headerTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Video count
                    const Icon(Icons.remove_red_eye_outlined,
                        color: _metaTextColor, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '${section.videoCount} VIDEOS',
                      style: const TextStyle(
                          color: _metaTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),

                    // Rating
                    if (section.rating != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.star_rounded,
                          color: _starGold, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        section.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                            color: _metaTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── View All button ───────────────────────────────────────
          GestureDetector(
            onTap: onViewAll,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    color: _brandPink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    color: _brandPink, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source avatar circle ──────────────────────────────────────────────────────

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
