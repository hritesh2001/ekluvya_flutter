import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../features/auth/data/models/device_info_model.dart';
import '../services/api_service.dart';

class AuthViewModel extends ChangeNotifier {
  static const _tag = 'AuthViewModel';

  final ApiService _api;
  AuthViewModel(this._api);

  bool _isLoading = false;
  String? _errorMessage;
  bool _mustChangePassword = false;
  // In-memory caches set during studentLogin.
  String? _pendingToken;
  String? _pendingOldPassword;
  // Credentials cached for re-login after device logout.
  String? _loginUsername;
  String? _loginPassword;
  // Subscription flag from the login response — available immediately after
  // studentLogin() so callers can seed SessionViewModel before runPostLoginFlow.
  bool _isUserSubscribed = false;
  // Relative profile picture path from the login response.
  String _loginProfilePictureUrl = '';
  // Active device sessions parsed from the login response.
  List<DeviceInfoModel> _activeDevices = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get mustChangePassword => _mustChangePassword;
  String get loginUsername => _loginUsername ?? '';
  /// Subscription flag from the student-login response. Available immediately
  /// after a successful [studentLogin] — before [runPostLoginFlow] completes.
  bool get isUserSubscribed => _isUserSubscribed;

  /// Relative profile picture path from the login response (e.g. "images/…").
  /// Callers prepend the CDN base URL before rendering.
  String get loginProfilePictureUrl => _loginProfilePictureUrl;
  List<DeviceInfoModel> get activeDevices => List.unmodifiable(_activeDevices);

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

  // ── Safe helpers ──────────────────────────────────────────────────────────

  /// Returns true if either `status == 'success'` or `statusCode == 200`.
  static bool _isSuccess(Map<String, dynamic> res) {
    return res['status'] == 'success' ||
        res['statusCode'] == 200 ||
        res['statusCode'] == '200';
  }

  // ── Auth Methods ──────────────────────────────────────────────────────────

  /// Identifies the user → returns `{ authMethod, type, exists }` or null.
  Future<Map<String, dynamic>?> identify(String input) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.identifyUser(input);
      AppLogger.info(_tag, 'identify response: $res');

      if (_isSuccess(res)) {
        final response = res['response'];
        final responseMap = response is Map ? response : <String, dynamic>{};
        return {
          'authMethod': responseMap['auth_method']?.toString() ?? '',
          'type': responseMap['type']?.toString() ?? '',
          'exists': responseMap['exists'] == true,
        };
      }
      _setError(res['message']?.toString() ?? 'User not found');
      return null;
    } on AppException catch (e) {
      _setError(e.message);
      return null;
    } catch (e, st) {
      AppLogger.error(_tag, 'identify failed: ${e.runtimeType}', e, st);
      _setError('Something went wrong. Please try again. (${e.runtimeType})');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Sends OTP to [phone]. Returns true on success.
  Future<bool> sendOtp(String phone) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.sendOtp(phone);
      AppLogger.info(_tag, 'sendOtp response: $res');

      if (_isSuccess(res)) return true;
      _setError(res['message']?.toString() ?? 'Failed to send OTP');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'sendOtp failed: ${e.runtimeType}', e, st);
      _setError('Failed to send OTP. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verifies the 6-digit OTP. Returns true on success.
  Future<bool> verifyOtp(String phone, String otp) async {
    if (otp.length < 6) {
      _setError('Enter the complete 6-digit OTP');
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.verifyOtp(phone, otp);
      AppLogger.info(_tag, 'verifyOtp response: $res');

      if (_isSuccess(res)) return true;
      _setError(res['message']?.toString() ?? 'Invalid OTP');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'verifyOtp failed: ${e.runtimeType}', e, st);
      _setError('OTP verification failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Resends OTP. Returns true on success.
  Future<bool> resendOtp(String phone) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.sendOtp(phone);
      if (_isSuccess(res)) return true;
      _setError(res['message']?.toString() ?? 'Failed to resend OTP');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'resendOtp failed: ${e.runtimeType}', e, st);
      _setError('Failed to resend OTP. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Completes the OTP flow (phone-login API). Saves token, returns true on success.
  /// Routing (home vs register) is decided by the caller using the `exists`
  /// flag from [identify] — NOT from the login response.
  Future<bool> phoneLogin(String phone) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.phoneLogin(phone);
      AppLogger.info(_tag,
          'phoneLogin status=${res['status']} statusCode=${res['statusCode']}');

      if (_isSuccess(res)) {
        final response = res['response'];
        final token =
            response is Map ? response['access_token']?.toString() : null;

        AppLogger.info(
            _tag, 'token present: ${token != null && token.isNotEmpty}');

        if (token != null && token.isNotEmpty) await _api.saveToken(token);
        return true;
      }

      _setError(res['message']?.toString() ?? 'Login failed');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'phoneLogin failed: ${e.runtimeType}', e, st);
      _setError('Login failed. Please try again. (${e.runtimeType})');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Student (admission number + password) login. Returns true on success.
  /// Sets [mustChangePassword] when the server requires a password reset.
  Future<bool> studentLogin(String username, String password) async {
    _setLoading(true);
    _errorMessage = null;
    _mustChangePassword = false;
    try {
      final res = await _api.studentLogin(
        username: username,
        password: password,
      );
      AppLogger.info(_tag, 'studentLogin status=${res['status']}');

      if (_isSuccess(res)) {
        final response = res['response'];
        if (response is Map) {
          _mustChangePassword = response['must_change_password'] == 1;

          // Subscription status — available immediately from the login response.
          final sub = response['is_user_subscribed'];
          _isUserSubscribed = sub == true || sub == 1 || sub == '1';

          // Profile picture — relative path, CDN base prepended by caller.
          _loginProfilePictureUrl =
              (response['profile_picture'] ?? '').toString().trim();

          // Cache credentials for re-login after device logout.
          _loginUsername = username;
          _loginPassword = password;

          // In-memory token (primary path: must_change_password = 1).
          String? tok = response['access_token']?.toString();
          if (tok == null || tok.isEmpty) {
            final devs = response['get_devices'];
            if (devs is List && devs.isNotEmpty && devs[0] is Map) {
              tok = devs[0]['access_token']?.toString();
            }
          }
          _pendingToken = (tok != null && tok.isNotEmpty) ? tok : null;
          if (_mustChangePassword) _pendingOldPassword = password;

          // Parse active device sessions for the device restriction screen.
          final devList = response['get_devices'];
          _activeDevices = devList is List
              ? devList
                  .whereType<Map<String, dynamic>>()
                  .map(DeviceInfoModel.fromJson)
                  .toList()
              : [];

          AppLogger.info(_tag,
              'studentLogin pendingToken=${_pendingToken != null} devices=${_activeDevices.length}');
        }
        return true;
      }
      _setError(res['message']?.toString() ?? 'Invalid credentials');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'studentLogin failed: ${e.runtimeType}', e, st);
      _setError('Login failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Resets the student's password (called from ResetPasswordScreen).
  ///
  /// Uses the in-memory [_pendingToken] set during [studentLogin] as the
  /// primary source, falling back to the SharedPreferences-persisted token.
  /// This survives any response-shape variation and avoids SharedPreferences
  /// read-after-write races.
  Future<bool> resetPassword(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      // Prefer in-memory token; fall back to persisted token.
      final token = _pendingToken ?? await _api.getToken() ?? '';
      AppLogger.info(_tag, 'resetPassword token present: ${token.isNotEmpty}');
      if (token.isEmpty) {
        _setError('Session expired. Please log in again.');
        return false;
      }
      final oldPassword = _pendingOldPassword ?? '';
      if (oldPassword.isEmpty) {
        _setError('Session expired. Please log in again.');
        return false;
      }
      final res = await _api.resetPassword(
        token: token,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      AppLogger.info(_tag, 'resetPassword status=${res['status']}');
      if (_isSuccess(res)) {
        _pendingToken = null;
        _pendingOldPassword = null;
        return true;
      }
      _setError(res['message']?.toString() ?? 'Failed to update password');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'resetPassword failed: ${e.runtimeType}', e, st);
      _setError('Failed to update password. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Re-login using credentials cached during [studentLogin].
  /// Called automatically after device logout so the user lands on home
  /// without re-entering their admission number and password.
  Future<bool> reloginAfterDeviceLogout() async {
    if (_loginUsername == null || _loginPassword == null) {
      _setError('Session expired. Please log in again.');
      return false;
    }
    return studentLogin(_loginUsername!, _loginPassword!);
  }

  /// Google OAuth login. Returns true on success.
  Future<bool> googleLogin(String idToken) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.googleLogin(idToken);
      AppLogger.info(_tag, 'googleLogin status=${res['status']}');

      if (_isSuccess(res)) {
        final response = res['response'];
        final token = response is Map
            ? response['access_token']?.toString()
            : null;
        if (token != null && token.isNotEmpty) await _api.saveToken(token);
        return true;
      }
      _setError(res['message']?.toString() ?? 'Google login failed');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'googleLogin failed: ${e.runtimeType}', e, st);
      _setError('Google login failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
