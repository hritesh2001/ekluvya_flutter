import 'dart:async';
import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';

class ApiService {
  static const _tag = 'ApiService';

  // Fires whenever any API response returns HTTP 401.
  // SessionViewModel subscribes to this to force-logout the user in real time,
  // handling the case where another device's logout-all has revoked this token.
  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  // ── Error handler ─────────────────────────────────────────────────────────

  Never _handleNetworkError(Object e, StackTrace st, String label) {
    AppLogger.error(_tag, '$label → ${e.runtimeType}: $e', e, st);

    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException)                 throw const NetworkException();
    if (e is http.ClientException) {
      AppLogger.error(_tag, 'ClientException detail: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('lookup') || msg.contains('network')) {
        throw const NetworkException();
      }
      throw ServerException('Connection failed: ${e.message}');
    }
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }

  // ── Response decoder ──────────────────────────────────────────────────────

  Map<String, dynamic> _decode(http.Response res, String label) {
    AppLogger.info(_tag, '$label → ${res.statusCode}');
    AppLogger.info(_tag, 'BODY: ${res.body}');           // ← full body logged

    // 401 means the token has been revoked server-side (e.g. logout-all from
    // another device).  Broadcast before throwing so SessionViewModel can
    // react even if the immediate caller catches AppException.
    if (res.statusCode == 401) {
      AppLogger.warning(_tag, '$label → 401 Unauthorized — broadcasting forced logout');
      _unauthorizedController.add(null);
      throw const UnauthorizedException();
    }

    if (res.body.trimLeft().startsWith('<!')) {
      AppLogger.error(_tag, '$label returned HTML — check URL / headers');
      throw const ParseException();
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ParseException();
    } on FormatException catch (e) {
      AppLogger.error(_tag, 'JSON parse failed: $e | body: ${res.body}');
      throw const ParseException();
    }
  }

  // ── Generic helpers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? overrideUrl,
    Map<String, String>? headers,
  }) async {
    final url = overrideUrl ?? '${AppConstants.usersBaseUrl}$path';
    AppLogger.info(_tag, 'POST $url | ${jsonEncode(body)}');
    try {
      final res = await http
          .post(Uri.parse(url),
              headers: headers ?? _jsonHeaders, body: jsonEncode(body))
          .timeout(AppConstants.apiTimeout);
      return _decode(res, url);
    } catch (e, st) {
      if (e is AppException) rethrow;
      _handleNetworkError(e, st, 'POST $url');
    }
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body, {
    String? overrideUrl,
    Map<String, String>? headers,
  }) async {
    final url = overrideUrl ?? '${AppConstants.usersBaseUrl}$path';
    AppLogger.info(_tag, 'PUT $url | ${jsonEncode(body)}');
    try {
      final res = await http
          .put(Uri.parse(url),
              headers: headers ?? _jsonHeaders, body: jsonEncode(body))
          .timeout(AppConstants.apiTimeout);
      return _decode(res, url);
    } catch (e, st) {
      if (e is AppException) rethrow;
      _handleNetworkError(e, st, 'PUT $url');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? overrideUrl,
    Map<String, String>? headers,
  }) async {
    final url = overrideUrl ?? '${AppConstants.usersBaseUrl}$path';
    AppLogger.info(_tag, 'GET $url');
    try {
      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(AppConstants.apiTimeout);
      return _decode(res, url);
    } catch (e, st) {
      if (e is AppException) rethrow;
      _handleNetworkError(e, st, 'GET $url');
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  static const _refreshTokenKey = 'refresh_token';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clearRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Step 1 — identify user (tells us if they're new or existing)
  Future<Map<String, dynamic>> identifyUser(String input) =>
      _post('/auth/identify-user', {'identifier': input});

  /// Step 2a — send OTP
  /// Params as per developer docs: code, to, is_phone_verified
  Future<Map<String, dynamic>> sendOtp(String phone) => _post(
        '/auth/send-newOtp',
        {
          'code': AppConstants.countryCode,   // "+91"
          'to': phone,
          'is_phone_verified': 0,
        },
      );

  /// Step 3a — verify OTP
  /// Params as per developer docs: phone, otp, browsername, deviceDetail,
  /// is_phone_verified
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) =>
      _post('/auth/validate-otp', {
        'phone': phone,
        'otp': otp,
        // Send platform name so the server records login_type as "iOS"/"Android"
        // rather than "Web" (which it assigns when browsername is empty).
        'browsername': Platform.isIOS ? 'iOS' : 'Android',
        'deviceDetail': Platform.isIOS ? 'iPhone' : 'Android',
        'is_phone_verified': 1,
      });

  /// Step 4a — phone login (called after OTP is verified)
  /// Uses 'phone' param — confirmed from browser network trace.
  /// Developer docs had copy-paste error (showed sendOtp params instead).
  Future<Map<String, dynamic>> phoneLogin(String phone) =>
      _post('/auth/phone-login', {
        'phone': phone,                       // ← correct field name
        'is_phone_verified': 1,
        // Sending the platform name (not an empty string) causes the server to
        // store login_type as "iOS" or "Android" instead of "Web", which is
        // required for correct device-limit detection and for the device popup
        // to show the right icon and label.
        'browsername': Platform.isIOS ? 'iOS' : 'Android',
        'deviceDetail': Platform.isIOS ? 'iPhone' : 'Android',
      });

  Future<Map<String, dynamic>> googleLogin(String idToken) =>
      _post('/auth/login', {'google_auth_id': idToken});

  /// Password login for student accounts.
  ///
  /// Token location varies by server response:
  ///   • must_change_password = 1 → token is at response.access_token
  ///   • must_change_password = 0 → token is at response.get_devices[0].access_token
  /// Both paths are checked so the token is always persisted.
  Future<Map<String, dynamic>> studentLogin({
    required String username,
    required String password,
  }) async {
    final decoded = await _post(
      '/auth/student-login',
      {
        'username':     username,
        'password':     password,
        'browsername':  Platform.isIOS ? 'iOS' : 'Android',
        'deviceDetail': Platform.isIOS ? 'iPhone' : 'Android',
        'login_type':   'password',
      },
    );
    final ok = decoded['status'] == 'success' || decoded['statusCode'] == 200;
    if (ok) {
      final response = decoded['response'];
      if (response is Map) {
        // Primary path (must_change_password = 1): token at response.access_token
        String? token = response['access_token']?.toString();

        // Fallback path (fully logged in): token at response.get_devices[0].access_token
        if (token == null || token.isEmpty) {
          final devices = response['get_devices'];
          if (devices is List && devices.isNotEmpty && devices[0] is Map) {
            token = devices[0]['access_token']?.toString();
          }
        }

        AppLogger.info(_tag, 'studentLogin token present: ${token != null && token.isNotEmpty}');
        if (token != null && token.isNotEmpty) await saveToken(token);
      }
    }
    return decoded;
  }

  // ── Registration ──────────────────────────────────────────────────────────

  /// Params as per developer docs:
  /// first_name, email, phone, login_type, country_code, iso,
  /// is_phone_verified, browsername, deviceDetail
  /// (last_name, gender, dob, preparing_for, profile_picture are optional extras)
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String gender,
    required String preparingFor,
    required DateTime dob,
    File? image,
  }) async {
    final uri = Uri.parse('${AppConstants.usersBaseUrl}/auth/register');
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll({
        // ── Required fields (from developer docs) ──
        'first_name': firstName,
        'email': email,
        'phone': phone,
        'login_type': 'normal',               // required per developer docs
        'country_code': AppConstants.countryCode,
        'iso': 'in',                           // ISO country code per developer docs
        'is_phone_verified': '1',
        'browsername': '',
        'deviceDetail': Platform.isIOS ? 'iPhone' : 'Android',
        // ── Optional extras (original fields) ──
        'last_name': lastName,
        'gender': gender,
        'preparing_for': preparingFor,
        'dob': '${dob.day.toString().padLeft(2, '0')}/'
            '${dob.month.toString().padLeft(2, '0')}/'
            '${dob.year}',
      });

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', image.path),
      );
    }

    AppLogger.info(_tag, 'POST register | fields: ${request.fields}');

    try {
      final streamed = await request.send().timeout(AppConstants.apiTimeout);
      final body = await streamed.stream.bytesToString();
      AppLogger.info(_tag, 'register BODY: $body');

      if (body.trimLeft().startsWith('<!')) throw const ParseException();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ParseException();
    } catch (e, st) {
      if (e is AppException) rethrow;
      _handleNetworkError(e, st, 'POST register');
    }
  }

  // ── Profile / Media ───────────────────────────────────────────────────────

  /// Change password — PUT /auth/change-password
  /// Required body: old_password, password, password_confirmation
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) =>
      _put(
        '/auth/change-password',
        {
          'old_password': oldPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        },
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    return _get(
      '/profile',
      overrideUrl: '${AppConstants.mediaBaseUrl}/profile',
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
    );
  }

  Future<Map<String, dynamic>> fetchCommonFeatures() => _get(
        '/common',
        overrideUrl: '${AppConstants.mediaBaseUrl}/common',
      );

  /// Logs out device(s) during the phone-login flow.
  /// POST /auth/logout-device
  /// [username]   — server-side username field (e.g. "usr-5QovTsaghO"), NOT phone.
  /// [deviceToken]— access_token of the device to remove.
  /// [preference] — 1 for single device; "all" to remove every device at once.
  Future<Map<String, dynamic>> logoutPhoneDevice({
    required String username,
    required String deviceToken,
    Object preference = 1,
  }) =>
      _post('/auth/logout-device', {
        'username': username,
        'access_token': deviceToken,
        'preference': preference,
      });
}
