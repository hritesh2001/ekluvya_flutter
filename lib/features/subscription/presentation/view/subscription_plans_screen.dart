import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/app_toast.dart';
import '../../data/models/subscription_plan_item_model.dart';
import '../viewmodel/subscription_viewmodel.dart';
import 'subscription_redirect_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────

const _kPink       = Color(0xFFE91E63);
const _kOrange     = Color(0xFFFF5722);
const _kGold       = Color(0xFFFFD700);
const _kGreen      = Color(0xFF22C55E);
const _kGreenBorder = Color(0xFF22C55E);
const _kGreyBorder = Color(0xFFE5E5E5);
const _kText       = Color(0xFF0D0D0D);
const _kSubText    = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────

/// Subscription plans screen — pixel-matched to the provided design.
///
/// Shows API-driven plan cards, a "Most Recommended" badge on the first card,
/// and a sticky gradient CTA that reflects the selected plan's GST-inclusive price.
///
/// Entry point: [SubscriptionPlansScreen.route].
class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  static Route<void> route(BuildContext outerContext) =>
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => ChangeNotifierProvider(
          create: (_) => SubscriptionViewModel(
            authApi: outerContext.read<ApiService>(),
          )..load(),
          child: const SubscriptionPlansScreen(),
        ),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      );

  @override
  Widget build(BuildContext context) => const _PlansView();
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _PlansView extends StatelessWidget {
  const _PlansView();

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            _Header(topPad: topPad),

            // ── Subtitle (always visible, not part of scroll) ──────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _Subtitle(),
            ),

            // ── Dashed divider — below subtitle ────────────────────────
            const _DashedDivider(),

            // ── Scrollable body ────────────────────────────────────────
            Expanded(
              child: Consumer<SubscriptionViewModel>(
                builder: (context, vm, _) => _buildBody(context, vm),
              ),
            ),

            // ── Sticky CTA ─────────────────────────────────────────────
            Consumer<SubscriptionViewModel>(
              builder: (context, vm, _) =>
                  _StickyButton(vm: vm, bottomPad: bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionViewModel vm) {
    if (vm.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPink));
    }

    if (vm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: _kPink),
              const SizedBox(height: 12),
              Text(
                vm.error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: _kSubText),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: vm.load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: _kPink),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.hasData && vm.plans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No subscription plans available.\nPlease check back soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _kSubText, height: 1.6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan cards
          ...List.generate(vm.plans.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PlanCard(
                plan: vm.plans[i],
                isSelected: vm.selectedIndex == i,
                onTap: () => vm.selectPlan(i),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPad + 4, 4, 8),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: _kText),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Title with gold crown asset
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/subscription_crown_gold.png',
                  width: 22,
                  height: 22,
                  color: _kGold,
                ),
                const SizedBox(width: 8),
                const Text(
                  'One Subscription',
                  style: TextStyle(
                    color: _kGold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // Logout icon
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22, color: _kPink),
            onPressed: () => _showLogoutSheet(context),
          ),
        ],
      ),
    );
  }

  static Future<void> _showLogoutSheet(BuildContext context) async {
    final sessionVM = context.read<SessionViewModel>();
    final nav = Navigator.of(context);

    final confirmed = await ConfirmLogoutSheet.show(context);
    if (confirmed != true || !context.mounted) return;

    sessionVM.logout();
    AppToast.show(context, message: 'You have successfully logged out');
    nav.popUntil((r) => r.settings.name == '/home' || r.isFirst);
  }
}

// ── Dashed divider ────────────────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Subtitle ──────────────────────────────────────────────────────────────────

class _Subtitle extends StatelessWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          Text(
            'For the first time in India',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: _kSubText, height: 1.6),
          ),
          Text(
            'All Classes. All Topics. Many Teachers',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: _kSubText, height: 1.6),
          ),
          Text(
            'In just one subscription',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: _kSubText, height: 1.6),
          ),
        ],
      );
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionPlanItem plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card body
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFF6FFF9)
                  : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _kGreenBorder : _kGreyBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.planName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _kText : const Color(0xFF374151),
                  ),
                ),
                if (plan.hasDiscount) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.originalPriceDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kSubText,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _kSubText,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  plan.priceDisplay,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                if (plan.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    plan.description,
                    style: const TextStyle(
                        fontSize: 13,
                        color: _kSubText,
                        height: 1.5),
                  ),
                ],
              ],
            ),
          ),

          // Check badge — bottom-right corner overlay
          Positioned(
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(12),
              ),
              child: _CheckBadge(selected: isSelected),
            ),
          ),

          // "Most Recommended" badge — overlaps top border
          if (plan.isRecommended)
            Positioned(
              top: -12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Most Recommended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Checkmark badge ───────────────────────────────────────────────────────────

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: const Size(52, 52),
              painter: _TrianglePainter(
                  color: selected ? _kGreen : const Color(0xFFD1D5DB)),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Icon(
              Icons.check_rounded,
              size: 16,
              color: selected ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ── Sticky CTA button ─────────────────────────────────────────────────────────

class _StickyButton extends StatelessWidget {
  const _StickyButton({required this.vm, required this.bottomPad});
  final SubscriptionViewModel vm;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final canPay = vm.hasData && vm.plans.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 12),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: canPay
                ? const LinearGradient(
                    colors: [_kPink, _kOrange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: canPay ? null : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: canPay ? () => _onPay(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              vm.ctaText,
              style: TextStyle(
                color: canPay ? Colors.white : const Color(0xFF9CA3AF),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPay(BuildContext context) {
    // selectedPlan.id is available here for future payment-URL API integration.
    Navigator.of(context).push(SubscriptionRedirectScreen.route());
  }
}

// ── Logout confirmation bottom sheet ─────────────────────────────────────────
//
// Re-exported here so both the drawer and the plans screen header can use it
// from a single import.

class ConfirmLogoutSheet {
  ConfirmLogoutSheet._();

  /// Shows the confirmation sheet and returns `true` if the user confirmed.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _LogoutSheetBody(),
    );
  }
}

class _LogoutSheetBody extends StatelessWidget {
  const _LogoutSheetBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question
            const Text(
              'Are you sure you want to\nend the session?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D0D0D),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        backgroundColor: const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Yes, Logout
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPink, _kOrange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
