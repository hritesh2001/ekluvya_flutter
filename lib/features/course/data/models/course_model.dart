import '../../../../core/constants/app_constants.dart';
import 'class_details_model.dart';
import 'subject_model.dart';

/// A single course inside a category.
///
/// API shape:
/// ```json
/// {
///   "_id": "682c37587030ad5fa362f3ce",
///   "title": "IIT FOUNDATION",
///   "profile_picture": "course-images/1748842523892-blob.png",
///   "class_details": { "_id": "...", "title": "CLASS 7" },
///   "subjectTitle":  { "_id": "...", "title": "TAMIL" }
/// }
/// ```
class CourseModel {
  final String id;
  final String title;

  /// Relative path from API — use [fullImageUrl] for the complete URL.
  final String profilePicture;

  final ClassDetailsModel? classDetails;
  final SubjectModel? subjectTitle;

  /// Placeholder — API does not yet return a video count.
  /// Will be populated in a future API version.
  final int? videoCount;

  const CourseModel({
    required this.id,
    required this.title,
    required this.profilePicture,
    this.classDetails,
    this.subjectTitle,
    this.videoCount,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      classDetails: json['class_details'] is Map<String, dynamic>
          ? ClassDetailsModel.fromJson(
              json['class_details'] as Map<String, dynamic>)
          : null,
      subjectTitle: json['subjectTitle'] is Map<String, dynamic>
          ? SubjectModel.fromJson(
              json['subjectTitle'] as Map<String, dynamic>)
          : null,
      videoCount: (json['videoCount'] as num?)?.toInt() ??
          (json['total_videos'] as num?)?.toInt(),
    );
  }

  /// Full CloudFront image URL for the course thumbnail.
  String get fullImageUrl =>
      '${AppConstants.bannerImageBaseUrl}$profilePicture';

  bool get hasImage => profilePicture.isNotEmpty;
}
