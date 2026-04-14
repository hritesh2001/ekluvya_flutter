/// Represents a single subject returned by:
///   GET /mediaview/api/v1/home/subjects?courseId=&classId=&page=1&limit=25
///
/// Deliberately named [SubjectItemModel] to avoid shadowing the lightweight
/// [SubjectModel] used in the course-card data layer.
///
/// Example JSON:
/// ```json
/// { "_id": "xyz789", "title": "PHYSICS", "order": 2 }
/// ```
class SubjectItemModel {
  final String id;
  final String title;
  final int order;

  const SubjectItemModel({
    required this.id,
    required this.title,
    this.order = 0,
  });

  factory SubjectItemModel.fromJson(Map<String, dynamic> json) =>
      SubjectItemModel(
        id: json['_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectItemModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubjectItemModel(id: $id, title: $title)';
}
