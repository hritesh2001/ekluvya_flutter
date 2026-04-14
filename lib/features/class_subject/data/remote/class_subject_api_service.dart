import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/class_model.dart';
import '../models/subject_item_model.dart';

/// Fetches classes and subjects from:
///   GET [mediaBaseUrl]/home/classes?courseId=&page=&limit=15&is_pagination=true
///   GET [mediaBaseUrl]/home/subjects?courseId=&classId=&page=1&limit=25&is_pagination=true
class ClassSubjectApiService {
  static const _tag = 'ClassSubjectApiService';

  // ── Classes ────────────────────────────────────────────────────────────────

  /// Fetches all classes for [courseId].
  /// Paginates automatically until all pages are consumed or [limit] is reached.
  Future<List<ClassModel>> fetchClasses({
    required String courseId,
    int page = 1,
    int limit = 15,
  }) async {
    final url =
        '${AppConstants.mediaBaseUrl}/home/classes'
        '?courseId=$courseId&page=$page&limit=$limit&is_pagination=true';

    AppLogger.info(_tag, 'GET classes → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Classes response ${res.statusCode}');
      return _parseList<ClassModel>(res, ClassModel.fromJson, 'classes');
    } catch (e, st) {
      return _handleError<ClassModel>(e, st, 'fetchClasses');
    }
  }

  // ── Subjects ───────────────────────────────────────────────────────────────

  /// Fetches subjects for the given [courseId] + [classId] combination.
  Future<List<SubjectItemModel>> fetchSubjects({
    required String courseId,
    required String classId,
    int page = 1,
    int limit = 25,
  }) async {
    final url =
        '${AppConstants.mediaBaseUrl}/home/subjects'
        '?courseId=$courseId&classId=$classId&page=$page&limit=$limit&is_pagination=true';

    AppLogger.info(_tag, 'GET subjects → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Subjects response ${res.statusCode}');
      return _parseList<SubjectItemModel>(
          res, SubjectItemModel.fromJson, 'subjects');
    } catch (e, st) {
      return _handleError<SubjectItemModel>(e, st, 'fetchSubjects');
    }
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Decodes an HTTP response and extracts the list of [T] from
  /// `response.data` (the common API envelope pattern).
  ///
  /// Supported envelope shapes:
  ///   { "status": "success", "response": { "data": [...] } }
  ///   { "statusCode": 200,   "response": { "data": [...] } }
  ///   { "statusCode": 200,   "data": [...] }           ← flat fallback
  List<T> _parseList<T>(
    http.Response res,
    T Function(Map<String, dynamic>) fromJson,
    String debugLabel,
  ) {
    // Guard: server returned HTML (e.g. nginx error page)
    if (res.body.trimLeft().startsWith('<!')) {
      throw const ParseException();
    }

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException catch (e) {
      AppLogger.error(_tag, 'JSON parse error for $debugLabel: $e');
      throw const ParseException();
    }

    // Status check
    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      final msg = decoded['message']?.toString() ?? 'Server error';
      throw ServerException(msg);
    }

    // Try nested envelope first, fall back to flat `data`
    List? rawList;
    final response = decoded['response'];
    if (response is Map<String, dynamic>) {
      rawList = response['data'] as List?;
    }
    rawList ??= decoded['data'] as List?;

    if (rawList == null) {
      AppLogger.warning(_tag, '$debugLabel: no data list in response');
      return [];
    }

    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .where((item) {
          // Filter out items with empty IDs to skip malformed entries
          if (item is ClassModel) return item.id.isNotEmpty;
          if (item is SubjectItemModel) return item.id.isNotEmpty;
          return true;
        })
        .toList();

    AppLogger.info(_tag, 'Parsed ${items.length} $debugLabel items');
    return items;
  }

  /// Normalises low-level Dart/HTTP exceptions into typed [AppException]s.
  List<T> _handleError<T>(Object e, StackTrace st, String method) {
    if (e is AppException) throw e;
    AppLogger.error(_tag, '$method error', e, st);
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
