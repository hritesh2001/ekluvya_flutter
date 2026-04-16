import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/chapter_model.dart';
import '../models/class_model.dart';
import '../models/subject_item_model.dart';

/// Fetches classes and subjects from:
///   GET [mediaBaseUrl]/home/classes?courseId=&page=1&limit=15&is_pagination=true
///   GET [mediaBaseUrl]/home/subjects?courseId=&classId=&page=1&limit=25&is_pagination=true
///
/// Both endpoints are public — no auth header required.
class ClassSubjectApiService {
  static const _tag = 'ClassSubjectApiService';

  // ── Classes ────────────────────────────────────────────────────────────────

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

  // ── Chapters ───────────────────────────────────────────────────────────────

  Future<List<ChapterModel>> fetchChapters({
    required String courseId,
    required String classId,
    required String subjectId,
  }) async {
    // Endpoint and param order confirmed from Android network logs.
    final url =
        '${AppConstants.mediaBaseUrl}/home/all/chapterlist'
        '?courseId=$courseId&subjectId=$subjectId&classId=$classId';

    AppLogger.info(_tag, 'GET chapterlist → $url');

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'Chapterlist response ${res.statusCode}');
      return _parseChapterList(res);
    } catch (e, st) {
      return _handleError<ChapterModel>(e, st, 'fetchChapters');
    }
  }

  List<ChapterModel> _parseChapterList(http.Response res) {
    if (res.body.trimLeft().startsWith('<!')) {
      AppLogger.error(_tag, 'Received HTML instead of JSON for chapterlist');
      throw const ParseException();
    }

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      if (raw is! Map<String, dynamic>) throw const ParseException();
      decoded = raw;
    } on FormatException catch (e) {
      AppLogger.error(_tag, 'JSON parse error for chapterlist: $e');
      throw const ParseException();
    }

    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      final msg = decoded['message']?.toString() ?? 'Server error';
      throw ServerException(msg);
    }

    // Response key is "chapterList", not "data".
    final response = decoded['response'];
    final rawList = (response is Map<String, dynamic>)
        ? response['chapterList'] as List?
        : null;

    if (rawList == null) {
      AppLogger.warning(_tag, 'No chapterList in response');
      return [];
    }

    final chapters = rawList
        .whereType<Map<String, dynamic>>()
        .map(ChapterModel.fromJson)
        .where((c) => c.hasValidId)
        .toList()
      // Sort ascending by order so the first chapter is the lowest-order one.
      ..sort((a, b) => a.order.compareTo(b.order));

    AppLogger.info(_tag, 'Parsed ${chapters.length} chapters');
    return chapters;
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  List<T> _parseList<T>(
    http.Response res,
    T Function(Map<String, dynamic>) fromJson,
    String debugLabel,
  ) {
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

    final ok = decoded['status'] == 'success' ||
        (decoded['statusCode'] as num?)?.toInt() == 200;
    if (!ok) {
      final msg = decoded['message']?.toString() ?? 'Server error';
      throw ServerException(msg);
    }

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
          if (item is ClassModel) return item.id.isNotEmpty;
          if (item is SubjectItemModel) return item.id.isNotEmpty;
          if (item is ChapterModel) return item.hasValidId;
          return true;
        })
        .toList();

    AppLogger.info(_tag, 'Parsed ${items.length} $debugLabel items');
    return items;
  }

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
