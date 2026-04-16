import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/category_model.dart';
import '../remote/course_api_service.dart';

/// Concrete implementation of [CourseRepository].
///
/// Adds in-memory caching on top of [CourseApiService].
/// Connectivity is NOT pre-checked — the HTTP call surfaces
/// [NetworkException] / [RequestTimeoutException] reliably without the
/// risk of connectivity_plus hanging on certain Android versions.
class CourseRepositoryImpl implements CourseRepository {
  static const _tag = 'CourseRepositoryImpl';

  final CourseApiService _apiService;

  /// In-memory cache — survives the app session, cleared on restart.
  List<CategoryModel>? _cache;

  CourseRepositoryImpl({required CourseApiService apiService})
      : _apiService = apiService;

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final categories = await _apiService.fetchHomeData();
      _cache = categories;
      AppLogger.info(_tag, 'Fetched & cached ${categories.length} categories');
      return categories;
    } catch (e) {
      AppLogger.error(_tag, 'Fetch failed — checking cache', e);
      if (_cache != null) {
        AppLogger.info(_tag, 'Returning stale cache (${_cache!.length} items)');
        return _cache!;
      }
      rethrow;
    }
  }
}
