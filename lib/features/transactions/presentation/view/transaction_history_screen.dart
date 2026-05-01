import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../../data/models/transaction_model.dart';
import '../../data/remote/transaction_api_service.dart';
import '../viewmodel/transaction_history_viewmodel.dart';

// ── Brand constants ───────────────────────────────────────────────────────────

const _kGreen       = Color(0xFF2ECC71);
const _kGreenBg     = Color(0xFFE8F8EE);
const _kDark        = Color(0xFF1A1A1A);
const _kGray        = Color(0xFF9E9E9E);
const _kDivider     = Color(0xFFF0F0F0);
const _kCouponBg    = Color(0xFFFFFBEB);
const _kCouponBorder= Color(0xFFFFE082);

// ─────────────────────────────────────────────────────────────────────────────

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  static Route<void> route(BuildContext outerContext) =>
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => TransactionHistoryViewModel(
            transactionApi: TransactionApiService(),
            authApi: outerContext.read<ApiService>(),
          )..load(),
          child: const TransactionHistoryScreen(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: const _TransactionBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 1),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _kDark,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: _kDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.5, color: _kDivider),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _TransactionBody extends StatefulWidget {
  const _TransactionBody();

  @override
  State<_TransactionBody> createState() => _TransactionBodyState();
}

class _TransactionBodyState extends State<_TransactionBody> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<TransactionHistoryViewModel>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionHistoryViewModel>(
      builder: (context, vm, _) {
        // ── Loading ──────────────────────────────────────────────────────────
        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _kGreen),
          );
        }

        // ── Error ────────────────────────────────────────────────────────────
        if (vm.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: _kGray),
                  const SizedBox(height: 12),
                  Text(
                    vm.error ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: _kGray),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: vm.load,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: _kGreen),
                    label: const Text('Retry',
                        style: TextStyle(color: _kGreen)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kGreen),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ── Empty ─────────────────────────────────────────────────────────
        if (vm.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: _kGray),
                SizedBox(height: 12),
                Text(
                  'No transactions found',
                  style: TextStyle(
                    fontSize: 15,
                    color: _kGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // ── List ──────────────────────────────────────────────────────────
        return ListView.builder(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          itemCount: vm.transactions.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == vm.transactions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: _kGreen, strokeWidth: 2.5),
                  ),
                ),
              );
            }
            return _TransactionCard(tx: vm.transactions[index]);
          },
        );
      },
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: success icon ──────────────────────────────────────
              _SuccessIcon(isExpired: tx.isExpired),

              const SizedBox(width: 14),

              // ── Right: all text content ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Row 1: Plan name  ·  Amount ─────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            tx.planName.isNotEmpty
                                ? tx.planName
                                : 'Subscription',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tx.amountDisplay,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // ── Row 2: Type ──────────────────────────────────────
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Type:  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: 'Subscription',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 3),

                    // ── Row 3: Transaction ID (label + value same line) ──
                    if (tx.transactionId.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction ID:  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              tx.transactionId,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kGray,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 6),

                    // ── Row 4: Expiry (left)  ·  Status (right) ─────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ExpiryLabel(
                          label: tx.expiryLabel,
                          expired: tx.isExpired,
                        ),
                        const Spacer(),
                        if (tx.statusDisplay.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Status:  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _kGray,
                                ),
                              ),
                              Text(
                                tx.statusDisplay,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kGreen,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Coupon section (conditional) ───────────────────────────────
        if (tx.hasCoupon)
          _CouponSection(
            couponCode:      tx.couponCode,
            discountDisplay: tx.couponDiscountDisplay,
          ),

        const Divider(height: 1, thickness: 0.5, color: _kDivider),
      ],
    );
  }
}

// ── Coupon section ────────────────────────────────────────────────────────────

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.couponCode,
    required this.discountDisplay,
  });

  final String couponCode;
  final String discountDisplay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kCouponBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kCouponBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Applied coupon code ───────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APPLIED COUPON CODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _kGray,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        couponCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const VerticalDivider(
                  width: 1, thickness: 0.5, color: _kCouponBorder),

              // ── Coupon discount amount ────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COUPON DISCOUNT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _kGray,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discountDisplay,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Success icon widget ───────────────────────────────────────────────────────

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon({required this.isExpired});
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final color = isExpired ? _kGray : _kGreen;
    final bg    = isExpired ? const Color(0xFFF5F5F5) : _kGreenBg;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: color, size: 36),
          Positioned(
            top: -4,
            right: -4,
            child: Icon(Icons.auto_awesome, color: color, size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Expiry label widget ───────────────────────────────────────────────────────

class _ExpiryLabel extends StatelessWidget {
  const _ExpiryLabel({required this.label, required this.expired});
  final String label;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    if (expired) {
      return Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kGray,
          letterSpacing: 0.4,
        ),
      );
    }

    // "EXPIRE IN" in lighter green, "X DAYS" in bold green
    final parts = label.split(RegExp(r'(?<=IN )|(?=\d)'));
    final prefix = parts.length > 1 ? parts.first : label;
    final rest   = parts.length > 1 ? parts.skip(1).join() : '';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kGreen,
              letterSpacing: 0.4,
            ),
          ),
          if (rest.isNotEmpty)
            TextSpan(
              text: rest,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kGreen,
                letterSpacing: 0.4,
              ),
            ),
        ],
      ),
    );
  }
}
