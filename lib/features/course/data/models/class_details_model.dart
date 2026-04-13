/// Represents the class/grade info attached to a course.
/// e.g. { "_id": "...", "title": "CLASS 7" }
class ClassDetailsModel {
  final String id;
  final String title;

  const ClassDetailsModel({required this.id, required this.title});

  factory ClassDetailsModel.fromJson(Map<String, dynamic> json) {
    return ClassDetailsModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}
