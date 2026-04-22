import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../data/models/subscription_plan_item_model.dart';
import '../../data/remote/subscription_api_service.dart';

enum PlansLoadState { initial, loading, loaded, error }

/// Drives the SubscriptionPlansScreen.
/// Created and started via [SubscriptionPlansScreen.route].
class SubscriptionViewModel extends ChangeNotifier {
  static const _tag = 'SubscriptionViewModel';

  SubscriptionViewModel({
    required ApiService authApi,
    SubscriptionApiService? subscriptionApi,
  })  : _authApi = authApi,
        _subscriptionApi = subscriptionApi ?? SubscriptionApiService();

  final ApiService _authApi;
  final SubscriptionApiService _subscriptionApi;

  PlansLoadState _state = PlansLoadState.initial;
  List<SubscriptionPlanItem> _plans = [];
  int _selectedIndex = 0;
  String? _error;

  PlansLoadState get state => _state;
  bool get isLoading => _state == PlansLoadState.loading;
  bool get hasData => _state == PlansLoadState.loaded;
  bool get hasError => _state == PlansLoadState.error;
  List<SubscriptionPlanItem> get plans => _plans;
  int get selectedIndex => _selectedIndex;
  String? get error => _error;

  SubscriptionPlanItem? get selectedPlan =>
      _plans.isNotEmpty && _selectedIndex < _plans.length
          ? _plans[_selectedIndex]
          : null;

  /// CTA button label — includes selected plan's price + 18% GST.
  String get ctaText {
    final plan = selectedPlan;
    if (plan == null || plan.price <= 0) return 'Subscribe Now';
    return 'Pay ${plan.ctaPriceDisplay} to Subscribe';
  }

  void selectPlan(int index) {
    if (index < 0 || index >= _plans.length || index == _selectedIndex) return;
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> load() async {
    if (_state == PlansLoadState.loading) return;
    _state = PlansLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _state = PlansLoadState.error;
        _error = 'Please log in to view subscription plans.';
        notifyListeners();
        return;
      }

      _plans = await _subscriptionApi.getPlans(token);
      _selectedIndex = 0;
      _state = PlansLoadState.loaded;
      AppLogger.info(_tag, 'Loaded ${_plans.length} plans');
    } catch (e, st) {
      _state = PlansLoadState.error;
      _error = 'Could not load plans. Please try again.';
      AppLogger.error(_tag, 'load error', e, st);
    } finally {
      notifyListeners();
    }
  }
}
