import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/category_model.dart';
import '../remote/course_api_service.dart';

/// Concrete implementation of [CourseRepository].
///
/// Adds offline detection and in-memory caching on top of [CourseApiService].
class CourseRepositoryImpl implements CourseRepository {
  static const _tag = 'CourseRepositoryImpl';

  final CourseApiService _apiService;

  /// In-memory cache — survives the app session, cleared on restart.
  List<CategoryModel>? _cache;

  CourseRepositoryImpl({required CourseApiService apiService})
      : _apiService = apiService;

  @override
  Future<List<CategoryModel>> getCategories() async {
    final isConnected = await ConnectivityService.isConnected();

    if (!isConnected) {
      AppLogger.warning(_tag, 'Device is offline');
      if (_cache != null) {
        AppLogger.info(_tag, 'Serving ${_cache!.length} cached categories');
        return _cache!;
      }
      throw const NetworkException();
    }

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
