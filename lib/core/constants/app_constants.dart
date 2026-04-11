/// Centralized constants — no magic strings scattered across the codebase.
abstract class AppConstants {
  AppConstants._();

  // ── API ───────────────────────────────────────────────────────────────────
  static const String usersBaseUrl =
      'https://stg-ottapi.ekluvya.guru/users/api/v1';
  static const String mediaBaseUrl =
      'https://stg-ottapi.ekluvya.guru/mediaview/api/v1';

  /// Global timeout for every HTTP request.
  static const Duration apiTimeout = Duration(seconds: 15);

  // ── Local Storage ─────────────────────────────────────────────────────────
  static const String tokenKey = 'auth_token';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const String countryCode = '91';
  static const int otpLength = 6;
  static const int minPhoneLength = 10;
}
