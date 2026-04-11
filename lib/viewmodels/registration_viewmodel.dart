import 'dart:io';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../services/api_service.dart';

class RegistrationViewModel extends ChangeNotifier {
  static const _tag = 'RegistrationViewModel';

  final ApiService _api;
  RegistrationViewModel(this._api);

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

  /// Registers a new user. Returns true on success.
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String gender,
    required String preparingFor,
    required DateTime dob,
    File? image,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        gender: gender,
        preparingFor: preparingFor,
        dob: dob,
        image: image,
      );

      // API may return statusCode 200 or status 'success'
      final ok = res['status'] == 'success' ||
          res['statusCode'] == 200 ||
          res['statusCode'] == '200';
      if (ok) return true;

      _setError(res['message']?.toString() ?? 'Registration failed');
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'register failed', e, st);
      _setError('Something went wrong. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
