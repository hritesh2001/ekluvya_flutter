import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight wrapper around connectivity_plus.
/// Screens/ViewModels should NOT import connectivity_plus directly.
abstract class ConnectivityService {
  ConnectivityService._();

  /// Returns true if the device has at least one active network interface.
  /// Falls back to true on check failure so the real HTTP call can surface
  /// a more descriptive error instead of a silent block.
  static Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}
