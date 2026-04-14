/// Represents a single class/grade returned by:
///   GET /mediaview/api/v1/home/classes?courseId=&page=&limit=15
///
/// Example JSON:
/// ```json
/// { "_id": "abc123", "title": "CLASS 7", "order": 1 }
/// ```
class ClassModel {
  final String id;
  final String title;
  final int order;

  const ClassModel({
    required this.id,
    required this.title,
    this.order = 0,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) => ClassModel(
        id: json['_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ClassModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClassModel(id: $id, title: $title)';
}
