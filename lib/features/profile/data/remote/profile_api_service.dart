import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// Handles all profile-specific API calls:
///   • GET  /mediaview/api/v1/profile
///   • GET  /mediaview/api/v1/subscription
///   • POST /users/api/v1/auth/update-profile  (multipart)
class ProfileApiService {
  static const _tag = 'ProfileApiService';

  Map<String, String> _authHeader(String token) =>
      {'Authorization': 'Bearer $token'};

  // ── Get full profile ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile(String token) async {
    final url = Uri.parse('${AppConstants.mediaBaseUrl}/profile');
    try {
      final res = await http
          .get(url, headers: _authHeader(token))
          .timeout(AppConstants.apiTimeout);
      return _decode(res, 'getProfile');
    } catch (e, st) {
      AppLogger.error(_tag, 'getProfile error', e, st);
      return {};
    }
  }

  // ── Get subscription plan ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSubscription(String token) async {
    final url = Uri.parse('${AppConstants.mediaBaseUrl}/subscription');
    try {
      final res = await http
          .get(url, headers: _authHeader(token))
          .timeout(AppConstants.apiTimeout);
      return _decode(res, 'getSubscription');
    } catch (e, st) {
      AppLogger.error(_tag, 'getSubscription error', e, st);
      return {};
    }
  }

  // ── Update profile ─────────────────────────────────────────────────────────

  /// Sends a multipart POST to update the user's profile.
  ///
  /// [dob] must be in DD/MM/YYYY format (as expected by the API).
  /// [gender] is "1" (Male) or "2" (Female).
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String dob,
    required String gender,
    File? profilePicture,
  }) async {
    final url =
        Uri.parse('${AppConstants.usersBaseUrl}/auth/update-profile');
    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['first_name'] = firstName
        ..fields['last_name'] = lastName
        ..fields['dob'] = dob
        ..fields['gender'] = gender;

      if (profilePicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
              'profile_picture', profilePicture.path),
        );
      }

      AppLogger.info(_tag, 'updateProfile → fields: ${request.fields}');
      final streamed =
          await request.send().timeout(AppConstants.apiTimeout);
      final body = await streamed.stream.bytesToString();
      AppLogger.info(_tag, 'updateProfile ← ${streamed.statusCode} | $body');

      if (body.trimLeft().startsWith('<!')) return {};
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e, st) {
      AppLogger.error(_tag, 'updateProfile error', e, st);
      return {};
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _decode(http.Response res, String label) {
    AppLogger.info(_tag, '$label → ${res.statusCode}');
    if (res.body.trimLeft().startsWith('<!')) return {};
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      AppLogger.warning(_tag, '$label parse error: $e');
      return {};
    }
  }
}
