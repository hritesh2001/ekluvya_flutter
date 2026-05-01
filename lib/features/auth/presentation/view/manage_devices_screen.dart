import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../widgets/app_toast.dart';
import '../../../../services/api_service.dart';
import '../../data/models/device_info_model.dart';
import '../../data/remote/manage_devices_api_service.dart';
import '../viewmodel/manage_devices_viewmodel.dart';
import '../viewmodel/session_viewmodel.dart';

// ── Brand constants ───────────────────────────────────────────────────────────

const _kGradStart = Color(0xFFE91E63);
const _kGradEnd   = Color(0xFFFF5722);
const _kDark      = Color(0xFF1A1A1A);
const _kGray      = Color(0xFF9E9E9E);
const _kDivider   = Color(0xFFF0F0F0);
const _kRed       = Color(0xFFE91E63);

// ─────────────────────────────────────────────────────────────────────────────

class ManageDevicesScreen extends StatelessWidget {
  const ManageDevicesScreen({super.key});

  static Route<void> route(BuildContext outerContext) =>
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ManageDevicesViewModel(
            authApi: outerContext.read<ApiService>(),
            sessionVM: outerContext.read<SessionViewModel>(),
            api: ManageDevicesApiService(),
          )..load(),
          child: const ManageDevicesScreen(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_kGradStart, _kGradEnd],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: topPad),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Manage Devices',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Balances the back button visually
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            const Expanded(child: _DevicesBody()),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DevicesBody extends StatelessWidget {
  const _DevicesBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageDevicesViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _kRed),
          );
        }

        if (vm.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: _kGray),
                  const SizedBox(height: 12),
                  Text(
                    vm.error ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: _kGray, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: vm.load,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: _kRed),
                    label: const Text('Retry',
                        style: TextStyle(color: _kRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kRed),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (vm.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices_outlined, size: 48, color: _kGray),
                  SizedBox(height: 12),
                  Text(
                    'No devices found.',
                    style: TextStyle(fontSize: 14, color: _kGray),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: vm.devices.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, thickness: 0.5, color: _kDivider),
          itemBuilder: (context, i) {
            final device = vm.devices[i];
            return _DeviceRow(
              device: device,
              isCurrent: vm.isCurrentDevice(device),
              isSigningOut: vm.signingOutId == device.id,
              onSignOut: () => _handleSignOut(context, vm, device),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSignOut(
    BuildContext context,
    ManageDevicesViewModel vm,
    DeviceInfoModel device,
  ) async {
    final error = await vm.signOut(device);
    if (!context.mounted) return;
    if (error != null) {
      AppToast.show(context, message: error);
    } else {
      AppToast.show(context, message: 'Device signed out successfully');
    }
  }
}

// ── Device row ────────────────────────────────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.isCurrent,
    required this.isSigningOut,
    required this.onSignOut,
  });

  final DeviceInfoModel device;
  final bool isCurrent;
  final bool isSigningOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Device icon ────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForType(device.deviceType),
              size: 22,
              color: _kGray,
            ),
          ),
          const SizedBox(width: 12),

          // ── Name + timestamp ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'This Device',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Last Logged in ${device.formattedLastLogin}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kGray,
                  ),
                ),
              ],
            ),
          ),

          // ── Sign Out button (other devices only) ───────────────────────
          if (!isCurrent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              height: 32,
              child: isSigningOut
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: _kRed,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onSignOut,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: _kRed, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'android':
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'web':
        return Icons.computer_rounded;
      default:
        return Icons.devices_outlined;
    }
  }
}
