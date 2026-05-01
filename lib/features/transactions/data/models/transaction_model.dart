/// Single transaction record from
/// GET /payment/api/v1/payments/transaction/user
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.planName,
    required this.amountDisplay,
    required this.transactionId,
    required this.statusDisplay,
    required this.endDate,
    this.couponCode = '',
    this.couponDiscountDisplay = '',
  });

  final String id;
  final String planName;
  final String amountDisplay;        // e.g. "₹ 117"
  final String transactionId;        // gudsho_receipt
  final String statusDisplay;        // e.g. "Success"
  final DateTime? endDate;
  final String couponCode;           // couponData.coupon_text
  final String couponDiscountDisplay; // e.g. "₹ 29"

  bool get hasCoupon => couponCode.isNotEmpty;

  /// Whole days remaining until expiry, comparing date-only (time ignored).
  /// Returns negative when expired.
  int get daysRemaining {
    if (endDate == null) return -1;
    final now = DateTime.now();
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final today  = DateTime(now.year, now.month, now.day);
    return endDay.difference(today).inDays;
  }

  /// "EXPIRE IN X DAYS", "EXPIRING TODAY", or "EXPIRED"
  String get expiryLabel {
    final d = daysRemaining;
    if (d < 0)  return 'EXPIRED';
    if (d == 0) return 'EXPIRING TODAY';
    if (d == 1) return 'EXPIRE IN 1 DAY';
    return 'EXPIRE IN $d DAYS';
  }

  bool get isExpired => daysRemaining < 0;

  // ── Factory ──────────────────────────────────────────────────────────────

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Null-safe string extractor
    String s(dynamic v) {
      if (v == null) return '';
      final str = v.toString().trim();
      return str == 'null' ? '' : str;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final sub = json['subscription'];
    final Map<String, dynamic> subMap =
        sub is Map<String, dynamic> ? sub : const {};

    // amount is in paise (×100); divide to get rupees
    final rawAmount = json['amount'];
    final String amountDisplay = () {
      if (rawAmount is! num) return '₹ 0';
      final rupees = rawAmount.toDouble() / 100;
      return rupees % 1 == 0 ? '₹ ${rupees.toInt()}' : '₹ ${rupees.toStringAsFixed(2)}';
    }();

    // status: 2 → "Success", anything else use raw value
    final status = json['status'];
    final statusDisplay =
        (status == 2 || status == '2') ? 'Success' : s(status);

    // couponData — optional; may be null or absent
    final couponRaw = json['couponData'];
    final Map<String, dynamic> couponMap =
        couponRaw is Map<String, dynamic> ? couponRaw : const {};

    final couponCode = s(couponMap['coupon_text']);

    final String couponDiscountDisplay = () {
      final raw = couponMap['coupon_discount_amount'];
      if (raw is! num) return '';
      final rupees = raw.toDouble() / 100;
      return rupees % 1 == 0 ? '₹ ${rupees.toInt()}' : '₹ ${rupees.toStringAsFixed(2)}';
    }();

    return TransactionModel(
      id:                     s(json['_id']),
      planName:               s(subMap['name'] ?? subMap['subscription_name']),
      amountDisplay:          amountDisplay,
      transactionId:          s(json['gudsho_receipt'] ?? json['order_id']),
      statusDisplay:          statusDisplay,
      endDate:                parseDate(subMap['end_date']),
      couponCode:             couponCode,
      couponDiscountDisplay:  couponDiscountDisplay,
    );
  }
}
