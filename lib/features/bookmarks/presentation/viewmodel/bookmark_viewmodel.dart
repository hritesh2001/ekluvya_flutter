import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../../auth/presentation/viewmodel/session_viewmodel.dart';
import '../../data/models/bookmark_item_model.dart';
import '../../data/remote/bookmark_api_service.dart';

enum BookmarkLoadState { initial, loading, loaded, error }

/// Result returned by [BookmarkViewModel.requestToggle] so the widget layer
/// can handle redirects without coupling the ViewModel to navigation.
/// NOTE: Bookmark actions are login-gated only — subscription state is irrelevant.
enum BookmarkToggleResult { success, requiresLogin, error }

class BookmarkViewModel extends ChangeNotifier {
  static const _tag = 'BookmarkViewModel';

  BookmarkViewModel({
    required BookmarkApiService bookmarkApi,
    required ApiService authApi,
    required SessionViewModel sessionVM,
  })  : _api = bookmarkApi,
        _authApi = authApi,
        _sessionVM = sessionVM {
    _sessionVM.addListener(_onSessionChanged);
  }

  final BookmarkApiService _api;
  final ApiService _authApi;
  final SessionViewModel _sessionVM;

  // ── List state ─────────────────────────────────────────────────────────────

  BookmarkLoadState _state = BookmarkLoadState.initial;
  final List<BookmarkItemModel> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isBusy = false;
  String? _error;

  // In-flight episode IDs — prevents duplicate concurrent toggle calls.
  final Set<String> _inFlight = {};

  // O(1) bookmark status lookup — populated from list fetch + optimistic toggle.
  final Set<String> _bookmarkedIds = {};

  // ── Getters ────────────────────────────────────────────────────────────────

  BookmarkLoadState get state => _state;
  bool get isLoading => _state == BookmarkLoadState.loading;
  bool get hasData => _state == BookmarkLoadState.loaded;
  bool get hasError => _state == BookmarkLoadState.error;
  bool get isEmpty => hasData && _items.isEmpty;
  bool get isBusy => _isBusy;
  bool get hasMore => _hasMore;
  List<BookmarkItemModel> get items => List.unmodifiable(_items);
  String? get error => _error;

  // Bookmark visibility is login-gated only — subscription state is irrelevant.
  bool isBookmarked(String episodeId) =>
      _sessionVM.isLoggedIn && _bookmarkedIds.contains(episodeId);

  // ── Fetch bookmark list ────────────────────────────────────────────────────

  Future<void> fetchBookmarks({bool forceRefresh = false}) async {
    if (_isBusy) return;
    if (!_hasMore && !forceRefresh) return;

    if (forceRefresh) {
      _page = 1;
      _hasMore = true;
    }

    _isBusy = true;

    if (forceRefresh || _state == BookmarkLoadState.initial) {
      _state = BookmarkLoadState.loading;
      _error = null;
      if (forceRefresh) _items.clear();
      notifyListeners();
    }

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _fail('Please log in to view bookmarks.');
        return;
      }

      final json = await _api.fetchBookmarks(token: token, page: _page);
      final fresh = _parseResponse(json);

      AppLogger.info(_tag, 'fetchBookmarks: page=$_page got=${fresh.length}');

      if (_page == 1 || forceRefresh) {
        _items
          ..clear()
          ..addAll(fresh);
        _bookmarkedIds.clear();
      } else {
        _items.addAll(fresh);
      }

      for (final item in fresh) {
        if (item.isWatchLater) _bookmarkedIds.add(item.episodeId);
      }

      _hasMore = fresh.length >= 14;
      if (_hasMore) _page++;

      _state = BookmarkLoadState.loaded;
    } catch (e, st) {
      AppLogger.error(_tag, 'fetchBookmarks error', e, st);
      if (_items.isEmpty) _fail('Could not load bookmarks. Please try again.');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isBusy || !_hasMore) return;
    await fetchBookmarks();
  }

  // ── Toggle bookmark ────────────────────────────────────────────────────────
  //
  // Returns [BookmarkToggleResult] so the caller (widget layer) can redirect
  // to login or subscription without the ViewModel touching navigation.

  Future<BookmarkToggleResult> requestToggle({
    required String episodeId,
    required String seasonId,
  }) async {
    if (episodeId.isEmpty) return BookmarkToggleResult.error;
    if (_inFlight.contains(episodeId)) return BookmarkToggleResult.error;

    // ── Access control ───────────────────────────────────────────────────────

    if (!_sessionVM.isLoggedIn) {
      AppLogger.info(_tag, 'requestToggle: not logged in');
      return BookmarkToggleResult.requiresLogin;
    }
    // No subscription gate — bookmark add/remove must always work for logged-in users.

    // ── Optimistic update ────────────────────────────────────────────────────

    _inFlight.add(episodeId);
    final wasBookmarked = _bookmarkedIds.contains(episodeId);

    if (wasBookmarked) {
      _bookmarkedIds.remove(episodeId);
    } else {
      _bookmarkedIds.add(episodeId);
    }
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _rollback(episodeId, wasBookmarked);
        AppLogger.warning(_tag, 'requestToggle: no token — rolled back');
        return BookmarkToggleResult.error;
      }

      await _api.toggleBookmark(
        token: token,
        episodeId: episodeId,
        seasonId: seasonId,
        isWatchLater: wasBookmarked ? 0 : 1,
      );

      AppLogger.info(
        _tag,
        'requestToggle ✓ episodeId=$episodeId  bookmarked=${!wasBookmarked}',
      );

      // Background sync — keeps the list consistent without blocking the UI.
      unawaited(fetchBookmarks(forceRefresh: true));

      return BookmarkToggleResult.success;
    } catch (e) {
      _rollback(episodeId, wasBookmarked);
      AppLogger.warning(_tag, 'requestToggle ✗ API error (rolled back): $e');
      return BookmarkToggleResult.error;
    } finally {
      _inFlight.remove(episodeId);
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _rollback(String episodeId, bool wasBookmarked) {
    if (wasBookmarked) {
      _bookmarkedIds.add(episodeId);
    } else {
      _bookmarkedIds.remove(episodeId);
    }
    notifyListeners();
  }

  List<BookmarkItemModel> _parseResponse(Map<String, dynamic> json) {
    final dataList = _extractList(json);
    if (dataList == null) {
      AppLogger.warning(_tag, 'No parseable list in response: ${json.keys}');
      return [];
    }
    AppLogger.info(_tag, 'Raw list length: ${dataList.length}');

    final results = <BookmarkItemModel>[];
    for (final item in dataList) {
      if (item is Map<String, dynamic>) {
        try {
          results.add(BookmarkItemModel.fromJson(item));
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
      for (final key in ['data', 'result', 'bookmarks', 'items']) {
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

  void _fail(String msg) {
    _state = BookmarkLoadState.error;
    _error = msg;
    notifyListeners();
  }

  // Clears cached bookmark state on logout only.
  // Subscription changes do NOT clear bookmarks — bookmarks are login-gated only.
  void _onSessionChanged() {
    if (!_sessionVM.isLoggedIn) {
      _bookmarkedIds.clear();
      _items.clear();
      _state = BookmarkLoadState.initial;
      _page = 1;
      _hasMore = true;
      notifyListeners();
      AppLogger.info(_tag, '_onSessionChanged: logged out — bookmark state cleared');
    }
  }

  @override
  void dispose() {
    _sessionVM.removeListener(_onSessionChanged);
    super.dispose();
  }
}
