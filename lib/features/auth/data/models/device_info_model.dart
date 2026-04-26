class DeviceInfoModel {
  const DeviceInfoModel({
    required this.id,
    required this.displayName,
    required this.deviceType,
    required this.accessToken,
    this.lastLoginAt,
  });

  final String id;           // session _id used for per-device logout API
  final String displayName;  // human-readable device label shown in popup
  final String deviceType;   // normalised: 'ios' | 'android' | 'web' | ''
  final String accessToken;  // device's own JWT — used by phone-login logout API
  final DateTime? lastLoginAt;

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    // Server returns 'login_type' ("Web", "Mobile", "iOS", "Android" …).
    // Prefer it over the rarely-present 'device_type' field.
    final rawType =
        (json['login_type'] ?? json['device_type'] ?? '').toString().toLowerCase();

    final rawName =
        (json['device_name'] ?? json['deviceName'] ?? json['name'] ?? '')
            .toString()
            .trim();
    final rawBrowser = (json['browser_name'] ?? '').toString().trim();

    // Build a human-readable label: "Nothing FroggerPro", "Chrome", etc.
    String display;
    if (rawName.isNotEmpty) {
      display = rawBrowser.isNotEmpty ? '$rawName ($rawBrowser)' : rawName;
    } else if (rawBrowser.isNotEmpty) {
      display = rawBrowser;
    } else if (rawType.isNotEmpty) {
      display = '${rawType[0].toUpperCase()}${rawType.substring(1)} Device';
    } else {
      display = 'Unknown Device';
    }

    // Prefer updated_at > created_at for last-activity display.
    final rawDate =
        (json['updated_at'] ?? json['updatedAt'] ?? json['last_login'] ??
                json['lastLogin'] ?? json['created_at'] ?? json['createdAt'])
            ?.toString();

    return DeviceInfoModel(
      id: (json['_id'] ?? json['id'] ?? json['device_id'] ?? '').toString(),
      displayName: display,
      deviceType: rawType, // 'web' | 'android' | 'ios' | 'mobile' | ''
      accessToken: (json['access_token'] ?? '').toString(),
      lastLoginAt: rawDate != null ? DateTime.tryParse(rawDate) : null,
    );
  }

  /// "23 Apr 2026 12:27 PM (IST)"
  String get formattedLastLogin {
    if (lastLoginAt == null) return 'Unknown';
    // Convert UTC → IST (UTC +5:30)
    final ist = lastLoginAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h   = ist.hour == 0 ? 12 : (ist.hour > 12 ? ist.hour - 12 : ist.hour);
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    final min  = ist.minute.toString().padLeft(2, '0');
    return '${ist.day} ${months[ist.month - 1]} ${ist.year} $h:$min $ampm (IST)';
  }
}
