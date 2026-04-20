import '../../../../core/constants/app_constants.dart';
import 'course_model.dart';

/// A top-level category (e.g. ACADEMICS, LIFE SKILLS) that
/// contains a list of courses.
///
/// API shape (relevant fields):
/// ```json
/// {
///   "_id": "...",
///   "title": "ACADEMICS",
///   "order": 2,
///   "profile_picture": "streamcollection-images/xyz.png",
///   "total": 8,          ← total courses on the server
///   "data": [ ...courses ]
/// }
/// ```
class CategoryModel {
  final String id;
  final String title;
  final int order;

  /// Relative path from the API — use [fullImageUrl] for display.
  final String profilePicture;

  /// Courses returned for this page (limited by inside_limit).
  final List<CourseModel> courses;

  /// Total courses available on the server for this category.
  /// Use this for the "X Courses" subtitle rather than courses.length.
  final int totalCourses;

  /// Not yet returned by the API — reserved for a future version.
  final int? totalVideos;

  const CategoryModel({
    required this.id,
    required this.title,
    required this.order,
    required this.profilePicture,
    required this.courses,
    required this.totalCourses,
    this.totalVideos,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final courses = rawData is List
        ? rawData
            .whereType<Map<String, dynamic>>()
            .map(CourseModel.fromJson)
            .toList()
        : <CourseModel>[];

    return CategoryModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      profilePicture: json['profile_picture']?.toString() ?? '',
      courses: courses,
      // 'total' is the server-side count of all courses in this category
      totalCourses: (json['total'] as num?)?.toInt() ?? courses.length,
      totalVideos: (json['totalVideos'] as num?)?.toInt() ??
          (json['total_videos'] as num?)?.toInt(),
    );
  }

  /// Full CloudFront image URL for the collection background.
  String get fullImageUrl => profilePicture.isNotEmpty
      ? '${AppConstants.thumbnailCdnBaseUrl}$profilePicture'
      : '';

  bool get hasCourses => courses.isNotEmpty;
}
