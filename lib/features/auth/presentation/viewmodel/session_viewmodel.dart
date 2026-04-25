import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
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
  static const _deviceIdKey         = 'session_device_id';
  static const _kIsSubscribed       = 'session_is_subscribed';
  static const _kUserName           = 'session_user_name';
  static const _kProfilePicture     = 'session_profile_picture';
  static const _kDefaultProfileId   = 'session_default_profile_id';

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
  // Relative path from API (e.g. "images/…jpg"). Full URL computed in getter.
  String _profilePictureRelPath = '';
  // default_profile._id from the profile API — used by Watch History.
  String _defaultProfileId = '';
  int _deviceCount = 0;
  int _deviceLimit = 2;

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
  int get deviceCount => _deviceCount;
  int get deviceLimit => _deviceLimit;

  /// Display name from the profile API. Empty string when not yet loaded.
  String get userName => _userName;

  /// The `_id` of the user's default profile. Used by Watch History API.
  String get defaultProfileId => _defaultProfileId;

  /// Full CDN URL for the user's profile picture, or empty string when unknown.
  String get profilePictureUrl {
    if (_profilePictureRelPath.isEmpty) return '';
    if (_profilePictureRelPath.startsWith('http')) return _profilePictureRelPath;
    return '${AppConstants.bannerImageBaseUrl}$_profilePictureRelPath';
  }

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

  // ── Early subscription seeding ────────────────────────────────────────────

  /// Seeds subscription state immediately from the login API response so the
  /// UI reflects the correct access level before [runPostLoginFlow] completes.
  void seedSubscriptionFromLogin(
    bool isSubscribed, {
    String profilePictureUrl = '',
    String userName = '',
  }) {
    _sessionState = SessionState.loggedIn;
    _isSubscribed = isSubscribed;
    if (profilePictureUrl.isNotEmpty) _profilePictureRelPath = profilePictureUrl;
    if (userName.isNotEmpty) _userName = userName;
    // Persist immediately so the state survives an app restart.
    unawaited(_savePersistedUserData());
    notifyListeners();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Called once on app start.
  ///
  /// 1. Read cached token — if absent, mark loggedOut.
  /// 2. If token present but JWT is expired, clear and mark loggedOut.
  /// 3. Restore cached subscription / profile fields instantly.
  /// 4. Silently re-validate in the background.
  Future<void> initialize() async {
    final token = await _api.getToken();
    if (token == null || token.isEmpty) {
      _sessionState = SessionState.loggedOut;
      notifyListeners();
      return;
    }

    if (_isTokenExpired(token)) {
      AppLogger.warning(_tag, 'Stored token is expired — clearing session');
      _sessionState = SessionState.loggedOut;
      unawaited(_api.clearToken());
      unawaited(_clearPersistedUserData());
      notifyListeners();
      return;
    }

    // Restore cached values instantly so the UI shows correct state before
    // the network call completes.
    await _restorePersistedUserData();
    _sessionState = SessionState.loggedIn;
    notifyListeners();

    // Silently re-validate subscription + profile in the background.
    unawaited(_refreshSubscription(token));
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
      _deviceCount = profileResult.profileCount;
      _deviceLimit = profileResult.profileMaxLimit;
      _isDeviceRestricted = _deviceCount > _deviceLimit;

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

      // Step 4: Get profile (user name + device count — CRITICAL).
      final profileJson = await _sessionApi.getProfile(token);
      final model = UserProfileModel.fromProfileJson(
        profileJson,
        profileCount: profileResult.profileCount,
        profileMaxLimit: profileResult.profileMaxLimit,
      );
      final rawProfile = profileJson['response'];
      final profileHasExplicitSubscription =
          rawProfile is Map && rawProfile.containsKey('is_user_subscribed');
      if (profileHasExplicitSubscription) {
        _isSubscribed = model.isSubscribed;
      }
      // else: keep the value seeded from the login response
      if (model.name.isNotEmpty) _userName = model.name;
      if (model.profilePictureUrl.isNotEmpty) {
        _profilePictureRelPath = model.profilePictureUrl;
      }
      if (rawProfile is Map) {
        final dp = rawProfile['default_profile'];
        if (dp is Map) {
          final id = dp['_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) _defaultProfileId = id;
        }
      }

      // Persist the authoritative values so they survive app restarts.
      unawaited(_savePersistedUserData());

      AppLogger.info(
        _tag,
        'Post-login: subscribed=$_isSubscribed '
        '(from_profile=$profileHasExplicitSubscription) '
        'device_restricted=$_isDeviceRestricted name="$_userName" '
        'profileId="$_defaultProfileId"',
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
    unawaited(_savePersistedUserData());
    notifyListeners();
  }

  /// Updates the cached profile picture URL after a successful profile save
  /// so the menu/drawer header reflects the new image without a session restart.
  void updateProfilePicture(String urlOrRelPath) {
    final trimmed = urlOrRelPath.trim();
    if (trimmed.isEmpty || trimmed == _profilePictureRelPath) return;
    _profilePictureRelPath = trimmed;
    unawaited(_savePersistedUserData());
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
    _profilePictureRelPath = '';
    _defaultProfileId = '';
    notifyListeners();
    unawaited(_api.clearToken());
    unawaited(_clearPersistedUserData());
  }

  // ── Device management ──────────────────────────────────────────────────────

  /// Signs out a specific device session then re-validates the current state.
  Future<void> logoutDeviceSession(String deviceId) async {
    final token = await _api.getToken() ?? '';
    await _sessionApi.logoutDevice(token, deviceId);
  }

  /// Signs out ALL device sessions for the current account.
  Future<void> logoutAllDeviceSessions() async {
    final token = await _api.getToken() ?? '';
    await _sessionApi.logoutAllDevices(token);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _refreshSubscription(String token) async {
    try {
      final profileJson = await _sessionApi.getProfile(token);
      final model = UserProfileModel.fromProfileJson(profileJson);
      final rawProfile = profileJson['response'];
      final hasExplicit =
          rawProfile is Map && rawProfile.containsKey('is_user_subscribed');
      if (hasExplicit) {
        _isSubscribed = model.isSubscribed;
      }
      if (model.name.isNotEmpty) _userName = model.name;
      if (model.profilePictureUrl.isNotEmpty) {
        _profilePictureRelPath = model.profilePictureUrl;
      }
      if (rawProfile is Map) {
        final dp = rawProfile['default_profile'];
        if (dp is Map) {
          final id = dp['_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) _defaultProfileId = id;
        }
      }
      unawaited(_savePersistedUserData());
      AppLogger.info(
          _tag, 'Refreshed: subscribed=$_isSubscribed name="$_userName"');
      notifyListeners();
    } catch (e) {
      AppLogger.warning(_tag, 'Subscription refresh failed (non-fatal): $e');
    }
  }

  /// Returns true if the JWT [token] is expired (or cannot be decoded).
  /// Does NOT make a network request — pure local check.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false; // not a JWT — assume valid
      // JWT parts use base64url without padding; add padding to decode.
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = claims['exp'];
      if (exp == null) return false; // no expiry claim — assume valid
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (exp as num).toInt() * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().isAfter(expiry);
    } catch (e) {
      AppLogger.warning(_tag, 'JWT decode failed (non-fatal): $e');
      return false; // on parse error, let the API decide
    }
  }

  /// Persists the current subscription + profile fields to SharedPreferences
  /// so they can be restored instantly on the next cold start.
  Future<void> _savePersistedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_kIsSubscribed, _isSubscribed),
        prefs.setString(_kUserName, _userName),
        prefs.setString(_kProfilePicture, _profilePictureRelPath),
        prefs.setString(_kDefaultProfileId, _defaultProfileId),
      ]);
    } catch (e) {
      AppLogger.warning(_tag, '_savePersistedUserData failed: $e');
    }
  }

  /// Reads back the persisted fields into memory — called during [initialize]
  /// so the UI can render correct state before the network refresh completes.
  Future<void> _restorePersistedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSubscribed         = prefs.getBool(_kIsSubscribed)         ?? false;
      _userName             = prefs.getString(_kUserName)            ?? '';
      _profilePictureRelPath = prefs.getString(_kProfilePicture)    ?? '';
      _defaultProfileId     = prefs.getString(_kDefaultProfileId)   ?? '';
      AppLogger.info(
        _tag,
        'Restored: subscribed=$_isSubscribed name="$_userName" '
        'profileId="$_defaultProfileId"',
      );
    } catch (e) {
      AppLogger.warning(_tag, '_restorePersistedUserData failed: $e');
    }
  }

  /// Removes all persisted user fields from SharedPreferences on logout.
  Future<void> _clearPersistedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kIsSubscribed),
        prefs.remove(_kUserName),
        prefs.remove(_kProfilePicture),
        prefs.remove(_kDefaultProfileId),
      ]);
    } catch (e) {
      AppLogger.warning(_tag, '_clearPersistedUserData failed: $e');
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
