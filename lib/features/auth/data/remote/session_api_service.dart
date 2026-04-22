import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// Handles the 4-step mandatory post-login API flow:
/// 1. POST impression/user
/// 2. GET muti-profile/list
/// 3. POST frequent-device-impression/user
/// 4. GET /mediaview/api/v1/profile  (subscription check)
/// 5. GET home data (refresh)
class SessionApiService {
  static const _tag = 'SessionApiService';

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _safeDecode(
    http.Response res,
    String label,
  ) {
    AppLogger.info(_tag, '$label → ${res.statusCode}');
    if (res.body.trimLeft().startsWith('<!')) return Future.value({});
    try {
      final decoded = jsonDecode(res.body);
      return Future.value(decoded is Map<String, dynamic> ? decoded : {});
    } catch (e) {
      AppLogger.warning(_tag, '$label parse error: $e');
      return Future.value({});
    }
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────

  Future<void> saveUserImpression(String token) async {
    try {
      final url =
          Uri.parse('${AppConstants.userActionsBaseUrl}/impression/user');
      final res = await http
          .post(url, headers: _authHeaders(token), body: jsonEncode({}))
          .timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'impression/user → ${res.statusCode}');
    } catch (e) {
      AppLogger.warning(_tag, 'saveUserImpression failed (non-fatal): $e');
    }
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  /// Returns `{profileCount, profileMaxLimit}` or defaults on failure.
  Future<({int profileCount, int profileMaxLimit})> getMultiProfiles(
    String token,
  ) async {
    try {
      final url =
          Uri.parse('${AppConstants.usersBaseUrl}/muti-profile/list');
      final res = await http
          .get(url, headers: _authHeaders(token))
          .timeout(AppConstants.apiTimeout);
      final body = await _safeDecode(res, 'muti-profile/list');

      final response = body['response'];
      final Map<String, dynamic> data =
          response is Map<String, dynamic> ? response : {};

      final profiles = data['data'];
      final count = profiles is List ? profiles.length : 0;
      final maxLimit = (data['profileMaxLimit'] as num?)?.toInt() ?? 2;

      AppLogger.info(_tag, 'profiles: $count / $maxLimit');
      return (profileCount: count, profileMaxLimit: maxLimit);
    } catch (e) {
      AppLogger.warning(_tag, 'getMultiProfiles failed (non-fatal): $e');
      return (profileCount: 0, profileMaxLimit: 2);
    }
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────

  Future<void> saveDeviceImpression(
    String token,
    String deviceId,
  ) async {
    try {
      final url = Uri.parse(
        '${AppConstants.userActionsBaseUrl}/frequent-device-impression/user',
      );
      final body = jsonEncode({
        'device_id': deviceId,
        'device_type': Platform.isIOS ? 'ios' : 'android',
        'device_name': Platform.isIOS ? 'iPhone' : 'Android',
      });
      final res = await http
          .post(url, headers: _authHeaders(token), body: body)
          .timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'device-impression → ${res.statusCode}');
    } catch (e) {
      AppLogger.warning(_tag, 'saveDeviceImpression failed (non-fatal): $e');
    }
  }

  // ── Step 4 ────────────────────────────────────────────────────────────────

  /// Returns raw profile JSON map for subscription extraction.
  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final url = Uri.parse('${AppConstants.mediaBaseUrl}/profile');
      final res = await http
          .get(url, headers: _authHeaders(token))
          .timeout(AppConstants.apiTimeout);
      return _safeDecode(res, 'profile');
    } catch (e) {
      AppLogger.warning(_tag, 'getProfile failed (non-fatal): $e');
      return {};
    }
  }

  // ── Step 5 ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHomeData(String token) async {
    try {
      final url = Uri.parse(
        '${AppConstants.mediaBaseUrl}/home/gethome-data?limit=5&inside_limit=12',
      );
      final res = await http
          .get(url, headers: _authHeaders(token))
          .timeout(AppConstants.apiTimeout);
      return _safeDecode(res, 'home/gethome-data');
    } catch (e) {
      AppLogger.warning(_tag, 'getHomeData failed (non-fatal): $e');
      return {};
    }
  }
}
