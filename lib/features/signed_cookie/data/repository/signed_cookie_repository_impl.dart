import '../../../../core/utils/logger.dart';
import '../../domain/repositories/signed_cookie_repository.dart';
import '../models/signed_cookie_model.dart';
import '../remote/signed_cookie_api_service.dart';

class SignedCookieRepositoryImpl implements SignedCookieRepository {
  static const _tag = 'SignedCookieRepositoryImpl';

  final SignedCookieApiService _api;
  SignedCookieRepositoryImpl({required SignedCookieApiService apiService})
      : _api = apiService;

  SignedCookieModel? _cached;
  Future<SignedCookieModel>? _inFlight;

  @override
  Future<SignedCookieModel> getSignedCookies() {
    // Return cached cookies if still valid
    final cached = _cached;
    if (cached != null && cached.isValid) {
      AppLogger.info(_tag, 'Returning cached signed cookies (valid until ${cached.expires})');
      return Future.value(cached);
    }
    // Deduplicate in-flight requests
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _fetch();
    _inFlight = future;
    return future;
  }

  Future<SignedCookieModel> _fetch() async {
    try {
      final data = await _api.fetchSignedCookies();
      _cached = data;
      AppLogger.info(_tag, 'Fetched signed cookies, expires ${data.expires}');
      return data;
    } catch (e) {
      AppLogger.error(_tag, 'Signed cookie fetch failed: $e');
      final cached = _cached;
      if (cached != null) return cached; // serve stale if available
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}
