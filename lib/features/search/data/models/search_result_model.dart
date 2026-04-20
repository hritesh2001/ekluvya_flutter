import '../../../../core/constants/app_constants.dart';

class SearchResultModel {
  const SearchResultModel({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String thumbnailUrl;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    // Priority: new_thumbnail_images.webp.to → new_thumbnail_images.default.to
    String thumbnailPath = '';
    final thumbImages = json['new_thumbnail_images'];
    if (thumbImages is Map<String, dynamic>) {
      final webp = thumbImages['webp'];
      if (webp is Map<String, dynamic>) {
        thumbnailPath = webp['to']?.toString() ?? '';
      }
      if (thumbnailPath.isEmpty) {
        final def = thumbImages['default'];
        if (def is Map<String, dynamic>) {
          thumbnailPath = def['to']?.toString() ?? '';
        }
      }
    }

    return SearchResultModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnailUrl: _toAbsoluteUrl(thumbnailPath),
    );
  }

  // API returns relative paths — prepend the CDN base URL when needed.
  static String _toAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppConstants.thumbnailCdnBaseUrl;
    // Avoid double-slash when base already ends with '/' and path starts with '/'.
    if (base.endsWith('/') && path.startsWith('/')) {
      return '$base${path.substring(1)}';
    }
    return '$base$path';
  }
}
