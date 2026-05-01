import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';
import '../models/device_info_model.dart';

class ManageDevicesApiService {
  static const _tag = 'ManageDevicesApiService';

  Map<String, String> _authHeaders(String token) => {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  // ── Fetch devices ──────────────────────────────────────────────────────────

  /// GET /mediaview/api/v1/profile → response.device_info[]
  Future<List<DeviceInfoModel>> fetchDevices(String token) async {
    final uri = Uri.parse('${AppConstants.mediaBaseUrl}/profile');
    AppLogger.info(_tag, 'GET $uri');

    final response = await http
        .get(uri, headers: {HttpHeaders.authorizationHeader: 'Bearer $token'})
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(_tag, 'fetchDevices → ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('fetchDevices failed [${response.statusCode}]');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      final resp = decoded['response'];
      if (resp is! Map<String, dynamic>) return [];

      final deviceInfo = resp['device_info'];
      if (deviceInfo is! List) return [];

      return deviceInfo
          .whereType<Map<String, dynamic>>()
          .map(DeviceInfoModel.fromJson)
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.warning(_tag, 'fetchDevices parse error: $e');
      return [];
    }
  }

  // ── Logout device ──────────────────────────────────────────────────────────

  /// POST /users/api/v1/auth/logout-device
  /// Body: { username, access_token, preference: 1 }
  Future<void> logoutDevice({
    required String token,
    required String username,
    required String deviceAccessToken,
  }) async {
    final uri = Uri.parse('${AppConstants.usersBaseUrl}/auth/logout-device');
    AppLogger.info(_tag, 'POST $uri — logout device');

    final response = await http
        .post(
          uri,
          headers: _authHeaders(token),
          body: jsonEncode({
            'username': username,
            'access_token': deviceAccessToken,
            'preference': 1,
          }),
        )
        .timeout(AppConstants.apiTimeout);

    AppLogger.info(
      _tag,
      'logoutDevice → ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'logoutDevice failed [${response.statusCode}]: ${response.body}',
      );
    }
  }
}
