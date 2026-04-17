import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/signed_cookie_model.dart';

/// GET [mediaApiBaseUrl]/get-signed-cookies
class SignedCookieApiService {
  static const _tag = 'SignedCookieApiService';

  Future<SignedCookieModel> fetchSignedCookies() async {
    const url = '${AppConstants.mediaApiBaseUrl}/get-signed-cookies';
    AppLogger.info(_tag, 'GET signed-cookies → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Signed-cookies response ${res.statusCode}');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  SignedCookieModel _parse(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) throw const ParseException();

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException {
      throw const ParseException();
    }

    // Accept any 2xx or message containing "success"
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok) {
      throw ServerException(decoded['message']?.toString() ?? 'Server error');
    }

    return SignedCookieModel.fromJson(decoded);
  }

  Never _handleError(Object e, StackTrace st) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, 'fetchSignedCookies error', e, st);
    if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) throw const NetworkException();
    throw ServerException('Unexpected error: ${e.runtimeType}');
  }
}
