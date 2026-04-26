import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/connectivity_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/viewmodel/session_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NetworkGuard
// ─────────────────────────────────────────────────────────────────────────────
//
// Place inside MaterialApp.builder so it sits above all routes but inside
// the Navigator.  Listens to NetworkService and shows ONE blocking popup
// when the device goes offline.  The popup auto-dismisses when connectivity
// is restored; the Retry button forces an immediate re-check.
//
// Usage (main.dart):
//   builder: (context, child) {
//     return NetworkGuard(child: child ?? const SizedBox.shrink());
//   },

class NetworkGuard extends StatefulWidget {
  final Widget child;
  const NetworkGuard({super.key, required this.child});

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard>
    with WidgetsBindingObserver {
  NetworkService? _ns;
  bool _dialogShowing = false;
  StreamSubscription<void>? _forceLogoutSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ns = context.read<NetworkService>();
      _ns!.addListener(_onNetworkChanged);
      if (!_ns!.isOnline) _showPopup();

      // Navigate to /login whenever SessionViewModel detects a server-side
      // token revocation (401 from any API call, including logout-all from
      // another device or platform).
      final sessionVM = context.read<SessionViewModel>();
      _forceLogoutSub = sessionVM.onForceLogout.listen((_) => _onForceLogout());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ns?.removeListener(_onNetworkChanged);
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-validate token on every app resume.  Catches expired JWTs and
      // also triggers a background profile fetch that will surface a 401 if
      // the token was revoked by logout-all from another device.
      context.read<SessionViewModel>().checkTokenOnResume();
    }
  }

  // ── Force logout navigation ────────────────────────────────────────────────

  void _onForceLogout() {
    if (!mounted) return;
    // Remove all routes and land on /login so the user must re-authenticate.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // ── Network popup ──────────────────────────────────────────────────────────

  void _onNetworkChanged() {
    if (!mounted) return;
    if (!(_ns?.isOnline ?? true) && !_dialogShowing) {
      _showPopup();
    }
    // The popup listens to NetworkService itself and pops when online.
  }

  Future<void> _showPopup() async {
    if (!mounted || _dialogShowing) return;
    _dialogShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _NetworkPopup(networkService: _ns!),
    );
    _dialogShowing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// _NetworkPopup
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkPopup extends StatefulWidget {
  final NetworkService networkService;
  const _NetworkPopup({required this.networkService});

  @override
  State<_NetworkPopup> createState() => _NetworkPopupState();
}

class _NetworkPopupState extends State<_NetworkPopup> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.networkService.addListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    widget.networkService.removeListener(_onNetworkChanged);
    super.dispose();
  }

  void _onNetworkChanged() {
    if (!mounted) return;
    if (widget.networkService.isOnline) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    await widget.networkService.checkNow();
    if (mounted) setState(() => _checking = false);
    // _onNetworkChanged auto-pops the dialog if now online.
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return PopScope(
      canPop: false, // block hardware back button while offline
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ───────────────────────────────────────────────
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 38,
                  color: colors.brand,
                ),
              ),

              const SizedBox(height: 22),

              // ── Title ──────────────────────────────────────────────
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // ── Body ───────────────────────────────────────────────
              Text(
                'Please check your internet connection and try again.',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.metaText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // ── Retry button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : _retry,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        colors.brand.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.refresh_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
