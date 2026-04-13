/// Represents the subject info attached to a course.
/// e.g. { "_id": "...", "title": "TAMIL" }
class SubjectModel {
  final String id;
  final String title;

  const SubjectModel({required this.id, required this.title});

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}
