/// Active subscription plan from GET /mediaview/api/v1/subscription.
///
/// Actual API path (confirmed from live response):
///   response.subscriptionList.user_subscription.active_subscription
///     .name       → plan name  (e.g. "One Week Plan")
///     .price      → paid price (e.g. 117)
///     .end_date   → ISO-8601   (e.g. "2026-04-29T07:54:11.274Z")
///     .status     → "active"
class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.planName,
    required this.expiryText,
    required this.priceDisplay,
    required this.isActive,
  });

  final String planName;
  final String expiryText;   // raw value from API
  final String priceDisplay; // e.g. "INR 117"
  final bool isActive;

  bool get hasPrice => priceDisplay.isNotEmpty;

  // ── Days-remaining helpers (mirrors TransactionModel) ──────────────────────

  /// Parses [expiryText] to a local [DateTime], using the same multi-format
  /// logic as [expiryDateDisplay]. Returns null when parsing fails.
  DateTime? get endDate {
    if (expiryText.isEmpty) return null;

    // DD/MM/YYYY
    final slash = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(expiryText);
    if (slash != null) {
      return DateTime.tryParse(
          '${slash.group(3)}-${slash.group(2)}-${slash.group(1)}');
    }

    // DD-MM-YYYY
    final dash = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(expiryText);
    if (dash != null) {
      return DateTime.tryParse(
          '${dash.group(3)}-${dash.group(2)}-${dash.group(1)}');
    }

    // Unix timestamp (seconds or milliseconds)
    final asInt = int.tryParse(expiryText);
    if (asInt != null && asInt > 0) {
      try {
        final ms = asInt > 9999999999 ? asInt : asInt * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      } catch (_) {}
    }

    // ISO-8601 / space-separated datetime
    try {
      final normalised = expiryText.contains('T')
          ? expiryText
          : expiryText.replaceFirst(' ', 'T');
      return DateTime.parse(normalised).toLocal();
    } catch (_) {}

    // YYYY-MM-DD substring
    final ymd = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(expiryText);
    if (ymd != null) {
      return DateTime.tryParse(
          '${ymd.group(1)}-${ymd.group(2)}-${ymd.group(3)}');
    }

    return null;
  }

  int get daysRemaining {
    final d = endDate;
    if (d == null) return -1;
    final endDay = DateTime(d.year, d.month, d.day);
    final today  = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.difference(todayDay).inDays;
  }

  /// "EXPIRE IN X DAYS", "EXPIRING TODAY", "EXPIRED", or '' when unknown.
  String get expiryLabel {
    if (expiryText.isEmpty) return '';
    final d = daysRemaining;
    if (d < 0)  return 'EXPIRED';
    if (d == 0) return 'EXPIRING TODAY';
    if (d == 1) return 'EXPIRE IN 1 DAY';
    return 'EXPIRE IN $d DAYS';
  }

  bool get isExpired => daysRemaining < 0;

  /// Converts [expiryText] → "DD/MM/YYYY".
  /// Handles ISO-8601, space-separated datetime, Unix timestamps (s/ms),
  /// DD/MM/YYYY, DD-MM-YYYY, and bare YYYY-MM-DD strings.
  String get expiryDateDisplay {
    if (expiryText.isEmpty) return '';

    // Already DD/MM/YYYY
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(expiryText)) return expiryText;

    // DD-MM-YYYY (e.g. "01-05-2025")
    final ddMmYyyy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(expiryText);
    if (ddMmYyyy != null) {
      return '${ddMmYyyy.group(1)}/${ddMmYyyy.group(2)}/${ddMmYyyy.group(3)}';
    }

    // Unix timestamp — seconds (10 digits) or milliseconds (13 digits)
    final asInt = int.tryParse(expiryText);
    if (asInt != null && asInt > 0) {
      try {
        final ms = asInt > 9999999999 ? asInt : asInt * 1000;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    // ISO-8601 / space-separated datetime
    try {
      final normalised =
          expiryText.contains('T') ? expiryText : expiryText.replaceFirst(' ', 'T');
      final dt = DateTime.parse(normalised).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}

    // Last-resort: extract YYYY-MM-DD substring
    final ymd = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(expiryText);
    if (ymd != null) return '${ymd.group(3)}/${ymd.group(2)}/${ymd.group(1)}';

    return '';
  }

  // ── Factory ────────────────────────────────────────────────────────────────

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    // Null-safe string extractor — collapses null / "null" to ''.
    String s(dynamic v) {
      if (v == null) return '';
      final str = v.toString().trim();
      return str == 'null' ? '' : str;
    }

    final response = json['response'];
    final Map<String, dynamic> resp =
        response is Map<String, dynamic> ? response : const {};

    Map<String, dynamic> planData = const {};
    bool isUserSubscribed = false;

    // ── Path 1 (primary): response.subscriptionList (Map) ─────────────────
    final subList = resp['subscriptionList'];
    if (subList is Map<String, dynamic>) {
      final userSub = subList['user_subscription'];
      if (userSub is Map<String, dynamic>) {
        isUserSubscribed = userSub['is_user_subscribed'] == true ||
            userSub['is_user_subscribed'] == 1 ||
            userSub['is_user_subscribed'] == '1';

        // The actual plan fields live one level deeper in active_subscription.
        final activeSub = userSub['active_subscription'];
        if (activeSub is Map<String, dynamic>) {
          planData = activeSub;
        } else {
          planData = userSub;
        }
      }

      // user_subscription might be a List
      if (planData.isEmpty) {
        final userSubArr = subList['user_subscription'];
        if (userSubArr is List && userSubArr.isNotEmpty && userSubArr.first is Map) {
          final first = Map<String, dynamic>.from(userSubArr.first as Map);
          final activeSub = first['active_subscription'];
          planData = activeSub is Map<String, dynamic> ? activeSub : first;
        }
      }
    }

    // ── Path 2: response.subscriptionList as a List ───────────────────────
    if (planData.isEmpty &&
        subList is List &&
        subList.isNotEmpty &&
        subList.first is Map) {
      planData = Map<String, dynamic>.from(subList.first as Map);
    }

    // ── Path 3: response.user_subscription (flat) ─────────────────────────
    if (planData.isEmpty) {
      final v = resp['user_subscription'];
      if (v is Map<String, dynamic>) {
        final activeSub = v['active_subscription'];
        planData = activeSub is Map<String, dynamic> ? activeSub : v;
        isUserSubscribed = isUserSubscribed ||
            v['is_user_subscribed'] == true ||
            v['is_user_subscribed'] == 1;
      }
    }

    // ── Path 4: response.subscription / response.subscriptions ───────────
    if (planData.isEmpty) {
      final v = resp['subscription'] ?? resp['subscriptions'];
      if (v is List && v.isNotEmpty && v.first is Map) {
        planData = Map<String, dynamic>.from(v.first as Map);
      } else if (v is Map<String, dynamic>) {
        planData = v;
      }
    }

    // ── Path 5: response.subscription_detail / response.plan_details ─────
    if (planData.isEmpty) {
      final v = resp['subscription_detail'] ?? resp['plan_details'];
      if (v is Map<String, dynamic> && v.isNotEmpty) planData = v;
    }

    // ── Path 6: last-resort — resp has plan keys directly ────────────────
    if (planData.isEmpty) {
      const planKeys = ['name', 'plan_name', 'price', 'amount', 'end_date'];
      if (planKeys.any((k) => resp.containsKey(k))) planData = resp;
    }

    // ── Extract fields ────────────────────────────────────────────────────

    final name = s(planData['name'] ??
        planData['plan_name'] ??
        planData['plan'] ??
        planData['subscription_plan_name'] ??
        planData['plan_title'] ??
        planData['package_name']);

    final expiry = s(planData['end_date'] ??
        planData['expiry_date'] ??
        planData['expiry'] ??
        planData['subscription_end_date'] ??
        planData['valid_till'] ??
        planData['validity_date'] ??
        planData['expire_date'] ??
        planData['plan_expiry']);

    final rawPrice = s(planData['price'] ??
        planData['amount'] ??
        planData['plan_price'] ??
        planData['subscription_amount'] ??
        planData['offer_price']);

    // Strip trailing ".0" from whole-number prices (e.g. "117.0" → "117")
    final cleanPrice = () {
      if (rawPrice.isEmpty) return '';
      final d = double.tryParse(rawPrice);
      if (d == null) return rawPrice;
      return d == d.truncateToDouble() ? d.toInt().toString() : rawPrice;
    }();

    final active = isUserSubscribed ||
        planData['status'] == 'active' ||
        planData['is_active'] == true ||
        planData['is_active'] == 1;

    return SubscriptionPlanModel(
      planName: name.isNotEmpty ? name : 'Current Plan',
      expiryText: expiry,
      priceDisplay: cleanPrice.isNotEmpty ? 'INR $cleanPrice' : '',
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
