import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../services/api_service.dart';
import '../../data/models/profile_field_model.dart';
import '../../data/models/subscription_plan_model.dart';
import '../../data/models/user_profile_detail_model.dart';
import '../../data/remote/profile_api_service.dart';

enum ProfileLoadState { initial, loading, loaded, error }

enum SaveState { idle, saving, success, error }

/// Manages state for the Edit Profile screen.
///
/// The [buildFieldList] method returns the exact set of form rows to render,
/// driven by which fields the API returned. This makes the form fully dynamic:
/// student fields appear automatically when present; regular-user fields
/// (mobile, email) appear only for phone-number accounts.
class EditProfileViewModel extends ChangeNotifier {
  static const _tag = 'EditProfileViewModel';

  EditProfileViewModel({
    required ProfileApiService profileApi,
    required ApiService authApi,
  })  : _profileApi = profileApi,
        _authApi = authApi;

  final ProfileApiService _profileApi;
  final ApiService _authApi;

  // ── Load state ─────────────────────────────────────────────────────────────

  ProfileLoadState _loadState = ProfileLoadState.initial;
  String? _loadError;

  ProfileLoadState get loadState => _loadState;
  bool get isLoading => _loadState == ProfileLoadState.loading;
  bool get hasData => _loadState == ProfileLoadState.loaded;
  bool get hasError => _loadState == ProfileLoadState.error;
  String? get loadError => _loadError;

  // ── Profile data ───────────────────────────────────────────────────────────

  // Common
  String _firstName = '';
  String _lastName = '';
  String _username = '';
  String _dob = '';
  String _gender = '';
  String _profilePictureUrl = '';
  File? _pendingImage;

  // Regular-user (phone-number login)
  String _mobile = '';
  String _email = '';

  // Student-only (admission-number login)
  String _admissionNumber = '';
  String _schoolCode = '';
  String _branch = '';
  String _className = '';
  String _section = '';
  String _preparingFor = '';

  bool _isStudent = false;

  SubscriptionPlanModel? _plan;

  // ── Getters ────────────────────────────────────────────────────────────────

  String get firstName => _firstName;
  String get lastName => _lastName;
  String get username => _username;
  String get dobDisplay => _dob;
  String get gender => _gender;
  String get genderDisplay =>
      _gender == '1' ? 'Male' : _gender == '2' ? 'Female' : _gender;
  String get profilePictureUrl => _profilePictureUrl;
  File? get pendingImage => _pendingImage;
  bool get isStudent => _isStudent;
  SubscriptionPlanModel? get plan => _plan;

  String get fullName => '$_firstName $_lastName'.trim();

  String get avatarDisplayName {
    final n = fullName;
    final u = _username;
    if (n.isEmpty && u.isEmpty) return '';
    if (n.isEmpty) return u;
    if (u.isEmpty) return n;
    return '${n}_$u';
  }

  // ── Save state ─────────────────────────────────────────────────────────────

  SaveState _saveState = SaveState.idle;
  String? _saveError;

  SaveState get saveState => _saveState;
  bool get isSaving => _saveState == SaveState.saving;
  bool get saveSuccess => _saveState == SaveState.success;
  String? get saveError => _saveError;

  // ── Dynamic field value lookup ─────────────────────────────────────────────

  /// Returns the live string value for the given API field key.
  /// Used by the dynamic form builder to populate each row.
  String fieldValue(String key) {
    switch (key) {
      case 'first_name':
        return _firstName;
      case 'last_name':
        return _lastName;
      case 'username':
        return _username;
      case 'mobile':
        return _mobile;
      case 'email':
        return _email;
      case 'dob':
        return _dob;
      case 'gender':
        return genderDisplay;
      case 'admission_number':
        return _admissionNumber;
      case 'school_code':
        return _schoolCode;
      case 'branch':
        return _branch;
      case 'class_name':
        return _className;
      case 'section':
        return _section;
      case 'preparing_for':
        return _preparingFor;
      default:
        return '';
    }
  }

  // ── Dynamic field list ─────────────────────────────────────────────────────

  /// Returns the ordered list of field configurations to render in the form.
  ///
  /// A field is included only when it has a non-empty value from the API,
  /// so the form adapts automatically to student vs regular accounts.
  List<ProfileFieldConfig> buildFieldList() {
    final fields = <ProfileFieldConfig>[
      // Always shown — editable
      const ProfileFieldConfig(
        key: 'first_name',
        label: 'Your Name',
        type: ProfileFieldType.editableText,
      ),
    ];

    // Regular-user fields — present for phone-number login accounts
    if (_mobile.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'mobile',
        label: 'Mobile number',
        type: ProfileFieldType.readOnlyVerified,
      ));
    }
    if (_email.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'email',
        label: 'Email',
        type: ProfileFieldType.readOnlyVerified,
      ));
    }

    // Always shown — editable via pickers
    fields.add(const ProfileFieldConfig(
      key: 'dob',
      label: 'DOB (DD/MM/YYYY)',
      type: ProfileFieldType.datePicker,
    ));
    fields.add(const ProfileFieldConfig(
      key: 'gender',
      label: 'Gender',
      type: ProfileFieldType.genderPicker,
    ));

    // Student-only fields — present for admission-number login accounts
    if (_admissionNumber.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'admission_number',
        label: 'Admission Number',
        type: ProfileFieldType.readOnly,
      ));
    }
    if (_schoolCode.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'school_code',
        label: 'School Code',
        type: ProfileFieldType.readOnly,
      ));
    }
    if (_branch.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'branch',
        label: 'Branch',
        type: ProfileFieldType.readOnly,
      ));
    }
    if (_className.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'class_name',
        label: 'Class',
        type: ProfileFieldType.readOnly,
      ));
    }
    if (_section.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'section',
        label: 'Section',
        type: ProfileFieldType.readOnly,
      ));
    }
    if (_preparingFor.isNotEmpty) {
      fields.add(const ProfileFieldConfig(
        key: 'preparing_for',
        label: 'Preparing For',
        type: ProfileFieldType.readOnly,
      ));
    }

    return fields;
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  void setFirstName(String v) {
    _firstName = v.trim();
    notifyListeners();
  }

  void setGender(String code) {
    if (_gender == code) return;
    _gender = code;
    notifyListeners();
  }

  void setDob(DateTime date) {
    _dob = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    notifyListeners();
  }

  void setPendingImage(File image) {
    _pendingImage = image;
    notifyListeners();
  }

  void resetSaveState() {
    if (_saveState == SaveState.idle) return;
    _saveState = SaveState.idle;
    _saveError = null;
    notifyListeners();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loadState == ProfileLoadState.loading) return;

    _loadState = ProfileLoadState.loading;
    _loadError = null;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _loadState = ProfileLoadState.error;
        _loadError = 'Please log in to view your profile.';
        notifyListeners();
        return;
      }

      // Fetch profile + subscription in parallel.
      final results = await Future.wait([
        _profileApi.getProfile(token),
        _profileApi.getSubscription(token),
      ]);

      final profile = UserProfileDetailModel.fromJson(results[0]);
      _firstName = profile.firstName;
      _lastName = profile.lastName;
      _username = profile.username;
      _dob = profile.dobDisplay;
      _gender = profile.gender;
      _profilePictureUrl = profile.profilePictureUrl;
      _mobile = profile.mobile;
      _email = profile.email;
      _admissionNumber = profile.admissionNumber;
      _schoolCode = profile.schoolCode;
      _branch = profile.branch;
      _className = profile.className;
      _section = profile.section;
      _preparingFor = profile.preparingFor;
      _isStudent = profile.isStudent;

      final subJson = results[1];
      _plan = subJson.isNotEmpty
          ? SubscriptionPlanModel.fromJson(subJson)
          : null;

      _loadState = ProfileLoadState.loaded;
      AppLogger.info(
        _tag,
        'Loaded — name="$fullName" isStudent=$_isStudent plan="${_plan?.planName}"',
      );
    } catch (e, st) {
      _loadState = ProfileLoadState.error;
      _loadError = 'Could not load profile. Please try again.';
      AppLogger.error(_tag, 'load error', e, st);
    } finally {
      notifyListeners();
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Returns `true` on success. On failure, [saveError] holds the message.
  Future<bool> save() async {
    if (_saveState == SaveState.saving) return false;

    _saveState = SaveState.saving;
    _saveError = null;
    notifyListeners();

    try {
      final token = await _authApi.getToken() ?? '';
      if (token.isEmpty) {
        _fail('Please log in to save your profile.');
        return false;
      }

      final res = await _profileApi.updateProfile(
        token: token,
        firstName: _firstName,
        lastName: _lastName,
        dob: _dob,
        gender: _gender,
        profilePicture: _pendingImage,
      );

      final ok = res['status'] == 'success' ||
          res['statusCode'] == 200 ||
          res['statusCode'] == '200';

      if (ok) {
        _pendingImage = null;
        _saveState = SaveState.success;
        AppLogger.info(_tag, 'Profile saved successfully');
        notifyListeners();
        return true;
      }

      _fail(res['message']?.toString() ?? 'Save failed. Please try again.');
      return false;
    } catch (e, st) {
      _fail('Could not save profile. Please try again.');
      AppLogger.error(_tag, 'save error', e, st);
      return false;
    }
  }

  void _fail(String msg) {
    _saveState = SaveState.error;
    _saveError = msg;
    notifyListeners();
  }
}
