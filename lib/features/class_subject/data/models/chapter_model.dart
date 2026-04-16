/// A single chapter returned by:
///   GET /mediaview/api/v1/home/chapters?courseId=&classId=&subjectId=&page=1&limit=100
class ChapterModel {
  final String id;
  final String title;
  final int order;

  const ChapterModel({
    required this.id,
    required this.title,
    this.order = 0,
  });

  bool get hasValidId => id.isNotEmpty;

  factory ChapterModel.fromJson(Map<String, dynamic> json) => ChapterModel(
        id: json['_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChapterModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChapterModel(id: $id, title: $title)';
}
