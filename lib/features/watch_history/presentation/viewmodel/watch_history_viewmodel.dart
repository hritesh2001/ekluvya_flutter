import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../../auth/presentation/viewmodel/session_viewmodel.dart';
import '../../../video_player/data/services/watch_progress_service.dart';
import '../../data/local/watch_history_delete_store.dart';
import '../../data/models/watch_history_item_model.dart';
import '../../data/remote/watch_history_api_service.dart';

enum WatchHistoryLoadState { initial, loading, loaded, error }

class WatchHistoryViewModel extends ChangeNotifier {
  static const _tag = 'WatchHistoryViewModel';

  WatchHistoryViewModel({
    required WatchHistoryApiService watchHistoryApi,
    required ApiService authApi,
    required SessionViewModel sessionVM,
    WatchProgressService? progressService,
    WatchHistoryDeleteStore? deleteStore,
  })  : _api            = watchHistoryApi,
        _authApi         = authApi,
        _sessionVM       = sessionVM,
        _progressService = progressService ?? WatchProgressService(),
        _deleteStore     = deleteStore     ?? WatchHistoryDeleteStore();

  final WatchHistoryApiService _api;
  final ApiService             _authApi;
  final SessionViewModel       _sessionVM;
  final WatchProgressService   _progressService;

  /// Persists deleted mediaIds to SharedPreferences so they survive restarts.
  /// Acts as a client-side filter when the backend is slow to propagate deletes.
  final WatchHistoryDeleteStore _deleteStore;

  // ── State ──────────────────────────────────────────────────────────────────

  WatchHistoryLoadState _state = WatchHistoryLoadState.initial;
  String? _error;
  final List<WatchHistoryItemModel> _items = [];
  bool _isBusy = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  WatchHistoryLoadState get state => _state;
  bool get isLoading  => _state == WatchHistoryLoadState.loading;
  bool get hasError   => _state == WatchHistoryLoadState.error;
  bool get hasData    => _state == WatchHistoryLoadState.loaded;
  String? get error   => _error;
  List<WatchHistoryItemModel> get items => List.unmodifiable(_items);
  bool get isEmpty    => hasData && _items.isEmpty;
  bool get isBusy     => _isBusy;

  // ── Public entry points ────────────────────────────────────────────────────

  Future<void> load() async {
    if (_isBusy) return;
    await _fetchInternal(showSpinner: true);
  }

  Future<void> refreshWatchHistory() async {
    if (_isBusy) return;
    await _fetchInternal(showSpinner: _state == WatchHistoryLoadState.initial);
  }

  // ── Remove single item (optimistic) ───────────────────────────────────────

  Future<void> removeItem(String mediaId) async {
    final idx = _items.indexWhere((item) => item.mediaId == mediaId);
    if (idx < 0) return;

    final profileId = _sessionVM.defaultProfileId;
    AppLogger.info(
      _tag,
      'removeItem ▶  mediaId=$mediaId  '
      'profile_id: ${profileId.isNotEmpty ? profileId : "(empty)"}',
    );

    final removed = _items.removeAt(idx);
    notifyListeners(); // immediate optimistic UI update

    // Persist BEFORE the network call — deletion survives an app kill.
    await _deleteStore.markDeleted(mediaId);

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        // No auth — restore item and un-persist the deletion.
        _items.insert(idx, removed);
        await _deleteStore.unmarkDeleted(mediaId);
        notifyListeners();
        AppLogger.warning(_tag, 'removeItem ✗ no token — restored');
        return;
      }

      await _api.removeItem(
        token:     token,
        mediaId:   mediaId,
        profileId: profileId,
      );
      AppLogger.info(_tag, 'removeItem ✓ mediaId=$mediaId');
    } catch (e) {
      // API error — UI stays cleared; deletion filter remains active.
      // Cross-platform note: item may still appear on web until backend syncs.
      AppLogger.warning(_tag, 'removeItem ✗ API error (item stays hidden): $e');
    }
  }

  // ── Clear all (optimistic — UI clears immediately, API call is fire-and-forget)
  //
  // Mirrors removeItem: optimistic UI update first, then backend sync.
  // The deleteStore filter prevents cleared items from reappearing on any
  // subsequent re-fetch even if the backend is slow to propagate.

  Future<void> clearAll() async {
    if (_isBusy) return;

    final profileId = _sessionVM.defaultProfileId;
    final token = await _authApi.getToken() ?? '';

    if (token.isEmpty) {
      AppLogger.warning(_tag, 'clearAll ✗ no token — aborting');
      return;
    }

    AppLogger.info(
      _tag,
      'clearAll ▶  '
      'profile_id: ${profileId.isNotEmpty ? profileId : "(empty)"}  '
      'items: ${_items.length}',
    );

    // ── Step 1: Optimistic update — clear UI immediately ───────────────────
    final mediaIds = _items.map((i) => i.mediaId).toSet();
    _items.clear();
    _state = WatchHistoryLoadState.loaded;

    // Persist deletion intent so items don't reappear on re-fetch even if
    // the backend is slow to propagate.
    await _deleteStore.markAllDeleted(mediaIds);
    notifyListeners();

    // ── Step 2: Backend sync ───────────────────────────────────────────────
    try {
      await _api.clearAll(token: token, profileId: profileId);
      // Reset the delete filter immediately so re-watched videos (same mediaId)
      // are not silently filtered on the next fetch. cleanupAbsent() cannot
      // remove an ID that re-appears in the API response, so without this reset
      // a re-watched video would remain hidden by the stale delete filter.
      await _deleteStore.reset();
      AppLogger.info(_tag, 'clearAll ✓ backend confirmed deletion, filter reset');
    } catch (e) {
      // Backend failed — UI is already cleared and the deleteStore filter
      // keeps items hidden. Log the error; the user has already seen items go.
      AppLogger.warning(_tag, 'clearAll ✗ API error (UI already cleared): $e');
    }

    // ── Step 3: Silent re-fetch to let the backend confirm empty state ─────
    // deleteStore ensures items stay hidden even if backend is slow.
    unawaited(_fetchInternal(showSpinner: false));
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _fetchInternal({required bool showSpinner}) async {
    _isBusy = true;

    if (showSpinner) {
      _state = WatchHistoryLoadState.loading;
      _error = null;
      _items.clear();
      notifyListeners();
    }

    // Restore persisted deletion filter before touching any data.
    await _deleteStore.load();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _fail('Please log in to view your history.');
        return;
      }

      final profileId = _sessionVM.defaultProfileId;
      AppLogger.info(
        _tag,
        'fetch ▶  profile_id: ${profileId.isNotEmpty ? profileId : "(empty)"}  '
        'deleteFilter: ${_deleteStore.hasEntries}',
      );

      final json = await _api.fetchWatchHistory(
        token:     token,
        profileId: profileId,
      );

      final fresh = _parseResponse(json);
      AppLogger.info(_tag, 'fetch ◀  ${fresh.length} items from API');

      final apiIds = fresh.map((i) => i.mediaId).toSet();

      if (fresh.isEmpty && _deleteStore.hasEntries) {
        // Backend returned empty → deletion fully propagated — wipe filter.
        await _deleteStore.reset();
        AppLogger.info(_tag, 'fetch: backend confirmed empty — delete filter cleared');
      } else if (fresh.isNotEmpty && _deleteStore.hasEntries) {
        // Drop filter entries for items the API no longer returns (deleted on server).
        await _deleteStore.cleanupAbsent(apiIds);
      }

      final enriched = await _enrichThumbnails(fresh);

      // Apply deletion filter — hides items the user deleted even if the
      // backend hasn't propagated the change yet (survives app restarts).
      final visible = _deleteStore.apply(enriched);

      AppLogger.info(
        _tag,
        'fetch: showing ${visible.length} / ${fresh.length} items '
        '(${fresh.length - visible.length} filtered by delete store)',
      );

      _items
        ..clear()
        ..addAll(visible);
      _state = WatchHistoryLoadState.loaded;
    } catch (e, st) {
      if (showSpinner || _items.isEmpty) {
        _fail('Could not load watch history. Please try again.');
      }
      AppLogger.error(_tag, 'fetch error', e, st);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  List<WatchHistoryItemModel> _parseResponse(Map<String, dynamic> json) {
    final dataList = _extractList(json);
    if (dataList == null) {
      AppLogger.warning(_tag, 'No parseable list in response: ${json.keys}');
      return [];
    }
    AppLogger.info(_tag, 'Raw list length: ${dataList.length}');

    final results = <WatchHistoryItemModel>[];
    for (final item in dataList) {
      if (item is Map<String, dynamic>) {
        try {
          results.add(WatchHistoryItemModel.fromJson(item));
        } catch (e) {
          AppLogger.warning(_tag, 'Skipping malformed item: $e');
        }
      }
    }
    return results;
  }

  List<dynamic>? _extractList(Map<String, dynamic> json) {
    final resp = json['response'];
    if (resp is Map<String, dynamic>) {
      for (final key in ['data', 'result', 'watchHistory', 'items']) {
        final v = resp[key];
        if (v is List) return v;
      }
    }
    if (resp is List) return resp;
    for (final key in ['data', 'result', 'items']) {
      final v = json[key];
      if (v is List) return v;
    }
    return null;
  }

  Future<List<WatchHistoryItemModel>> _enrichThumbnails(
    List<WatchHistoryItemModel> items,
  ) async {
    final enriched = <WatchHistoryItemModel>[];
    for (final item in items) {
      final cached = await _progressService.getThumbnail(item.mediaId);
      enriched.add(
        cached != null && cached.isNotEmpty
            ? item.copyWith(thumbnailUrl: cached)
            : item,
      );
    }
    return enriched;
  }

  void _fail(String msg) {
    _state = WatchHistoryLoadState.error;
    _error = msg;
    notifyListeners();
  }
}
