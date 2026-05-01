/// A single subscription plan from
/// GET /mediaview/api/v1/subscription →
/// response.subscriptionList.subscriptions[*]
class SubscriptionPlanItem {
  const SubscriptionPlanItem({
    required this.id,
    required this.planName,
    required this.price,
    required this.originalPrice,
    required this.description,
    required this.duration,
    required this.isRecommended,
  });

  final String id;
  final String planName;

  /// Discounted sale price (INR, no GST).
  final double price;

  /// Original MRP (INR). 0 when not provided.
  final double originalPrice;

  final String description;

  /// Human-readable duration, e.g. "1 year", "1 week".
  final String duration;

  /// True for the first/default plan in the list.
  final bool isRecommended;

  bool get hasDiscount => originalPrice > 0 && originalPrice > price;

  /// Display string for the current price (e.g. "₹7,500/ year + 18% GST").
  String get priceDisplay {
    final formatted = _formatIndianPrice(price);
    final suffix =
        duration.isNotEmpty ? '/ $duration + 18% GST' : '+ 18% GST';
    return '$formatted $suffix';
  }

  /// Display string for the original/MRP price (e.g. "₹10,000").
  String get originalPriceDisplay => _formatIndianPrice(originalPrice);

  /// Price + 18% GST, rounded, with Indian comma formatting.
  String get ctaPriceDisplay => _formatIndianPrice(price * 1.18);

  // ── Factory ────────────────────────────────────────────────────────────────

  factory SubscriptionPlanItem.fromJson(
    Map<String, dynamic> json, {
    bool isRecommended = false,
  }) {
    // Helper: read string from root OR from a nested map.
    String s(String key, [Map<String, dynamic>? nested]) {
      final v = (nested ?? json)[key];
      if (v == null) return '';
      final str = v.toString().trim();
      return str == 'null' ? '' : str;
    }

    double d(String key, [Map<String, dynamic>? nested]) =>
        double.tryParse(s(key, nested)) ?? 0.0;

    // Some APIs nest price fields under a `prices` object.
    final pricesMap = json['prices'] is Map<String, dynamic>
        ? json['prices'] as Map<String, dynamic>
        : null;

    final id   = s('id').isNotEmpty ? s('id') : s('plan_id');
    final name = s('plan_name').isNotEmpty ? s('plan_name') : s('name');
    final desc = s('description').isNotEmpty
        ? s('description')
        : s('plan_description');

    // Duration: explicit label > days field (at root or in prices).
    final rawDur = s('plan_duration').isNotEmpty
        ? s('plan_duration')
        : s('duration');
    final daysRaw = json['days'] ?? pricesMap?['days'];
    final days = (daysRaw as num?)?.toInt() ?? 0;
    final dur = rawDur.isNotEmpty ? rawDur : _daysToLabel(days);

    // ── Price resolution ────────────────────────────────────────────────────
    // Priority: prices.amount > root amount > root price
    // discounted_price is the DISCOUNT AMOUNT (not the final price).
    // finalPrice = amount - discounted_price
    final amount = pricesMap != null
        ? d('amount', pricesMap)
        : d('amount');

    final discountAmount = pricesMap != null
        ? d('discounted_price', pricesMap)
        : d('discounted_price');

    final legacyPrice = d('price', pricesMap) > 0
        ? d('price', pricesMap)
        : d('price');

    final finalPrice = amount > 0
        ? (amount - discountAmount).clamp(0.0, double.infinity)
        : legacyPrice;

    // MRP / original price = amount (before discount).
    final mrp = amount > 0
        ? amount
        : (d('mrp', pricesMap) > 0
            ? d('mrp', pricesMap)
            : (d('original_price', pricesMap) > 0
                ? d('original_price', pricesMap)
                : d('mrp') > 0 ? d('mrp') : d('original_price')));

    return SubscriptionPlanItem(
      id: id,
      planName: name.isNotEmpty ? name : 'Subscription Plan',
      price: finalPrice,
      originalPrice: mrp,
      description: desc,
      duration: dur,
      isRecommended: isRecommended,
    );
  }

  static String _daysToLabel(int days) {
    if (days == 365) return 'year';
    if (days >= 28 && days <= 31) return 'month';
    if (days == 7) return 'week';
    if (days == 1) return 'day';
    if (days > 1) return '$days days';
    return '';
  }
}

// ── Number formatter ──────────────────────────────────────────────────────────

/// Returns price formatted with Indian comma conventions, e.g. ₹7,500 or ₹1,00,000.
String _formatIndianPrice(double price) {
  final n = price.round();
  if (n <= 0) return '';
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  // Last 3 digits, then groups of 2 from right
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final buf = StringBuffer(last3);
  while (rest.isNotEmpty) {
    final chunk = rest.length >= 2 ? rest.substring(rest.length - 2) : rest;
    rest = rest.length >= 2 ? rest.substring(0, rest.length - 2) : '';
    buf.write(',');
    buf.write(chunk);
    // flip later
  }
  // buf contains last3,XX,XX... reversed groups — rebuild properly
  final parts = <String>[];
  final raw = s;
  if (raw.length <= 3) return '₹$raw';
  parts.add(raw.substring(raw.length - 3));
  var idx = raw.length - 3;
  while (idx > 0) {
    final start = (idx - 2).clamp(0, idx);
    parts.add(raw.substring(start, idx));
    idx = start;
  }
  return '₹${parts.reversed.join(',')}';
}
