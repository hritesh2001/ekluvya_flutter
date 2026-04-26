import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/banner_model.dart';
import '../../domain/repositories/banner_repository.dart';

/// UI state machine for the banner carousel.
enum BannerState {
  /// First launch — nothing has been attempted yet.
  initial,

  /// API call is in flight.
  loading,

  /// API returned successfully (list may be empty).
  loaded,

  /// API call failed and no cache is available.
  error,
}

/// Exposes banner state and data to the UI layer.
///
/// Depends on [BannerRepository] (abstract) — not the concrete impl —
/// so it stays decoupled from data-fetching details.
class BannerViewModel extends ChangeNotifier {
  static const _tag = 'BannerViewModel';

  final BannerRepository _repository;

  BannerState _state = BannerState.initial;
  List<BannerModel> _banners = [];
  String? _errorMessage;

  BannerViewModel(this._repository);

  // ── Getters ─────────────────────────────────────────────────────────────

  BannerState get state => _state;
  List<BannerModel> get banners => List.unmodifiable(_banners);
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == BannerState.loading;
  bool get hasError => _state == BannerState.error;
  bool get hasData => _state == BannerState.loaded && _banners.isNotEmpty;
  bool get isEmpty => _state == BannerState.loaded && _banners.isEmpty;

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Loads banners from the repository.
  /// Guards against duplicate in-flight calls.
  Future<void> loadBanners() async {
    if (_state == BannerState.loading) return;

    _state = BannerState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _banners = await _repository.getBanners();
      _state = BannerState.loaded;
      AppLogger.info(_tag, 'Loaded ${_banners.length} banners');
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _state = BannerState.error;
      AppLogger.warning(_tag, 'Network error: $e');
    } on RequestTimeoutException catch (e) {
      _errorMessage = e.message;
      _state = BannerState.error;
      AppLogger.warning(_tag, 'Timeout: $e');
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _state = BannerState.error;
      AppLogger.error(_tag, 'Server error: $e');
    } catch (e, st) {
      _errorMessage = 'Something went wrong. Please try again.';
      _state = BannerState.error;
      AppLogger.error(_tag, 'Unexpected error', e, st);
    } finally {
      notifyListeners();
    }
  }

  /// Clears error state and re-fetches — wired to the Retry button.
  void retry() => loadBanners();

  /// Public alias used by connectivity listeners to re-fetch after internet
  /// is restored.  Identical to [retry] but semantically distinct at call sites.
  void refreshBanners() => loadBanners();
}
