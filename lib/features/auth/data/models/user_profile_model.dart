/// Subscription + profile data from GET /mediaview/api/v1/profile.
class UserProfileModel {
  const UserProfileModel({
    required this.isSubscribed,
    required this.profileCount,
    required this.profileMaxLimit,
    this.name = '',
  });

  /// true when is_subscription_plans == 1 AND subscription_info is non-empty.
  final bool isSubscribed;

  /// Number of profiles attached to this account.
  final int profileCount;

  /// Maximum profiles allowed (from /muti-profile/list).
  final int profileMaxLimit;

  /// Display name from the profile API. Empty when the field is absent.
  final String name;

  bool get isDeviceRestricted => profileCount > profileMaxLimit;

  factory UserProfileModel.fromProfileJson(
    Map<String, dynamic> json, {
    int profileCount = 0,
    int profileMaxLimit = 2,
  }) {
    final response = json['response'];
    final Map<String, dynamic> data =
        response is Map<String, dynamic> ? response : const {};

    final isSubPlan = data['is_subscription_plans'];
    final subInfo = data['subscription_info'];

    final bool subscribed =
        (isSubPlan == 1 || isSubPlan == '1' || isSubPlan == true) &&
        (subInfo is List ? subInfo.isNotEmpty : subInfo != null && subInfo.toString().isNotEmpty);

    // Try common API field names for user display name.
    final rawName = (data['name']
            ?? data['full_name']
            ?? data['first_name']
            ?? data['username']
            ?? '')
        .toString()
        .trim();

    return UserProfileModel(
      isSubscribed: subscribed,
      profileCount: profileCount,
      profileMaxLimit: profileMaxLimit,
      name: rawName,
    );
  }
}
