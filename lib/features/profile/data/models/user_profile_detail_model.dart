/// Full user profile returned by GET /mediaview/api/v1/profile.
///
/// All optional fields default to empty string when absent from the API
/// response. Field presence drives the dynamic form in EditProfileScreen:
///   • mobile / email    → shown for regular users (phone-number login)
///   • admissionNumber … → shown for student users (admission-number login)
class UserProfileDetailModel {
  const UserProfileDetailModel({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.dob,
    required this.gender,
    required this.profilePictureUrl,
    this.mobile = '',
    this.email = '',
    this.admissionNumber = '',
    this.schoolCode = '',
    this.branch = '',
    this.className = '',
    this.section = '',
    this.preparingFor = '',
  });

  // ── Common fields ───────────────────────────────────────────────────────────
  final String firstName;
  final String lastName;
  final String username;
  final String dob;
  final String gender;
  final String profilePictureUrl;

  // ── Regular-user fields (phone-number login) ────────────────────────────────
  final String mobile;
  final String email;

  // ── Student-only fields (admission-number login) ────────────────────────────
  final String admissionNumber;
  final String schoolCode;
  final String branch;
  final String className;
  final String section;
  final String preparingFor;

  // ── Derived ────────────────────────────────────────────────────────────────

  String get fullName => '$firstName $lastName'.trim();

  /// Students log in via admission number; regular users via phone number.
  bool get isStudent => admissionNumber.isNotEmpty || schoolCode.isNotEmpty;

  String get genderDisplay {
    if (gender == '1') return 'Male';
    if (gender == '2') return 'Female';
    return gender;
  }

  /// Normalises DOB to DD/MM/YYYY for display, accepting either format.
  String get dobDisplay {
    if (dob.isEmpty) return '';
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dob)) return dob;
    final parts = dob.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dob;
  }

  // ── Factory ────────────────────────────────────────────────────────────────

  factory UserProfileDetailModel.fromJson(Map<String, dynamic> json) {
    final response = json['response'];
    final Map<String, dynamic> data =
        response is Map<String, dynamic> ? response : const {};

    String s(String key) => data[key]?.toString().trim() ?? '';

    // Mobile may come as 'mobile' or 'phone_number'.
    final mobile = s('mobile').isNotEmpty ? s('mobile') : s('phone_number');
    // Class may come as 'class_name' or 'class'.
    final className =
        s('class_name').isNotEmpty ? s('class_name') : s('class');

    return UserProfileDetailModel(
      firstName: s('first_name'),
      lastName: s('last_name'),
      username: s('username'),
      dob: s('dob'),
      gender: s('gender'),
      profilePictureUrl: s('profile_picture'),
      mobile: mobile,
      email: s('email'),
      admissionNumber: s('admission_number'),
      schoolCode: s('school_code'),
      branch: s('branch'),
      className: className,
      section: s('section'),
      preparingFor: s('preparing_for'),
    );
  }

  static UserProfileDetailModel empty() => const UserProfileDetailModel(
        firstName: '',
        lastName: '',
        username: '',
        dob: '',
        gender: '',
        profilePictureUrl: '',
      );
}
