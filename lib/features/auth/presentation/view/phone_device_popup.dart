import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../../../../viewmodels/auth_viewmodel.dart';
import '../viewmodel/phone_device_viewmodel.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg       = Color(0xFFFFFFFF);
const _kWarning  = Color(0xFFFFF3E0);
const _kOrange   = Color(0xFFF57C00);
const _kDark     = Color(0xFF1A1A1A);
const _kGray     = Color(0xFF757575);
const _kDivider  = Color(0xFFF0F0F0);
const _kYellow   = Color(0xFFFFD600);
const _kRed      = Color(0xFFE53935);

// ─────────────────────────────────────────────────────────────────────────────

/// Presents the device-limit dialog.  Call [PhoneDevicePopup.show] from the
/// OTP screen when [AuthViewModel.isPhoneDeviceLimited] is true.
///
/// Returns true when the user successfully signs out and re-authenticates so
/// the caller can proceed with the post-login flow.
class PhoneDevicePopup {
  static Future<bool> show(BuildContext context) async {
    final api     = context.read<ApiService>();
    final authVM  = context.read<AuthViewModel>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => ChangeNotifierProvider(
        create: (_) => PhoneDeviceViewModel(api: api, authVM: authVM),
        child: const _PhoneDeviceDialog(),
      ),
    );
    return result == true;
  }
}

// ── Dialog shell ──────────────────────────────────────────────────────────────

class _PhoneDeviceDialog extends StatelessWidget {
  const _PhoneDeviceDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Consumer<PhoneDeviceViewModel>(
        builder: (context, vm, _) {
          return _DialogCard(vm: vm);
        },
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.vm});

  final PhoneDeviceViewModel vm;

  @override
  Widget build(BuildContext context) {
    final authVM  = context.read<AuthViewModel>();
    final devices = authVM.phoneLoginDevices;
    final phone   = authVM.loginUsername;

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top bar: logo + close ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Image.asset('assets/logo/ekluvya_logo.png',
                    height: 32, errorBuilder: (_, _, _) => const SizedBox(width: 80, height: 32)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kDark),
                  onPressed: vm.isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // ── Warning banner ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kWarning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _kOrange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Multiple Device Sign-In Detected',
                      style: TextStyle(
                        color: _kOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Description ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are signed in on ${devices.length} device${devices.length == 1 ? '' : 's'}. '
                  'Sign out from one device to continue.',
                  style: const TextStyle(
                    color: _kDark,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Phone number row
                Row(
                  children: [
                    Text(
                      '+91 $phone',
                      style: const TextStyle(
                        color: _kDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: vm.isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: _kYellow,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _kYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5, color: _kDivider),

          // ── Device list ───────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.30,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: devices.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, thickness: 0.5, color: _kDivider),
              itemBuilder: (context, index) {
                final device = devices[index];
                return _DeviceRow(device: device, vm: vm);
              },
            ),
          ),

          const Divider(height: 1, thickness: 0.5, color: _kDivider),

          // ── Error message ─────────────────────────────────────────
          if (vm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                vm.errorMessage!,
                style: const TextStyle(color: _kRed, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Sign out all link / loading ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: vm.isLoading
                ? const Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: _kYellow, strokeWidth: 2.5),
                    ),
                  )
                : GestureDetector(
                    onTap: () async {
                      final success = await vm.logoutAllAndContinue();
                      if (!context.mounted) return;
                      if (success) Navigator.of(context).pop(true);
                    },
                    child: const Text(
                      'Sign out from all devices & continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: _kRed,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Individual device row ─────────────────────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.vm});

  final dynamic device; // DeviceInfoModel
  final PhoneDeviceViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t       = device.deviceType.toLowerCase();
    final isIos     = t == 'ios' || t.contains('iphone');
    final isAndroid = t == 'android' || t == 'mobile';
    final isWeb     = t == 'web';

    final icon = isIos
        ? Icons.phone_iphone_rounded
        : isAndroid
            ? Icons.phone_android_rounded
            : isWeb
                ? Icons.laptop_rounded
                : Icons.devices_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Device icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: _kGray),
          ),
          const SizedBox(width: 12),

          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: const TextStyle(
                    color: _kDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (device.lastLoginAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    device.formattedLastLogin,
                    style: const TextStyle(color: _kGray, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Sign out button
          GestureDetector(
            onTap: vm.isLoading
                ? null
                : () async {
                    final success = await vm.logoutDeviceAndContinue(
                      deviceToken: device.accessToken,
                    );
                    if (!context.mounted) return;
                    if (success) Navigator.of(context).pop(true);
                  },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _kRed.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sign out',
                style: TextStyle(
                  color: _kRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
