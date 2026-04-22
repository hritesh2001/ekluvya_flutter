import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lightweight, non-blocking overlay toast.
///
/// Usage:
///   AppToast.show(context, message: 'You have successfully logged in');
class AppToast {
  static const _successIconUrl =
      'https://stg-ott.ekluvya.guru/toast-success.9d366c9fe2c579e3.svg';

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        iconUrl: _successIconUrl,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    // rootOverlay: true so the toast persists across route transitions.
    Overlay.of(context, rootOverlay: true).insert(entry);
  }
}

// ── Toast view ────────────────────────────────────────────────────────────────

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.iconUrl,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final String iconUrl;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>  _fade;
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPad + 96, // sits above bottom nav bar
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // SVG icon with Material fallback on load/error
                  SvgPicture.network(
                    widget.iconUrl,
                    width: 26,
                    height: 26,
                    placeholderBuilder: (_) => const _SuccessIcon(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fallback icon shown while SVG loads ────────────────────────────────────────

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4CAF50),
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}
