import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../services/api_service.dart';

class AuthViewModel extends ChangeNotifier {
  static const _tag = 'AuthViewModel';

  final ApiService _api;
  AuthViewModel(this._api);

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
  Future<bool> studentLogin(String username, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.studentLogin(
        username: username,
        password: password,
      );
      AppLogger.info(_tag, 'studentLogin status=${res['status']}');

      if (_isSuccess(res)) return true;
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
