import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ── Design tokens — light surface (cards sit on white background) ─────────────

const Color _cardBg      = Color(0xFFF0F0F0); // light placeholder bg
const Color _shimmerBase = Color(0xFFE8E8E8); // light shimmer base
const Color _shimmerHigh = Color(0xFFF8F8F8); // light shimmer highlight
const Color _titleColor  = Color(0xFF1A1A1A); // dark text on white
const Color _metaColor   = Color(0xFF888888); // medium grey meta text

/// Individual video / chapter card.
///
/// Layout (top → bottom):
///   ┌──────────────────────────┐
///   │  Thumbnail (16:9 ratio)  │
///   ├──────────────────────────┤
///   │  Title (2 lines max)     │
///   │  Meta  (optional)        │
///   └──────────────────────────┘
///
/// [cardWidth] is injected by the parent — lets [ContentSectionWidget] keep
/// all sibling cards the same size without using a ListView intrinsic.
///
/// Both image-loading states (placeholder + error) use a shimmer gradient so
/// the card never shows an unstyled empty box.
class ContentCardWidget extends StatelessWidget {
  const ContentCardWidget({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    required this.cardWidth,
    this.onTap,
    this.videosLabel,
    this.rating,
  });

  final String title;
  final String thumbnailUrl;

  /// Injected width — height derived from [_thumbAspect].
  final double cardWidth;

  final VoidCallback? onTap;

  /// Optional "14 VIDEOS" label shown under the title.
  final String? videosLabel;

  /// Optional numeric star rating shown with a gold star.
  final double? rating;

  /// Thumbnail height = width × this ratio  (16 : 9).
  /// Public so sibling widgets ([ContentSectionWidget]) can derive the
  /// list height from the same constant without duplicating the value.
  static const double thumbAspect = 9 / 16;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = cardWidth * thumbAspect;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Thumbnail ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: cardWidth,
                height: thumbHeight,
                child: thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _ShimmerBox(
                          width: cardWidth,
                          height: thumbHeight,
                        ),
                        errorWidget: (_, _, _) => _PlaceholderBox(
                          width: cardWidth,
                          height: thumbHeight,
                        ),
                      )
                    : _PlaceholderBox(
                        width: cardWidth,
                        height: thumbHeight,
                      ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Title ─────────────────────────────────────────────────
            Text(
              title.isNotEmpty ? title : '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _titleColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),

            // ── Optional meta row ─────────────────────────────────────
            if (videosLabel != null || rating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (videosLabel != null) ...[
                    const Icon(Icons.remove_red_eye_outlined,
                        color: _metaColor, size: 10),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        videosLabel!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _metaColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                  if (videosLabel != null && rating != null)
                    const SizedBox(width: 8),
                  if (rating != null) ...[
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF5B800), size: 10),
                    const SizedBox(width: 2),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(
                          color: _metaColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w400),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Internal loading/error boxes ──────────────────────────────────────────────

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Color(0xFFBBBBBB), size: 28),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
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
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: const [
                _shimmerBase,
                _shimmerHigh,
                _shimmerBase,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
