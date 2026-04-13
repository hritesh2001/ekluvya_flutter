import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/category_model.dart';

/// Fetches home-screen category + course data from:
///   GET [mediaBaseUrl]/home/gethome-data?limit=X&inside_limit=Y
class CourseApiService {
  static const _tag = 'CourseApiService';

  /// [categoryLimit]  — max categories to return (default 10)
  /// [courseLimit]    — max courses per category (default 12)
  Future<List<CategoryModel>> fetchHomeData({
    int categoryLimit = 10,
    int courseLimit = 12,
  }) async {
    final url =
        '${AppConstants.mediaBaseUrl}/home/gethome-data'
        '?limit=$categoryLimit&inside_limit=$courseLimit';

    AppLogger.info(_tag, 'GET $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Response ${res.statusCode}');

      if (res.body.trimLeft().startsWith('<!')) {
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

      final ok =
          decoded['status'] == 'success' || decoded['statusCode'] == 200;
      if (!ok) {
        final msg = decoded['message']?.toString() ?? 'Server error';
        throw ServerException(msg);
      }

      final response = decoded['response'];
      if (response is! Map<String, dynamic>) {
        AppLogger.warning(_tag, 'Unexpected response shape');
        return [];
      }

      final data = response['data'];
      if (data is! List) {
        AppLogger.warning(_tag, 'data is not a List: $data');
        return [];
      }

      final categories = data
          .whereType<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .where((c) => c.title.isNotEmpty) // skip malformed entries
          .toList();

      AppLogger.info(_tag, 'Parsed ${categories.length} categories');
      return categories;
    } catch (e, st) {
      if (e is AppException) rethrow;
      AppLogger.error(_tag, 'fetchHomeData error', e, st);
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
