import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../../features/subscription/presentation/view/subscription_plans_screen.dart';

/// Tab indices that require an active subscription.
const _kPremiumTabs = {1, 2, 3}; // Search, Explore, Bookmark

/// Central access guard for bottom-nav tab switches.
///
/// Call [FeatureGuard.checkTabAccess] before switching to a new tab index.
/// Returns `true` if navigation should proceed (tab is free, or user is
/// subscribed).  Returns `false` and redirects:
///   • not logged in   → /login
///   • logged in, no sub → SubscriptionPlansScreen
class FeatureGuard {
  const FeatureGuard._();

  static bool checkTabAccess(BuildContext context, int tabIndex) {
    if (!_kPremiumTabs.contains(tabIndex)) return true;

    final sessionVM = context.read<SessionViewModel>();

    if (!sessionVM.isLoggedIn) {
      Navigator.of(context).pushNamed('/login');
      return false;
    }

    if (sessionVM.isSubscribed) return true;

    Navigator.of(context).push(SubscriptionPlansScreen.route(context));
    return false;
  }
}
