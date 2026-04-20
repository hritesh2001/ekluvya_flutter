import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/search_result_model.dart';
import '../../data/remote/search_api_service.dart';

enum SearchState { idle, loading, loaded, empty, error }

class SearchViewModel extends ChangeNotifier {
  static const _tag = 'SearchViewModel';
  static const _debounce = Duration(milliseconds: 300);

  SearchViewModel({SearchApiService? service})
      : _service = service ?? SearchApiService();

  final SearchApiService _service;

  SearchState _state = SearchState.idle;
  List<SearchResultModel> _results = const [];
  String _errorMessage = '';
  String _query = '';
  bool _isDisposed = false;
  Timer? _debounceTimer;

  SearchState get state => _state;
  List<SearchResultModel> get results => _results;
  String get errorMessage => _errorMessage;
  String get query => _query;

  // ── Public API ──────────────────────────────────────────────────────────────

  void onQueryChanged(String q) {
    _query = q;
    _debounceTimer?.cancel();

    if (q.trim().isEmpty) {
      _results = const [];
      _setSearchState(SearchState.idle);
      return;
    }

    _setSearchState(SearchState.loading);
    _debounceTimer = Timer(_debounce, () => _fetch(q.trim()));
  }

  void clear() {
    _debounceTimer?.cancel();
    _query = '';
    _results = const [];
    _setSearchState(SearchState.idle);
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  Future<void> _fetch(String q) async {
    try {
      final results = await _service.search(q);
      if (_isDisposed) return;
      _results = results;
      _setSearchState(results.isEmpty ? SearchState.empty : SearchState.loaded);
    } on AppException catch (e) {
      if (_isDisposed) return;
      _errorMessage = e.message;
      AppLogger.error(_tag, 'Search failed: ${e.message}');
      _setSearchState(SearchState.error);
    } catch (e, st) {
      if (_isDisposed) return;
      _errorMessage = 'Something went wrong. Please try again.';
      AppLogger.error(_tag, 'Search unexpected error', e, st);
      _setSearchState(SearchState.error);
    }
  }

  void _setSearchState(SearchState next) {
    if (_isDisposed || _state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
