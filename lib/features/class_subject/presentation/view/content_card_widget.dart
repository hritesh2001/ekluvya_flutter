import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const Color _cardBg      = Color(0xFFF0F0F0);
const Color _shimmerBase = Color(0xFFE8E8E8);
const Color _shimmerHigh = Color(0xFFF8F8F8);
const Color _titleColor  = Color(0xFF1A1A1A);
const Color _metaColor   = Color(0xFF5E6278);

/// Individual video / chapter card.
///
/// Thumbnail overlay:
///   • Centre white play button
///   • Top-right bookmark: default = white outline, tapped = filled pink
class ContentCardWidget extends StatefulWidget {
  const ContentCardWidget({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    required this.cardWidth,
    this.onTap,
    this.rating,
  });

  final String title;
  final String thumbnailUrl;
  final double cardWidth;
  final VoidCallback? onTap;
  final double? rating;

  /// Thumbnail height = width × this ratio (16:9).
  static const double thumbAspect = 9 / 16;

  @override
  State<ContentCardWidget> createState() => _ContentCardWidgetState();
}

class _ContentCardWidgetState extends State<ContentCardWidget> {
  bool _bookmarked = false;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = widget.cardWidth * ContentCardWidget.thumbAspect;

    return Semantics(
      label: widget.title,
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Thumbnail ───────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: widget.cardWidth,
                  height: thumbHeight,
                  child: Stack(
                    children: [
                      // Background image
                      SizedBox(
                        width: widget.cardWidth,
                        height: thumbHeight,
                        child: widget.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.thumbnailUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: (widget.cardWidth * 2).round(),
                                fadeInDuration:
                                    const Duration(milliseconds: 150),
                                fadeOutDuration:
                                    const Duration(milliseconds: 80),
                                filterQuality: FilterQuality.medium,
                                placeholder: (_, _) => _ShimmerBox(
                                  width: widget.cardWidth,
                                  height: thumbHeight,
                                ),
                                errorWidget: (_, _, _) => _PlaceholderBox(
                                  width: widget.cardWidth,
                                  height: thumbHeight,
                                ),
                              )
                            : _PlaceholderBox(
                                width: widget.cardWidth,
                                height: thumbHeight,
                              ),
                      ),

                      // Subtle bottom gradient
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: thumbHeight * 0.35,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.30),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Centre play button — custom SVG
                      Positioned.fill(
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/videoplaythumbnail.svg',
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ),

                      // Bottom-right bookmark toggle
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _bookmarked = !_bookmarked),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _bookmarked
                                // Selected — filled pink, original SVG colors
                                ? SvgPicture.asset(
                                    'assets/icons/book_mark_selected.svg',
                                    width: 20,
                                    height: 20,
                                  )
                                // Default — outline, white tint
                                : SvgPicture.asset(
                                    'assets/icons/book_mark_select.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ── Title ───────────────────────────────────────────────
              Text(
                widget.title.isNotEmpty ? widget.title : '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              // ── Optional rating row ─────────────────────────────────
              if (widget.rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF5B800), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      widget.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _metaColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(12),
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
              colors: const [_shimmerBase, _shimmerHigh, _shimmerBase],
            ),
          ),
        ),
      ),
    );
  }
}
