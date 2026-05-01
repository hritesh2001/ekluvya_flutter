import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/search_result_model.dart';

/// Calls the Ekluvya elastic-search endpoint.
///
/// Endpoint:
///   GET [searchBaseUrl]/elastic/search?q={q}&limit={limit}&page={page}
class SearchApiService {
  static const _tag = 'SearchApiService';

  Future<List<SearchResultModel>> search(
    String query, {
    int limit = 12,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.searchBaseUrl}/elastic/search',
    ).replace(queryParameters: {
      'q': query,
      'limit': '$limit',
      'page': '$page',
    });

    AppLogger.info(_tag, 'GET search → $uri');

    try {
      final res = await http.get(uri).timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'Search response ${res.statusCode}');
      return _parse(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  List<SearchResultModel> _parse(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) throw const ParseException();

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException {
      throw const ParseException();
    }

    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      throw ServerException(
        decoded['message']?.toString() ?? 'Search failed.',
      );
    }

    // Results live at various nesting levels depending on the endpoint version.
    List<dynamic> items = const [];
    final resp = decoded['response'];
    if (resp is Map<String, dynamic>) {
      items = (resp['data'] ?? resp['hits']) as List? ?? const [];
    } else {
      items = (decoded['data'] ?? decoded['hits']) as List? ?? const [];
    }

    // Log raw fields of the first result so we know what the API actually returns.
    if (items.isNotEmpty && items.first is Map<String, dynamic>) {
      final first = items.first as Map<String, dynamic>;
      AppLogger.info(_tag, 'search result[0] keys: ${first.keys.toList()}');
      AppLogger.info(_tag, 'search result[0] slug="${first['slug']}" '
          'course_id="${first['course_id']}" class_id="${first['class_id']}" '
          'subject_id="${first['subject_id']}" '
          'hls="${first['hls_playlist_url']}"');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(SearchResultModel.fromJson)
        .toList();
  }

  Never _handleError(Object e, StackTrace st) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, 'search error', e, st);
    if (e is TimeoutException) throw const RequestTimeoutException();
    if (e is IOException) throw const NetworkException();
    if (e is http.ClientException) throw const NetworkException();
    throw ServerException('Search failed: ${e.runtimeType}');
  }
}
