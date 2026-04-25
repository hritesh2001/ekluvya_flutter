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

  /// Updates the user's profile.
  ///
  /// When [profilePicture] is null the request is sent as JSON (matching
  /// the Android client). When an image is attached multipart is used.
  ///
  /// [dob] is normalised internally — accepts both DD/MM/YYYY and YYYY-MM-DD.
  /// [gender] is "1" (Male) or "2" (Female).
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String dob,
    required String gender,
    String phone = '',
    String email = '',
    int isPhoneVerified = 0,
    int isEmailVerified = 0,
    File? profilePicture,
  }) async {
    final url =
        Uri.parse('${AppConstants.usersBaseUrl}/auth/update-profile');
    final apiDob    = _normaliseDob(dob);
    final genderInt = int.tryParse(gender) ?? 1;

    try {
      if (profilePicture != null) {
        // Multipart — only when a new profile picture is attached.
        final request = http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['first_name'] = firstName
          ..fields['last_name']  = lastName
          ..fields['dob']        = apiDob
          ..fields['gender']     = genderInt.toString()
          ..fields['phone']      = phone
          ..fields['email']      = email
          ..fields['is_phone_verified'] = isPhoneVerified.toString()
          ..fields['is_email_verified'] = isEmailVerified.toString();

        request.files.add(
          await http.MultipartFile.fromPath(
              'profile_picture', profilePicture.path),
        );

        AppLogger.info(_tag, 'updateProfile (multipart) → ${request.fields}');
        final streamed =
            await request.send().timeout(AppConstants.apiTimeout);
        final body = await streamed.stream.bytesToString();
        AppLogger.info(
            _tag, 'updateProfile ← ${streamed.statusCode} | $body');

        if (body.trimLeft().startsWith('<!')) return {};
        final decoded = jsonDecode(body);
        return decoded is Map<String, dynamic> ? decoded : {};
      } else {
        // JSON — matches Android client for text-only updates.
        final payload = jsonEncode({
          'first_name':        firstName,
          'dob':               apiDob,
          'gender':            genderInt,
          'phone':             phone,
          'email':             email,
          'is_phone_verified': isPhoneVerified,
          'is_email_verified': isEmailVerified,
        });
        AppLogger.info(_tag, 'updateProfile (json) → $payload');
        final res = await http
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type':  'application/json',
              },
              body: payload,
            )
            .timeout(AppConstants.apiTimeout);
        AppLogger.info(_tag, 'updateProfile ← ${res.statusCode} | ${res.body}');
        return _decode(res, 'updateProfile');
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'updateProfile error', e, st);
      return {};
    }
  }

  /// Normalises DOB to YYYY-MM-DD accepted by the API.
  /// Input may be DD/MM/YYYY (display), YYYY-MM-DD, or ISO datetime.
  static String _normaliseDob(String dob) {
    if (dob.isEmpty) return dob;
    // Strip time component from ISO datetime first
    final dateOnly = dob.contains('T') ? dob.split('T').first : dob;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateOnly)) return dateOnly;
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateOnly)) {
      final p = dateOnly.split('/');
      return '${p[2]}-${p[1]}-${p[0]}';
    }
    return dateOnly;
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
