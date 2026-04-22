import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../features/badge/data/models/badge_model.dart';
import '../../../../features/video_access/domain/entities/video_access_status.dart';
import 'content_card_widget.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class ContentItemData {
  const ContentItemData({
    required this.id,
    required this.title,
    this.slug = '',
    this.hlsUrl = '',
    this.thumbnailUrl = '',
    this.rating,
    this.episodeIndex = 0,
    // Default to `free` so any card that omits access status is never
    // accidentally shown as locked.
    this.accessStatus = VideoAccessStatus.free,
  });

  final String id;
  final String title;
  final String slug;
  final String hlsUrl;
  final String thumbnailUrl;
  final double? rating;
  final int episodeIndex;

  /// Drives the lock overlay and FREE badge on the card.
  /// Computed by [CheckVideoAccessUseCase] in the screen layer and stored
  /// here so the card widget itself is a pure presenter — no state reads.
  final VideoAccessStatus accessStatus;
}

class ContentSectionData {
  const ContentSectionData({
    required this.id,
    required this.sourceName,
    required this.videoCount,
    required this.items,
    this.rating,
    this.badges = const [],
  });

  final String id;
  final String sourceName;
  final int videoCount;
  final List<ContentItemData> items;

  /// average_rating from ratings API (0–5). null = not available.
  final double? rating;

  /// Winner badges for this partner (Most Loved / Most Watched).
  final List<BadgeInfo> badges;
}

// ── Widget ────────────────────────────────────────────────────────────────────

class ContentSectionWidget extends StatelessWidget {
  const ContentSectionWidget({
    super.key,
    required this.section,
    this.onViewAll,
    this.onItemTap,
  });

  final ContentSectionData section;
  final VoidCallback? onViewAll;
  final void Function(ContentItemData)? onItemTap;

  static const double _minCardWidth = 160.0;
  static const double _maxCardWidth = 220.0;

  double _cardWidth(double available) =>
      (available * 0.46).clamp(_minCardWidth, _maxCardWidth);

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW      = _cardWidth(constraints.maxWidth);
        final thumbH     = cardW * ContentCardWidget.thumbAspect;
        final listHeight = thumbH + 56;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(section: section, onViewAll: onViewAll),
            const SizedBox(height: 10),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: section.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  // Guard: never crash on out-of-bounds (defensive, belt+braces).
                  if (index < 0 || index >= section.items.length) {
                    return const SizedBox.shrink();
                  }
                  final item = section.items[index];
                  return GestureDetector(
                    // ValueKey forces widget recreation when item identity changes,
                    // preventing CachedNetworkImage from crossfading a cached
                    // thumbnail from the previous item at the same list index.
                    key: ValueKey(item.id),
                    behavior: HitTestBehavior.opaque,
                    onTap: onItemTap != null ? () => onItemTap!(item) : null,
                    child: ContentCardWidget(
                      title: item.title,
                      thumbnailUrl: item.thumbnailUrl,
                      cardWidth: cardW,
                      rating: item.rating,
                      accessStatus: item.accessStatus,
                    ),
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

// ── Design tokens ─────────────────────────────────────────────────────────────

const Color _nameColor    = Color(0xFFEE4166); // brand pink — partner name
const Color _metaColor    = Color(0xFFEE4166); // brand pink — videos + rating
const Color _viewAllColor = Color(0xFFEE4166); // brand pink — View All
const Color _starGold     = Color(0xFFFFC107); // gold star

// ── Section header ─────────────────────────────────────────────────────────────
//
//  Single row, left → right:
//  [PARTNER NAME] [❤ if loved] [👁 if watched] [🎬 N VIDEOS] [⭐ 4.0]  [View All >]

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, this.onViewAll});

  final ContentSectionData section;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final isMostLoved   = section.badges.any((b) => b.isMostLoved);
    final isMostWatched = section.badges.any((b) => b.isMostWatched);
    final hasRating     = section.rating != null && section.rating! > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Partner name ──────────────────────────────────────────
          Text(
            section.sourceName.toUpperCase(),
            style: const TextStyle(
              color: _nameColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          if (isMostLoved) ...[
            const SizedBox(width: 8),
            Image.asset('assets/icons/mostloved.png', width: 26, height: 26),
          ],

          if (isMostWatched) ...[
            const SizedBox(width: 8),
            Image.asset('assets/icons/mostwatched.png', width: 26, height: 26),
          ],

          const SizedBox(width: 12),
          SvgPicture.asset('assets/icons/video.svg', width: 14, height: 14),
          const SizedBox(width: 4),
          Text(
            '${section.videoCount} VIDEOS',
            style: const TextStyle(
              color: _metaColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (hasRating) ...[
            const SizedBox(width: 12),
            const Icon(Icons.star_rounded, color: _starGold, size: 16),
            const SizedBox(width: 4),
            Text(
              section.rating!.toStringAsFixed(1),
              style: const TextStyle(
                color: _metaColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const Spacer(),

          GestureDetector(
            onTap: onViewAll,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'View All',
                    style: const TextStyle(
                      color: _viewAllColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _viewAllColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
