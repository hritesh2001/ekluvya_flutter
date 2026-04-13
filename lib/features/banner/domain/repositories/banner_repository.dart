import '../../data/models/banner_model.dart';

/// Domain contract for banner data access.
///
/// The ViewModel depends on this abstraction, not the concrete
/// [BannerRepositoryImpl]. This keeps presentation logic decoupled from
/// data-fetching details and makes the ViewModel trivially testable.
abstract class BannerRepository {
  /// Returns banners sorted ascending by [BannerModel.order].
  ///
  /// - If offline and cached data exists → returns cached list (no throw).
  /// - If offline and no cache → throws [NetworkException].
  /// - On API failure with existing cache → returns cache (no throw).
  /// - On API failure with no cache → rethrows the [AppException].
  Future<List<BannerModel>> getBanners();
}
