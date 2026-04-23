import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../presentation/viewmodel/session_viewmodel.dart';
import '../../../../viewmodels/auth_viewmodel.dart';

enum DeviceActionState { idle, loading, success, error }

/// Drives the device restriction / management screen.
///
/// Scoped to [DeviceRestrictionScreen] — created in the route factory so
/// both [SessionViewModel] and [AuthViewModel] can be injected without
/// depending on BuildContext inside async gaps.
class DeviceViewModel extends ChangeNotifier {
  static const _tag = 'DeviceViewModel';

  DeviceViewModel({
    required SessionViewModel sessionVM,
    required AuthViewModel authVM,
  })  : _sessionVM = sessionVM,
        _authVM = authVM;

  final SessionViewModel _sessionVM;
  final AuthViewModel _authVM;

  DeviceActionState _state = DeviceActionState.idle;
  String? _error;
  String? _loadingDeviceId; // which device card is showing a spinner

  DeviceActionState get state => _state;
  bool get isLoading => _state == DeviceActionState.loading;
  String? get error => _error;
  String? get loadingDeviceId => _loadingDeviceId;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Signs out [deviceId] then re-logs in with cached credentials.
  /// Returns `true` when the device limit is no longer exceeded (go to home).
  Future<bool> logoutDevice(String deviceId) async {
    _state = DeviceActionState.loading;
    _loadingDeviceId = deviceId;
    _error = null;
    notifyListeners();
    try {
      await _sessionVM.logoutDeviceSession(deviceId);
      return await _reloginAndCheck();
    } catch (e, st) {
      AppLogger.error(_tag, 'logoutDevice error', e, st);
      _error = 'Failed to sign out device. Please try again.';
      _state = DeviceActionState.error;
      return false;
    } finally {
      _loadingDeviceId = null;
      notifyListeners();
    }
  }

  /// Signs out ALL device sessions then re-logs in with cached credentials.
  /// Returns `true` when ready to navigate to home.
  Future<bool> logoutAllAndRelogin() async {
    _state = DeviceActionState.loading;
    _error = null;
    notifyListeners();
    try {
      await _sessionVM.logoutAllDeviceSessions();
      return await _reloginAndCheck();
    } catch (e, st) {
      AppLogger.error(_tag, 'logoutAll error', e, st);
      _error = 'Failed to sign out all devices. Please try again.';
      _state = DeviceActionState.error;
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _reloginAndCheck() async {
    final ok = await _authVM.reloginAfterDeviceLogout();
    if (!ok) {
      _error = _authVM.errorMessage ?? 'Re-login failed. Please log in again.';
      _state = DeviceActionState.error;
      return false;
    }
    await _sessionVM.runPostLoginFlow();
    _state = _sessionVM.isDeviceRestricted
        ? DeviceActionState.error
        : DeviceActionState.success;
    if (_sessionVM.isDeviceRestricted) {
      _error = 'Device limit still exceeded. Please remove another device.';
    }
    return !_sessionVM.isDeviceRestricted;
  }
}
