import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/banner_model.dart';

/// Responsible ONLY for the raw HTTP call to the banners endpoint.
/// All errors are converted to typed [AppException] subclasses so upper layers
/// never have to deal with raw [Exception] or [HttpException].
class BannerApiService {
  static const _tag = 'BannerApiService';

  /// Fetches banner list from:
  ///   GET [mediaBaseUrl]/homebanners/banner-images/
  ///
  /// Returns a raw (unsorted) list of [BannerModel].
  /// Throws an [AppException] subclass on any failure.
  Future<List<BannerModel>> fetchBanners() async {
    final url = '${AppConstants.mediaBaseUrl}/homebanners/banner-images/';
    AppLogger.info(_tag, 'GET $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Response ${res.statusCode}: ${res.body}');

      // Server sometimes returns HTML error pages — detect early
      if (res.body.trimLeft().startsWith('<!')) {
        AppLogger.error(_tag, 'Server returned HTML — check URL/headers');
        throw const ParseException();
      }

      final Map<String, dynamic> decoded;
      try {
        final raw = jsonDecode(res.body);
        if (raw is! Map<String, dynamic>) throw const ParseException();
        decoded = raw;
      } on FormatException catch (e) {
        AppLogger.error(_tag, 'JSON parse error: $e');
        throw const ParseException();
      }

      // Success check mirrors the existing ApiService pattern
      final ok =
          decoded['status'] == 'success' || decoded['statusCode'] == 200;
      if (!ok) {
        final msg =
            decoded['message']?.toString() ?? 'Server returned an error';
        throw ServerException(msg);
      }

      // Safely navigate: response → data → List
      final response = decoded['response'];
      if (response is! Map<String, dynamic>) {
        AppLogger.warning(_tag, 'Unexpected response shape: $response');
        return [];
      }

      final data = response['data'];
      if (data is! List) {
        AppLogger.warning(_tag, 'data field is not a List: $data');
        return [];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(BannerModel.fromJson)
          .toList();
    } catch (e, st) {
      if (e is AppException) rethrow; // already typed — pass up as-is
      AppLogger.error(_tag, 'fetchBanners error', e, st);
      if (e is dart_async.TimeoutException) throw const RequestTimeoutException();
      if (e is IOException) throw const NetworkException();
      if (e is http.ClientException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('lookup') || msg.contains('network')) {
          throw const NetworkException();
        }
        throw ServerException('Connection failed: ${e.message}');
      }
      throw ServerException('Unexpected error: ${e.runtimeType}');
    }
  }
}
