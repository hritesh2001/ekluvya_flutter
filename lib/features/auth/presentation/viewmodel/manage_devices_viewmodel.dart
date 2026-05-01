import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../data/models/device_info_model.dart';
import '../../data/remote/manage_devices_api_service.dart';
import 'session_viewmodel.dart';

enum ManageDevicesLoadState { initial, loading, loaded, error }

class ManageDevicesViewModel extends ChangeNotifier {
  static const _tag = 'ManageDevicesViewModel';

  ManageDevicesViewModel({
    required ApiService authApi,
    required SessionViewModel sessionVM,
    ManageDevicesApiService? api,
  })  : _authApi = authApi,
        _sessionVM = sessionVM,
        _api = api ?? ManageDevicesApiService();

  final ApiService _authApi;
  final SessionViewModel _sessionVM;
  final ManageDevicesApiService _api;

  // ── State ──────────────────────────────────────────────────────────────────

  ManageDevicesLoadState _state = ManageDevicesLoadState.initial;
  String? _error;
  final List<DeviceInfoModel> _devices = [];
  String _currentToken = '';
  String? _signingOutId; // device.id being signed out right now

  // ── Getters ────────────────────────────────────────────────────────────────

  ManageDevicesLoadState get state => _state;
  bool get isLoading => _state == ManageDevicesLoadState.loading;
  bool get hasError => _state == ManageDevicesLoadState.error;
  bool get hasData => _state == ManageDevicesLoadState.loaded;
  String? get error => _error;
  List<DeviceInfoModel> get devices => List.unmodifiable(_devices);
  bool get isEmpty => hasData && _devices.isEmpty;
  String? get signingOutId => _signingOutId;

  /// Returns true when [device.accessToken] matches the locally stored token.
  bool isCurrentDevice(DeviceInfoModel device) =>
      _currentToken.isNotEmpty && device.accessToken == _currentToken;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _state = ManageDevicesLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _fail('Please log in to manage devices.');
        return;
      }

      _currentToken = token;

      final devices = await _api.fetchDevices(token);
      _devices
        ..clear()
        ..addAll(devices);
      _state = ManageDevicesLoadState.loaded;

      AppLogger.info(_tag, 'loaded ${devices.length} device(s)');
    } catch (e, st) {
      AppLogger.error(_tag, 'load error', e, st);
      _fail('Could not load devices. Please try again.');
    } finally {
      notifyListeners();
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  /// Signs out [device] from the backend and removes it from the list.
  /// Returns `null` on success, or an error string on failure.
  Future<String?> signOut(DeviceInfoModel device) async {
    if (_signingOutId != null) return null; // debounce concurrent taps

    _signingOutId = device.id;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) return 'Not logged in.';

      await _api.logoutDevice(
        token: token,
        username: _sessionVM.userName,
        deviceAccessToken: device.accessToken,
      );

      // Optimistic UI — remove immediately after backend confirms success.
      _devices.removeWhere((d) => d.id == device.id);
      notifyListeners();

      AppLogger.info(_tag, 'signOut ✓ device=${device.id}');
      return null;
    } catch (e, st) {
      AppLogger.error(_tag, 'signOut error', e, st);
      return 'Failed to sign out device. Please try again.';
    } finally {
      _signingOutId = null;
      notifyListeners();
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _fail(String msg) {
    _state = ManageDevicesLoadState.error;
    _error = msg;
    notifyListeners();
  }
}
