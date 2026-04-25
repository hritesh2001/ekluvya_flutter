import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

class TransactionApiService {
  static const _tag = 'TransactionApiService';

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Fetches paginated transactions.
  ///
  /// Returns the decoded JSON map or an empty map on any error.
  Future<Map<String, dynamic>> fetchTransactions({
    required String token,
    int page  = 1,
    int limit = 10,
  }) async {
    final now = DateTime.now();
    final toDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url = Uri.parse(
      '${AppConstants.paymentBaseUrl}/payments/transaction/user'
      '?limit=$limit&page=$page&from=1956-01-01&to=$toDate',
    );

    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(AppConstants.apiTimeout);
      AppLogger.info(_tag, 'fetchTransactions → ${res.statusCode}');
      if (res.body.trimLeft().startsWith('<!')) return {};
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e, st) {
      AppLogger.error(_tag, 'fetchTransactions error', e, st);
      return {};
    }
  }
}
