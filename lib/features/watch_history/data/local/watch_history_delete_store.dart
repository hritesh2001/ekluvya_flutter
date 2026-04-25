import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../models/watch_history_item_model.dart';

/// Persists watch-history deletion intent across app restarts.
///
/// Every time the user removes an item or clears all history, the affected
/// mediaIds are written to SharedPreferences.  On the next app launch, the
/// store is reloaded so the same items are filtered out of the API response —
/// even if the backend hasn't propagated the deletion yet.
///
/// The store cleans itself up automatically:
///   • When the API returns an empty list → backend confirmed → [reset].
///   • When the API omits items that were in [_deletedIds] → those items
///     were genuinely deleted → [cleanupAbsent] removes stale entries.
class WatchHistoryDeleteStore {
  static const _tag       = 'WatchHistoryDeleteStore';
  static const _kDeleted  = 'wh_deleted_ids';

  final Set<String> _deletedIds = {};
  bool _loaded = false;

  // ── Accessors ──────────────────────────────────────────────────────────────

  bool get hasEntries => _deletedIds.isNotEmpty;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads the persisted set from SharedPreferences.
  /// Idempotent — safe to call on every fetch; only reads once per session.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids   = prefs.getStringList(_kDeleted) ?? const [];
      _deletedIds.addAll(ids);
      AppLogger.info(_tag, 'Loaded ${_deletedIds.length} pending deletes');
    } catch (e) {
      AppLogger.warning(_tag, 'load failed: $e');
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Persists a single item deletion.
  Future<void> markDeleted(String mediaId) async {
    _deletedIds.add(mediaId);
    await _save();
  }

  /// Persists a batch of deletions (used by clearAll).
  Future<void> markAllDeleted(Iterable<String> mediaIds) async {
    _deletedIds.addAll(mediaIds);
    await _save();
  }

  /// Removes a single entry — used only when rolling back (token-empty case).
  Future<void> unmarkDeleted(String mediaId) async {
    _deletedIds.remove(mediaId);
    await _save();
  }

  /// Drops entries the API no longer returns — those items are genuinely
  /// deleted on the server, so no filter entry is needed any more.
  /// Called after every successful fetch to keep the set bounded.
  Future<void> cleanupAbsent(Set<String> apiMediaIds) async {
    final stale = _deletedIds
        .where((id) => !apiMediaIds.contains(id))
        .toSet();
    if (stale.isEmpty) return;
    _deletedIds.removeAll(stale);
    AppLogger.info(_tag, 'Cleaned up ${stale.length} stale entries');
    await _save();
  }

  /// Clears all entries — called when the API returns an empty list,
  /// confirming the backend has propagated the deletion.
  Future<void> reset() async {
    if (_deletedIds.isEmpty) return;
    _deletedIds.clear();
    await _save();
    AppLogger.info(_tag, 'Reset — backend confirmed empty history');
  }

  // ── Filter ─────────────────────────────────────────────────────────────────

  /// Returns [items] with any user-deleted entries removed.
  List<WatchHistoryItemModel> apply(List<WatchHistoryItemModel> items) {
    if (_deletedIds.isEmpty) return items;
    return items
        .where((item) => !_deletedIds.contains(item.mediaId))
        .toList();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kDeleted, _deletedIds.toList());
    } catch (e) {
      AppLogger.warning(_tag, '_save failed: $e');
    }
  }
}
