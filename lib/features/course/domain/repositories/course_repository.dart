import '../../data/models/category_model.dart';

/// Domain contract for course/category data access.
/// The ViewModel depends on this abstraction only.
abstract class CourseRepository {
  /// Returns all categories with their nested courses.
  ///
  /// - Offline + cache available  → returns cached list.
  /// - Offline + no cache         → throws [NetworkException].
  /// - API failure + cache        → returns stale cache.
  /// - API failure + no cache     → rethrows [AppException].
  Future<List<CategoryModel>> getCategories();
}
