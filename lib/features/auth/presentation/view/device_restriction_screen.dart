import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodel/session_viewmodel.dart';

const _kBrand = Color(0xFFE91E63);
const _kBg = Color(0xFF0A0A0F);
const _kSurface = Color(0xFF141420);
const _kWarning = Color(0xFFFF6B35);

/// Shown when [SessionViewModel.isDeviceRestricted] is true.
/// Blocks access and gives the user a path to log out.
class DeviceRestrictionScreen extends StatelessWidget {
  const DeviceRestrictionScreen({super.key});

  static const routeName = '/device-restriction';

  static Route<void> route() => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const DeviceRestrictionScreen(),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // ── Warning icon ──────────────────────────────────────
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kWarning.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: _kWarning.withValues(alpha: 0.20),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.devices_other_rounded,
                    color: _kWarning,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Heading ───────────────────────────────────────────
                const Text(
                  'Device Limit Reached',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Body text ─────────────────────────────────────────
                const Text(
                  'Your account has reached the maximum number of allowed devices or profiles.\n\n'
                  'To continue, please log out from another device or contact support to upgrade your plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Info card ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _kWarning.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: _kWarning.withValues(alpha: 0.8), size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Maximum 2 profiles are allowed per account.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Logout CTA ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Log Out & Switch Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Contact support ───────────────────────────────────
                GestureDetector(
                  onTap: () => _contactSupport(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Contact Support',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    context.read<SessionViewModel>().logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _contactSupport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact support@ekluvya.guru for assistance'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E1E30),
      ),
    );
  }
}
