import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Real-time network state tracker.
///
/// Register once at app start via [ChangeNotifierProvider]:
///   create: (_) => NetworkService()..init()
///
/// Widgets / ViewModels listen to [isOnline] changes, and any layer can call
/// [checkNow] to force a re-check (e.g. when the user taps Retry).
class NetworkService extends ChangeNotifier {
  bool _isOnline = true;

  /// True when the device has at least one active network interface.
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Subscribe to connectivity changes and perform an initial check.
  /// Call this once after construction.
  void init() {
    _check(); // async fire-and-forget: resolves before first frame completes
    _sub = Connectivity().onConnectivityChanged.listen(_applyResults);
  }

  /// Re-checks connectivity on demand (e.g. Retry button).
  /// Returns the new [isOnline] value.
  Future<bool> checkNow() async {
    await _check();
    return _isOnline;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _check() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _applyResults(results);
    } catch (_) {
      // Keep current state — the HTTP call will surface the real error.
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
