class DeviceInfoModel {
  const DeviceInfoModel({
    required this.id,
    required this.displayName,
    required this.deviceType,
    this.lastLoginAt,
  });

  final String id;          // session _id used for per-device logout API
  final String displayName; // "iPhone -", "Android -", etc.
  final String deviceType;  // 'ios' | 'android' | 'web'
  final DateTime? lastLoginAt;

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['device_type']?.toString() ?? '';
    final rawName = (json['device_name'] ?? json['deviceName'] ?? json['name'] ?? '').toString();

    String display;
    if (rawName.isNotEmpty) {
      display = rawName;
    } else if (rawType.isNotEmpty) {
      display = '${rawType[0].toUpperCase()}${rawType.substring(1)} -';
    } else {
      display = 'Unknown Device -';
    }

    final rawDate = (json['updatedAt'] ?? json['last_login'] ?? json['lastLogin'] ??
            json['created_at'] ?? json['createdAt'])
        ?.toString();

    return DeviceInfoModel(
      id: (json['_id'] ?? json['id'] ?? json['device_id'] ?? '').toString(),
      displayName: display,
      deviceType: rawType,
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
