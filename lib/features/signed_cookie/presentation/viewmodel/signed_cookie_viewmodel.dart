import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/signed_cookie_model.dart';
import '../../domain/repositories/signed_cookie_repository.dart';

/// Holds CloudFront signed cookies for Tutorix CDN video playback.
///
/// Call [fetch] once when the course detail screen initialises.
/// Idempotent — skips the network call if cookies are still valid.
/// Non-fatal on error — content still shows without signed cookies.
class SignedCookieViewModel extends ChangeNotifier {
  static const _tag = 'SignedCookieViewModel';

  final SignedCookieRepository _repo;
  SignedCookieViewModel({required SignedCookieRepository repository})
      : _repo = repository;

  SignedCookieModel? _cookies;
  bool _loading = false;

  /// True while the request is in flight.
  bool get isLoading => _loading;

  /// The signed cookie bundle, or null if not yet fetched / failed.
  SignedCookieModel? get cookies => _cookies;

  /// Convenience: single Cookie header string ready for HTTP requests.
  /// Returns empty string if cookies are unavailable.
  String get cookieHeader => _cookies?.isValid == true
      ? _cookies!.cookieHeader
      : '';

  /// Map of CloudFront cookie name → value for use in video player headers.
  Map<String, String> get cookieMap =>
      _cookies?.isValid == true ? _cookies!.cookieMap : {};

  /// Fetches signed cookies. Skips if already valid. Non-fatal on failure.
  Future<void> fetch() async {
    // Skip if we already have valid cookies
    if (_cookies != null && _cookies!.isValid) return;
    if (_loading) return;

    _loading = true;
    notifyListeners();

    try {
      _cookies = await _repo.getSignedCookies();
      AppLogger.info(_tag, 'Signed cookies ready, expires ${_cookies!.expires}');
    } catch (e) {
      // Non-fatal — Tutorix videos will fail to play but other content unaffected
      AppLogger.warning(_tag, 'Signed cookie fetch failed (non-fatal): $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
