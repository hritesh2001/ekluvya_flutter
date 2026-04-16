import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/banner_repository.dart';
import '../models/banner_model.dart';
import '../remote/banner_api_service.dart';

/// Concrete implementation of [BannerRepository].
///
/// Strategy:
/// 1. On success → update in-memory cache and return sorted list.
/// 2. On any failure → serve cached data if available, otherwise rethrow.
///
/// Connectivity is NOT pre-checked — the HTTP call surfaces
/// [NetworkException] / [RequestTimeoutException] reliably without the
/// risk of connectivity_plus hanging on certain Android versions.
class BannerRepositoryImpl implements BannerRepository {
  static const _tag = 'BannerRepositoryImpl';

  final BannerApiService _apiService;

  /// In-memory cache — lives for the app session.
  /// Populated on first successful fetch; used as offline fallback.
  List<BannerModel>? _cache;

  BannerRepositoryImpl({required BannerApiService apiService})
      : _apiService = apiService;

  @override
  Future<List<BannerModel>> getBanners() async {
    try {
      final banners = await _apiService.fetchBanners();

      // Sort ascending by order so UI always displays in the correct sequence
      banners.sort((a, b) => a.order.compareTo(b.order));

      _cache = banners;
      AppLogger.info(_tag, 'Fetched & cached ${banners.length} banners');
      return banners;
    } catch (e) {
      AppLogger.error(_tag, 'Fetch failed — checking cache', e);
      if (_cache != null) {
        AppLogger.info(_tag, 'Serving ${_cache!.length} stale cached banners');
        return _cache!;
      }
      rethrow;
    }
  }
}
