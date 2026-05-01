import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';
import '../models/subscription_plan_item_model.dart';

/// Fetches the subscription plans list from
/// GET /mediaview/api/v1/subscription →
/// response.subscriptionList.subscriptions
class SubscriptionApiService {
  static const _tag = 'SubscriptionApiService';

  Map<String, String> _authHeader(String token) =>
      {'Authorization': 'Bearer $token'};

  Future<List<SubscriptionPlanItem>> getPlans(String token) async {
    final url = Uri.parse('${AppConstants.mediaBaseUrl}/subscription');
    try {
      final res = await http
          .get(url, headers: _authHeader(token))
          .timeout(AppConstants.apiTimeout);

      AppLogger.info(_tag, 'getPlans → ${res.statusCode}');
      if (res.body.trimLeft().startsWith('<!')) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return [];

      final response = decoded['response'];
      if (response is! Map<String, dynamic>) return [];

      final subList = response['subscriptionList'];
      if (subList is! Map<String, dynamic>) return [];

      // Support both 'subscriptions' and 'subscription' key names.
      final raw = subList['subscriptions'] ?? subList['subscription'];
      final subscriptions = raw is List ? raw : [];
      if (subscriptions.isEmpty) {
        AppLogger.info(_tag, 'No subscriptions found. subList keys: ${subList.keys.toList()}');
        return [];
      }

      final plans = <SubscriptionPlanItem>[];
      for (int i = 0; i < subscriptions.length; i++) {
        final item = subscriptions[i];
        if (item is Map<String, dynamic>) {
          // Debug: log raw fields of first plan so we can confirm field names.
          if (i == 0) {
            AppLogger.info(_tag, 'plan[0] keys: ${item.keys.toList()}');
            final prices = item['prices'];
            if (prices is Map) {
              AppLogger.info(_tag, 'plan[0].prices keys: ${prices.keys.toList()} → $prices');
            }
            AppLogger.info(_tag,
                'plan[0] amount="${item['amount']}" '
                'discounted_price="${item['discounted_price']}" '
                'days="${item['days']}" '
                'plan_name="${item['plan_name'] ?? item['name']}"');
          }
          plans.add(SubscriptionPlanItem.fromJson(
            item,
            isRecommended: i == 0,
          ));
        }
      }
      AppLogger.info(_tag, 'Parsed ${plans.length} plans. '
          'plan[0] price=${plans.isNotEmpty ? plans[0].price : "n/a"} '
          'original=${plans.isNotEmpty ? plans[0].originalPrice : "n/a"}');
      return plans;
    } catch (e, st) {
      AppLogger.error(_tag, 'getPlans error', e, st);
      return [];
    }
  }
}
