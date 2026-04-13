import '../../../../core/constants/app_constants.dart';

/// Data model for a single banner item returned by the API.
///
/// Maps directly to the JSON structure from:
///   GET homebanners/banner-images/
///
/// All fields are null-safe — missing/null values from the server
/// are replaced with empty strings or zero.
class BannerModel {
  final String id;
  final String title;
  final int order;
  final String bannerUrl;
  final String slug;
  final String bannerImg;

  const BannerModel({
    required this.id,
    required this.title,
    required this.order,
    required this.bannerUrl,
    required this.slug,
    required this.bannerImg,
  });

  /// Parses a single banner JSON object safely.
  /// Any null or missing field falls back to a safe default.
  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      bannerUrl: json['bannerurl']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      bannerImg: json['bannerImg']?.toString() ?? '',
    );
  }

  /// Full image URL: CDN base URL + relative [bannerImg] path.
  ///
  /// Example:
  ///   bannerImg = "banner-images/1756391384009-blob.png"
  ///   → https://stg-ottapi.ekluvya.guru/mediaview/banner-images/1756391384009-blob.png
  String get fullImageUrl => '${AppConstants.bannerImageBaseUrl}$bannerImg';

  /// True when the banner has a tappable destination URL.
  bool get hasLink => bannerUrl.isNotEmpty;
}
