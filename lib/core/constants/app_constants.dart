/// Centralized constants — no magic strings scattered across the codebase.
abstract class AppConstants {
  AppConstants._();

  // ── API ───────────────────────────────────────────────────────────────────
  static const String usersBaseUrl =
      'https://stg-ottapi.ekluvya.guru/users/api/v1';
  static const String mediaBaseUrl =
      'https://stg-ottapi.ekluvya.guru/mediaview/api/v1';
  static const String userActionsBaseUrl =
      'https://stg-ottapi.ekluvya.guru/useractions/api/v1';

  /// Base for non-versioned mediaview endpoints (e.g. get-signed-cookies).
  static const String mediaApiBaseUrl =
      'https://stg-ottapi.ekluvya.guru/mediaview/api';

  static const String searchBaseUrl =
      'https://stg-ottapi.ekluvya.guru/search/api/v1';

  /// CloudFront CDN base URL for banner assets.
  /// Final URL = bannerImageBaseUrl + bannerImg field from API.
  static const String bannerImageBaseUrl =
      'https://d38zvxejdrf8bt.cloudfront.net/';

  /// CDN base URL for video thumbnail images returned by channel-list API.
  /// Thumbnail paths in API are relative (e.g. "gudsho-upload-.../blob.jpg").
  /// Final URL = thumbnailCdnBaseUrl + path.
  /// Verify this value against the network tab if images don't load.
  static const String thumbnailCdnBaseUrl =
      'https://d38zvxejdrf8bt.cloudfront.net/';

  /// Global timeout for every HTTP request.
  static const Duration apiTimeout = Duration(seconds: 15);

  // ── Local Storage ─────────────────────────────────────────────────────────
  static const String tokenKey = 'auth_token';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const String countryCode = '91';
  static const int otpLength = 6;
  static const int minPhoneLength = 10;
}
