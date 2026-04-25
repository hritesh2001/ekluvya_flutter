import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../data/models/transaction_model.dart';
import '../../data/remote/transaction_api_service.dart';

enum TransactionLoadState { initial, loading, loaded, error }

class TransactionHistoryViewModel extends ChangeNotifier {
  static const _tag  = 'TransactionHistoryViewModel';
  static const _limit = 10;

  TransactionHistoryViewModel({
    required TransactionApiService transactionApi,
    required ApiService authApi,
  })  : _api     = transactionApi,
        _authApi  = authApi;

  final TransactionApiService _api;
  final ApiService             _authApi;

  // ── State ───────────────────────────────────────────────────────────────────

  TransactionLoadState _state = TransactionLoadState.initial;
  String?              _error;
  final List<TransactionModel> _transactions = [];
  int  _currentPage  = 1;
  int  _totalPages   = 1;
  bool _isFetchingMore = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  TransactionLoadState get state => _state;
  bool get isLoading      => _state == TransactionLoadState.loading;
  bool get hasData        => _state == TransactionLoadState.loaded;
  bool get hasError       => _state == TransactionLoadState.error;
  String? get error       => _error;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isEmpty        => hasData && _transactions.isEmpty;
  bool get hasMore        => _currentPage < _totalPages;
  bool get isFetchingMore => _isFetchingMore;

  // ── Load (initial) ──────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_state == TransactionLoadState.loading) return;

    _state        = TransactionLoadState.loading;
    _error        = null;
    _currentPage  = 1;
    _transactions.clear();
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _fail('Please log in to view transactions.');
        return;
      }

      final json = await _api.fetchTransactions(
        token: token,
        page:  _currentPage,
        limit: _limit,
      );

      _parseAndAppend(json);
      _state = TransactionLoadState.loaded;
      AppLogger.info(_tag, 'Loaded ${_transactions.length} transactions');
    } catch (e, st) {
      _fail('Could not load transactions. Please try again.');
      AppLogger.error(_tag, 'load error', e, st);
    } finally {
      notifyListeners();
    }
  }

  // ── Load more (pagination) ──────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (_isFetchingMore || !hasMore) return;

    _isFetchingMore = true;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) return;

      final json = await _api.fetchTransactions(
        token: token,
        page:  _currentPage + 1,
        limit: _limit,
      );

      _parseAndAppend(json);
      AppLogger.info(_tag, 'Loaded more — total ${_transactions.length}');
    } catch (e, st) {
      AppLogger.error(_tag, 'loadMore error', e, st);
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _parseAndAppend(Map<String, dynamic> json) {
    final resp = json['response'];
    if (resp is! Map<String, dynamic>) return;

    final data = resp['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          try {
            _transactions.add(TransactionModel.fromJson(item));
          } catch (e) {
            AppLogger.warning(_tag, 'Skipping malformed transaction: $e');
          }
        }
      }
    }

    final totalPages = resp['totalPages'];
    if (totalPages is num) _totalPages = totalPages.toInt();

    final currentPage = resp['currentPage'];
    if (currentPage is num) _currentPage = currentPage.toInt();
  }

  void _fail(String msg) {
    _state = TransactionLoadState.error;
    _error  = msg;
    notifyListeners();
  }
}
