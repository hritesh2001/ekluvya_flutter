import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../viewmodels/auth_viewmodel.dart';
import '../../../../widgets/app_toast.dart';
import '../../presentation/viewmodel/session_viewmodel.dart';
import '../viewmodel/device_viewmodel.dart';

const _kPink   = Color(0xFFE91E63);
const _kOrange = Color(0xFFFF5722);

class DeviceRestrictionScreen extends StatefulWidget {
  const DeviceRestrictionScreen({super.key});

  static const routeName = '/device-restriction';

  @override
  State<DeviceRestrictionScreen> createState() =>
      _DeviceRestrictionScreenState();
}

class _DeviceRestrictionScreenState extends State<DeviceRestrictionScreen> {
  Future<void> _handleDeviceLogout(String deviceId) async {
    final vm  = context.read<DeviceViewModel>();
    final nav = Navigator.of(context);
    final ok  = await vm.logoutDevice(deviceId);
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, message: 'Signed in successfully');
      nav.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  Future<void> _handleLogoutAll() async {
    final vm  = context.read<DeviceViewModel>();
    final nav = Navigator.of(context);
    final ok  = await vm.logoutAllAndRelogin();
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, message: 'Signed in successfully');
      nav.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  void _goToLogin() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── X close button ───────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF333333), size: 22),
                  onPressed: _goToLogin,
                ),
              ),
            ),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                child: _Body(
                  onDeviceLogout: _handleDeviceLogout,
                  onLogoutAll:    _handleLogoutAll,
                  onChange:       _goToLogin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.onDeviceLogout,
    required this.onLogoutAll,
    required this.onChange,
  });

  final Future<void> Function(String deviceId) onDeviceLogout;
  final Future<void> Function() onLogoutAll;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final authVM    = context.watch<AuthViewModel>();
    final sessionVM = context.watch<SessionViewModel>();
    final vm        = context.watch<DeviceViewModel>();

    final devices  = authVM.activeDevices;
    final username = authVM.loginUsername;
    final count    = sessionVM.deviceCount > 0
        ? sessionVM.deviceCount
        : (devices.isNotEmpty ? devices.length : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── EKLUVYA logo ─────────────────────────────────────────────
        Center(child: _EkluvyaLogo()),
        const SizedBox(height: 20),

        // ── Warning banner ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _kPink, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Warning: Reached Your Device Limit.',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Title ────────────────────────────────────────────────────
        const Text(
          'Sign out from this device',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D0D0D),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),

        // ── Body text ────────────────────────────────────────────────
        RichText(
          text: TextSpan(
            style: const TextStyle(
                color: Color(0xFF444444), fontSize: 14, height: 1.6),
            children: [
              const TextSpan(
                  text:
                      'As per your plan purchased you have used this account on '),
              TextSpan(
                text: '$count',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                  text:
                      ' device. Please sign out and continue to login.'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Current username + Change link ───────────────────────────
        if (username.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: Color(0xFF444444), fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: "You're Currently Signing in using "),
                TextSpan(
                  text: username.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onChange,
            child: const Text(
              'Change',
              style: TextStyle(
                color: _kPink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Error message ────────────────────────────────────────────
        if (vm.error != null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              vm.error!,
              style: TextStyle(
                  color: Colors.red.shade700, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Device cards ─────────────────────────────────────────────
        if (devices.isEmpty)
          _DeviceCard(
            deviceName: 'This Device',
            lastLogin:  'Current session',
            isLoading:  vm.isLoading && vm.loadingDeviceId == null,
            onSignOut:  () => onDeviceLogout('current'),
          )
        else
          ...devices.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceCard(
                  deviceName: d.displayName,
                  lastLogin:  d.formattedLastLogin,
                  isLoading:  vm.loadingDeviceId == d.id,
                  onSignOut:  () => onDeviceLogout(d.id),
                ),
              )),

        const SizedBox(height: 24),

        // ── Sign out from all ────────────────────────────────────────
        Center(
          child: vm.isLoading && vm.loadingDeviceId == null
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kPink),
                )
              : GestureDetector(
                  onTap: vm.isLoading ? null : onLogoutAll,
                  child: const Text(
                    'Sign Out from all devices & continue',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF555555),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Device card ───────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.deviceName,
    required this.lastLogin,
    required this.isLoading,
    required this.onSignOut,
  });

  final String deviceName;
  final String lastLogin;
  final bool isLoading;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // ── Device info ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D0D0D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last logged in $lastLogin',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Sign out button ────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D0D0D),
                disabledBackgroundColor: Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Sign out',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── EKLUVYA logo ──────────────────────────────────────────────────────────────

class _EkluvyaLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/app-logo.png',
          height: 32,
          errorBuilder: (_, _, _) => const SizedBox(width: 32, height: 32),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                letterSpacing: 1.2),
            children: [
              TextSpan(text: 'E', style: TextStyle(color: _kPink)),
              TextSpan(text: 'K', style: TextStyle(color: _kOrange)),
              TextSpan(text: 'L', style: TextStyle(color: _kPink)),
              TextSpan(text: 'U', style: TextStyle(color: _kOrange)),
              TextSpan(text: 'V', style: TextStyle(color: _kPink)),
              TextSpan(text: 'Y', style: TextStyle(color: _kOrange)),
              TextSpan(text: 'A', style: TextStyle(color: _kPink)),
            ],
          ),
        ),
      ],
    );
  }
}
