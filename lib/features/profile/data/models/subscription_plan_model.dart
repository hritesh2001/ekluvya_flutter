/// Active subscription plan from GET /mediaview/api/v1/subscription.
class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.planName,
    required this.expiryText,
    required this.priceDisplay,
    required this.isActive,
  });

  final String planName;
  final String expiryText;   // raw expiry string from API
  final String priceDisplay; // e.g. "INR 117"
  final bool isActive;

  bool get hasPrice => priceDisplay.isNotEmpty;
  bool get hasExpiry => expiryText.isNotEmpty;

  // ── Factory ────────────────────────────────────────────────────────────────

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    // API path: response → subscriptionList → user_subscription
    final response = json['response'];
    final Map<String, dynamic> resp =
        response is Map<String, dynamic> ? response : const {};

    // Try nested path first, fall back to flat path
    Map<String, dynamic> planData = const {};
    final subList = resp['subscriptionList'];
    if (subList is Map<String, dynamic>) {
      final userSub = subList['user_subscription'];
      if (userSub is Map<String, dynamic>) planData = userSub;
    }
    if (planData.isEmpty) {
      final directSub = resp['user_subscription'];
      if (directSub is Map<String, dynamic>) planData = directSub;
    }
    // Some APIs return a list — take first element
    if (planData.isEmpty) {
      final subArr = resp['subscription'] ?? resp['subscriptions'];
      if (subArr is List && subArr.isNotEmpty && subArr.first is Map) {
        planData = Map<String, dynamic>.from(subArr.first as Map);
      }
    }

    final name = (planData['plan_name']
            ?? planData['name']
            ?? planData['plan']
            ?? '')
        .toString();

    final expiry = (planData['end_date']
            ?? planData['expiry_date']
            ?? planData['expiry']
            ?? '')
        .toString();

    final rawPrice = (planData['price']
            ?? planData['amount']
            ?? planData['plan_price']
            ?? '')
        .toString();

    final active = planData['is_user_subscribed'] == true
        || planData['is_user_subscribed'] == 1
        || planData['is_user_subscribed'] == '1'
        || planData['status'] == 'active';

    return SubscriptionPlanModel(
      planName: name.isNotEmpty ? name : 'Current Plan',
      expiryText: expiry,
      priceDisplay: rawPrice.isNotEmpty ? 'INR $rawPrice' : '',
      isActive: active,
    );
  }

  static const SubscriptionPlanModel none = SubscriptionPlanModel(
    planName: '',
    expiryText: '',
    priceDisplay: '',
    isActive: false,
  );
}
