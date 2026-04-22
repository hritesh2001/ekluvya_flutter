import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../../../../features/channel/data/models/video_item_model.dart';
import '../../../../services/api_service.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/remote/session_api_service.dart';

enum SessionState { unknown, loggedOut, loggedIn }

/// Central auth + subscription + device state manager.
///
/// Lifecycle:
///   1. Call [initialize] on app start (SplashScreen).
///   2. Call [runPostLoginFlow] immediately after any successful login.
///   3. Check [canPlayVideo] before launching a video.
///   4. Call [logout] to clear session (synchronous — UI updates instantly).
class SessionViewModel extends ChangeNotifier {
  static const _tag = 'SessionViewModel';
  static const _deviceIdKey = 'session_device_id';

  SessionViewModel({
    required ApiService apiService,
    SessionApiService? sessionApiService,
  })  : _api = apiService,
        _sessionApi = sessionApiService ?? SessionApiService();

  final ApiService _api;
  final SessionApiService _sessionApi;

  // ── State ──────────────────────────────────────────────────────────────────
  SessionState _sessionState = SessionState.unknown;
  bool _isSubscribed = false;
  bool _isDeviceRestricted = false;
  bool _isRunningPostLogin = false;
  String? _postLoginError;
  String _userName = '';

  // Pending video — set before navigating to login so we can resume after.
  VideoItemModel? _pendingVideo;
  Map<String, String> _pendingHeaders = {};

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoggedIn => _sessionState == SessionState.loggedIn;
  bool get isSubscribed => _isSubscribed;
  bool get isDeviceRestricted => _isDeviceRestricted;
  bool get isRunningPostLogin => _isRunningPostLogin;
  String? get postLoginError => _postLoginError;
  SessionState get sessionState => _sessionState;

  /// Display name from the profile API. Empty string when not yet loaded.
  String get userName => _userName;

  /// Two-letter initials derived from [userName] (e.g. "Nihan Reddy" → "NR").
  /// Returns a single uppercase letter if only one word is present.
  String get userInitials {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  VideoItemModel? get pendingVideo => _pendingVideo;
  Map<String, String> get pendingVideoHeaders => Map.unmodifiable(_pendingHeaders);
  bool get hasPendingVideo => _pendingVideo != null;

  // ── Video access control ───────────────────────────────────────────────────

  /// First episode (index 0) is always free.
  /// All others require login + active subscription.
  bool canPlayVideo(int episodeIndex) {
    if (episodeIndex == 0) return true;
    if (!isLoggedIn) return false;
    return _isSubscribed;
  }

  bool requiresLogin(int episodeIndex) =>
      episodeIndex > 0 && !isLoggedIn;

  bool requiresSubscription(int episodeIndex) =>
      episodeIndex > 0 && isLoggedIn && !_isSubscribed;

  // ── Pending video ──────────────────────────────────────────────────────────

  void setPendingVideo(VideoItemModel video, Map<String, String> headers) {
    _pendingVideo = video;
    _pendingHeaders = Map.unmodifiable(headers);
  }

  void clearPendingVideo() {
    _pendingVideo = null;
    _pendingHeaders = {};
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Called once on app start. Reads stored token and restores subscription
  /// state if the user is already logged in.
  Future<void> initialize() async {
    final token = await _api.getToken();
    if (token == null || token.isEmpty) {
      _sessionState = SessionState.loggedOut;
      notifyListeners();
      return;
    }

    _sessionState = SessionState.loggedIn;
    // Refresh subscription + user name silently in the background.
    unawaited(_refreshSubscription(token));
    notifyListeners();
  }

  // ── Post-login flow ────────────────────────────────────────────────────────

  /// MANDATORY order after any successful login:
  ///   1. POST impression/user
  ///   2. GET muti-profile/list  (device + profile check)
  ///   3. POST frequent-device-impression/user
  ///   4. GET profile            (subscription + name)
  ///   5. GET home data          (refresh content)
  Future<void> runPostLoginFlow() async {
    _isRunningPostLogin = true;
    _postLoginError = null;
    notifyListeners();

    try {
      final token = await _api.getToken();
      if (token == null || token.isEmpty) {
        _postLoginError = 'No auth token found after login.';
        return;
      }

      _sessionState = SessionState.loggedIn;

      // Step 1: Save user impression (fire-and-forget, non-blocking)
      await _sessionApi.saveUserImpression(token);

      // Step 2: Get profiles (device + profile limit check)
      final profileResult = await _sessionApi.getMultiProfiles(token);
      _isDeviceRestricted =
          profileResult.profileCount > profileResult.profileMaxLimit;

      if (_isDeviceRestricted) {
        AppLogger.warning(
          _tag,
          'Device restricted: ${profileResult.profileCount} profiles > '
          '${profileResult.profileMaxLimit} limit',
        );
        notifyListeners();
        return; // Block further flow
      }

      // Step 3: Save device impression
      final deviceId = await _getOrCreateDeviceId();
      await _sessionApi.saveDeviceImpression(token, deviceId);

      // Step 4: Get profile (subscription check + user name — CRITICAL)
      final profileJson = await _sessionApi.getProfile(token);
      final model = UserProfileModel.fromProfileJson(
        profileJson,
        profileCount: profileResult.profileCount,
        profileMaxLimit: profileResult.profileMaxLimit,
      );
      _isSubscribed = model.isSubscribed;
      if (model.name.isNotEmpty) _userName = model.name;
      AppLogger.info(
        _tag,
        'Post-login: subscribed=$_isSubscribed device_restricted=$_isDeviceRestricted name="$_userName"',
      );

      // Step 5: Refresh home data (non-blocking, callers observe CourseViewModel)
      unawaited(_sessionApi.getHomeData(token));
    } catch (e, st) {
      AppLogger.error(_tag, 'runPostLoginFlow error', e, st);
      _postLoginError = 'Session setup failed. Some content may be restricted.';
    } finally {
      _isRunningPostLogin = false;
      notifyListeners();
    }
  }

  // ── Name update ────────────────────────────────────────────────────────────

  /// Updates the locally cached user name after a successful profile save so
  /// the drawer header reflects the new name without a full session refresh.
  void updateUserName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _userName) return;
    _userName = trimmed;
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Clears all auth state synchronously so the UI updates instantly,
  /// then persists the change (token removal) in the background.
  void logout() {
    _sessionState = SessionState.loggedOut;
    _isSubscribed = false;
    _isDeviceRestricted = false;
    _pendingVideo = null;
    _pendingHeaders = {};
    _postLoginError = null;
    _userName = '';
    notifyListeners();
    // Token removal is async but non-blocking to the UI.
    unawaited(_api.clearToken());
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _refreshSubscription(String token) async {
    try {
      final profileJson = await _sessionApi.getProfile(token);
      final model = UserProfileModel.fromProfileJson(profileJson);
      _isSubscribed = model.isSubscribed;
      if (model.name.isNotEmpty) _userName = model.name;
      AppLogger.info(_tag, 'Refreshed: subscribed=$_isSubscribed name="$_userName"');
      notifyListeners();
    } catch (e) {
      AppLogger.warning(_tag, 'Subscription refresh failed (non-fatal): $e');
    }
  }

  /// Generates a stable device identifier stored in SharedPreferences.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = '${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}
