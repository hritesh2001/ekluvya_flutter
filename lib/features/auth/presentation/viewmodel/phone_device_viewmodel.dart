import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../../../viewmodels/auth_viewmodel.dart';

class PhoneDeviceViewModel extends ChangeNotifier {
  static const _tag = 'PhoneDeviceViewModel';

  final ApiService _api;
  final AuthViewModel _authVM;

  PhoneDeviceViewModel({required ApiService api, required AuthViewModel authVM})
      : _api = api,
        _authVM = authVM;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Signs out a single device then retries phone-login. Returns true when the
  /// retry succeeds so the caller can dismiss the dialog and continue the flow.
  Future<bool> logoutDeviceAndContinue({
    required String deviceToken,
  }) async {
    final phone = _authVM.loginUsername;        // phone number for retry
    final apiUsername = _authVM.loginApiUsername; // server username for API
    if (phone.isEmpty) {
      _setError('Session expired. Please try again.');
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await _api.logoutPhoneDevice(
        username: apiUsername,
        deviceToken: deviceToken,
        preference: 1, // single device
      );
    } on AppException catch (e) {
      AppLogger.error(_tag, 'logoutDevice failed: ${e.message}');
      // Continue to retry login even if the logout call failed.
    } catch (e, st) {
      AppLogger.error(_tag, 'logoutDevice unexpected: $e', e, st);
    }
    return _retryLogin(phone);
  }

  /// Signs out ALL devices with a single API call (preference: "all") then
  /// retries phone-login.  Matches the web flow exactly.
  Future<bool> logoutAllAndContinue() async {
    final phone = _authVM.loginUsername;        // phone number for retry
    final apiUsername = _authVM.loginApiUsername; // server username for API
    if (phone.isEmpty) {
      _setError('Session expired. Please try again.');
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    final devices = _authVM.phoneLoginDevices;
    if (devices.isNotEmpty) {
      try {
        // One call with preference "all" removes every session at once.
        await _api.logoutPhoneDevice(
          username: apiUsername,
          deviceToken: devices.first.accessToken,
          preference: 'all',
        );
      } on AppException catch (e) {
        AppLogger.error(_tag, 'logoutAllDevices failed: ${e.message}');
      } catch (e, st) {
        AppLogger.error(_tag, 'logoutAllDevices unexpected: $e', e, st);
      }
    }
    return _retryLogin(phone);
  }

  Future<bool> _retryLogin(String phone) async {
    try {
      final success = await _authVM.phoneLogin(phone);
      if (!success && _authVM.isPhoneDeviceLimited) {
        _setError('Still too many devices. Please try again.');
        _setLoading(false);
        return false;
      }
      if (!success) {
        _setError(_authVM.errorMessage ?? 'Login failed. Please try again.');
        _setLoading(false);
        return false;
      }
      _setLoading(false);
      return true;
    } catch (e, st) {
      AppLogger.error(_tag, 'retryLogin failed: $e', e, st);
      _setError('Login failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }
}
