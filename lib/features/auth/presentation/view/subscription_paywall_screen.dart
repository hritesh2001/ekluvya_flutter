import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBrand = Color(0xFFE91E63);
const _kBg = Color(0xFF0A0A0F);
const _kSurface = Color(0xFF141420);
const _kDivider = Color(0xFF252535);

/// Full-screen subscription paywall — shown when a non-subscribed user taps a
/// locked video.  Push via [SubscriptionPaywallScreen.route].
class SubscriptionPaywallScreen extends StatelessWidget {
  const SubscriptionPaywallScreen({
    super.key,
    this.onSubscribe,
    this.onDismiss,
  });

  /// Optional callback when "Subscribe Now" is tapped.
  /// If null, tapping shows a snackbar placeholder.
  final VoidCallback? onSubscribe;

  /// Optional callback for "Maybe Later".
  final VoidCallback? onDismiss;

  static Route<void> route({
    VoidCallback? onSubscribe,
    VoidCallback? onDismiss,
  }) =>
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SubscriptionPaywallScreen(
          onSubscribe: onSubscribe,
          onDismiss: onDismiss,
        ),
      );

  /// Shows as a bottom sheet from any BuildContext.
  static Future<void> showSheet(
    BuildContext context, {
    VoidCallback? onSubscribe,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallSheet(onSubscribe: onSubscribe),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: onDismiss ?? () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white54, size: 24),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _PaywallContent(
                    onSubscribe:
                        onSubscribe ?? () => _handleSubscribeTap(context),
                    onDismiss:
                        onDismiss ?? () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubscribeTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription flow coming soon'),
        backgroundColor: _kBrand,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Bottom Sheet variant ──────────────────────────────────────────────────────

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet({this.onSubscribe});

  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Close
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white38, size: 22),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: _PaywallContent(
                compact: true,
                onSubscribe: onSubscribe ??
                    () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscription flow coming soon'),
                          backgroundColor: _kBrand,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                onDismiss: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared paywall content ────────────────────────────────────────────────────

class _PaywallContent extends StatelessWidget {
  const _PaywallContent({
    required this.onSubscribe,
    required this.onDismiss,
    this.compact = false,
  });

  final VoidCallback onSubscribe;
  final VoidCallback onDismiss;
  final bool compact;

  static const _features = [
    (Icons.play_circle_filled_rounded, 'Unlimited access to all videos'),
    (Icons.hd_rounded, 'HD & Full HD quality streaming'),
    (Icons.download_rounded, 'Offline downloads'),
    (Icons.devices_rounded, 'Watch on any device'),
    (Icons.school_rounded, 'Expert-curated study content'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Hero icon ──────────────────────────────────────────────────
        if (!compact) ...[
          const SizedBox(height: 12),
          _GlowIcon(),
          const SizedBox(height: 28),
        ] else ...[
          _GlowIcon(size: 60),
          const SizedBox(height: 20),
        ],

        // ── Heading ────────────────────────────────────────────────────
        const Text(
          'Unlock Premium\nAccess',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Continue your learning journey without limits',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        // ── Features list ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kDivider),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _features.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1, thickness: 1, color: _kDivider),
                _FeatureRow(
                  icon: _features[i].$1,
                  label: _features[i].$2,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Subscribe CTA ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kBrand.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Subscribe Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Dismiss link ───────────────────────────────────────────────
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Glow icon ─────────────────────────────────────────────────────────────────

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kBrand.withValues(alpha: 0.15),
        boxShadow: [
          BoxShadow(
            color: _kBrand.withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.lock_rounded,
        color: _kBrand,
        size: size * 0.45,
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kBrand, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: _kBrand, size: 18),
        ],
      ),
    );
  }
}
