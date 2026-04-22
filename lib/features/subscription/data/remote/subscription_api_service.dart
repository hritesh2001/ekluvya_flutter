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

      final subscriptions = subList['subscriptions'];
      if (subscriptions is! List || subscriptions.isEmpty) return [];

      final plans = <SubscriptionPlanItem>[];
      for (int i = 0; i < subscriptions.length; i++) {
        final item = subscriptions[i];
        if (item is Map<String, dynamic>) {
          plans.add(SubscriptionPlanItem.fromJson(
            item,
            isRecommended: i == 0,
          ));
        }
      }
      AppLogger.info(_tag, 'Parsed ${plans.length} plans');
      return plans;
    } catch (e, st) {
      AppLogger.error(_tag, 'getPlans error', e, st);
      return [];
    }
  }
}
