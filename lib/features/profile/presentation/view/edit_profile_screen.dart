import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/app_toast.dart';
import '../../data/models/profile_field_model.dart';
import '../../data/models/subscription_plan_model.dart';
import '../../data/remote/profile_api_service.dart';
import '../viewmodel/edit_profile_viewmodel.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────

const _kPink       = Color(0xFFE91E63);
const _kOrange     = Color(0xFFFF5722);
const _kGreen      = Color(0xFF2ECC71);
const _kFieldLabel = Color(0xFF9E9E9E);
const _kFieldText  = Color(0xFF1A1A1A);

// ── Layout constants ──────────────────────────────────────────────────────────

const double _kAvatarRadius = 52.0;

// ── Shared underline decoration ───────────────────────────────────────────────

InputDecoration _underlineDecoration() => const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 10),
      enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFDDDDDD))),
      focusedBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: _kPink)),
      errorBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
      focusedErrorBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
    );

// ─────────────────────────────────────────────────────────────────────────────

/// Edit Profile screen — fully dynamic based on user type.
///
/// Student accounts (admission-number login) show academic read-only fields.
/// Regular accounts (phone-number login) show mobile + email verified fields.
/// Fields absent from the API response are silently omitted.
///
/// Entry point: [EditProfileScreen.route] — scopes the ViewModel to this
/// screen and triggers [EditProfileViewModel.load] automatically.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  static Route<void> route(BuildContext outerContext) =>
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => EditProfileViewModel(
            profileApi: ProfileApiService(),
            authApi: outerContext.read<ApiService>(),
          )..load(),
          child: const EditProfileScreen(),
        ),
      );

  @override
  Widget build(BuildContext context) => const _EditProfileView();
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  // Pre-initialized once — avoids re-instantiation cost on every tap
  final _picker   = ImagePicker();
  late EditProfileViewModel _vm;
  bool _controllerBound = false;
  bool _isPickingImage   = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerBound) {
      _vm = context.read<EditProfileViewModel>();
      _controllerBound = true;
      if (_vm.hasData) {
        _nameCtrl.text = _vm.firstName;
      } else {
        _vm.addListener(_onVmLoaded);
      }
    }
  }

  void _onVmLoaded() {
    if (_vm.hasData && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = _vm.firstName;
    }
    if (_vm.hasData || _vm.hasError) {
      _vm.removeListener(_onVmLoaded);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vm.removeListener(_onVmLoaded);
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null || !mounted) return;
      _vm.setPendingImage(File(picked.path));
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _pickDate() async {
    DateTime? initial;
    final dob = _vm.dobDisplay;
    if (dob.isNotEmpty) {
      final parts = dob.split('/');
      if (parts.length == 3) {
        try {
          initial = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } catch (_) {}
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _kPink),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _kPink)),
        ),
        child: child!,
      ),
    );
    if (picked != null) _vm.setDob(picked);
  }

  void _editGender() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String selected = _vm.gender;
          return AlertDialog(
            title: const Text('Select Gender'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GenderRadioTile(
                  label: 'Male',
                  value: '1',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v),
                ),
                _GenderRadioTile(
                  label: 'Female',
                  value: '2',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPink),
                onPressed: () {
                  Navigator.pop(ctx);
                  _vm.setGender(selected);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _vm.setFirstName(_nameCtrl.text);

    final ok = await _vm.save();
    if (!mounted) return;

    if (ok) {
      final sessionVM = context.read<SessionViewModel>();
      sessionVM.updateUserName('${_vm.firstName} ${_vm.lastName}'.trim());
      if (_vm.profilePictureUrl.isNotEmpty) {
        sessionVM.updateProfilePicture(_vm.profilePictureUrl);
      }
      AppToast.show(context, message: 'Profile updated successfully');
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_vm.saveError ?? 'Save failed. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Consumer<EditProfileViewModel>(
          builder: (context, vm, _) => Column(
            children: [
              // ── Header + avatar overlay ──────────────────────────────────
              // Flutter's Stack hit-test area equals its layout bounds, NOT
              // its paint-overflow area.  To make the full avatar circle
              // tappable we must bring the avatar inside the Stack's layout
              // bounds by giving the Stack a height of
              //   gradientHeight + _kAvatarRadius
              // via a transparent SizedBox spacer child.  The avatar is then
              // Positioned(bottom: 0), so its center sits exactly at the
              // gradient's bottom edge — visually identical to before.
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Non-positioned column gives the Stack its layout height:
                  //   gradient height + _kAvatarRadius (lower half of avatar)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGradientBar(context, topPad),
                      const SizedBox(height: _kAvatarRadius),
                    ],
                  ),
                  // Avatar sits at bottom: 0 of the extended Stack, so its
                  // center is exactly at the gradient's bottom edge.
                  Positioned(
                    bottom: 0,
                    child: _buildAvatarCircle(vm),
                  ),
                ],
              ),

              // 12 px gap between avatar bottom and the body content.
              const SizedBox(height: 12),

              // ── Main scrollable / fixed content ─────────────────────────
              Expanded(child: _buildBody(context, vm, bottomPad)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gradient bar (no avatar) ────────────────────────────────────────────────

  Widget _buildGradientBar(BuildContext context, double topPad) {
    return Container(
      width: double.infinity,
      height: topPad + kToolbarHeight + 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPink, _kOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad),
          SizedBox(
            height: kToolbarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Edit Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar circle widget (reused by both regular + B2B flows) ──────────────

  Widget _buildAvatarCircle(EditProfileViewModel vm) {
    return GestureDetector(
      onTap: _pickImage,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _kAvatarRadius * 2,
            height: _kAvatarRadius * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE0E0E0),
              boxShadow: [
                BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: ClipOval(child: _AvatarImage(vm: vm)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: _kPink),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, EditProfileViewModel vm, double bottomPad) {
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
                vm.loadError ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
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

    final isB2b = context.read<SessionViewModel>().isB2b || vm.isB2b;
    if (isB2b) return _buildBodyB2b(context, vm, bottomPad);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name displayed below avatar (spacing handled by outer Column).
            _buildAvatarName(vm),

            const SizedBox(height: 20),

            // Subscription card — shown whenever the session confirms the user
            // is subscribed, with a fallback if the plan API returned no data.
            if (context.watch<SessionViewModel>().isSubscribed) ...[
              _SubscriptionCard(
                plan: vm.plan ??
                    const SubscriptionPlanModel(
                      planName: 'Active Subscription',
                      expiryText: '',
                      priceDisplay: '',
                      isActive: true,
                    ),
              ),
              const SizedBox(height: 28),
            ],

            // Dynamic form rows — driven by API response fields.
            ..._buildDynamicFields(vm),

            const SizedBox(height: 36),

            _buildSaveButton(vm),

            const SizedBox(height: 14),

            _buildDeleteButton(context),
          ],
        ),
      ),
    );
  }

  // ── B2B body (read-only, no save/delete) ───────────────────────────────────

  Widget _buildBodyB2b(
      BuildContext context, EditProfileViewModel vm, double bottomPad) {
    final sessionVM = context.watch<SessionViewModel>();
    final isSubscribed = sessionVM.isSubscribed;
    final plan = vm.plan ??
        const SubscriptionPlanModel(
          planName: 'Active Subscription',
          expiryText: '',
          priceDisplay: '',
          isActive: true,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fixed white header — never scrolls ────────────────────────────
        // White background blocks any scroll content from bleeding through
        // the avatar area.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name below avatar (spacing handled by outer Column).
              _buildAvatarName(vm),

              const SizedBox(height: 20),

              // Current Plan — only when subscribed.
              if (isSubscribed) ...[
                _SubscriptionCard(plan: plan),
                const SizedBox(height: 16),
              ],

              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),

        // ── Scrollable fields ─────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 24),
            children: _buildB2bFields(vm, sessionVM),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildB2bFields(
      EditProfileViewModel vm, SessionViewModel sessionVM) {
    // Resolves a field value: vm first, then session fallback, then '-'.
    String resolve(String key) {
      final v = vm.fieldValue(key);
      if (v.isNotEmpty) return v;
      switch (key) {
        case 'class_name':     return sessionVM.className.isNotEmpty     ? sessionVM.className     : '-';
        case 'school_name':    return sessionVM.schoolName.isNotEmpty    ? sessionVM.schoolName    : '-';
        case 'school_address': return sessionVM.schoolAddress.isNotEmpty ? sessionVM.schoolAddress : '-';
        default:               return '-';
      }
    }

    return vm.buildFieldListB2b().map((field) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(field.label),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: _underlineDecoration(),
              child: Text(
                resolve(field.key),
                style: const TextStyle(
                    color: _kFieldLabel,
                    fontSize: 15,
                    fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Avatar name ────────────────────────────────────────────────────────────

  Widget _buildAvatarName(EditProfileViewModel vm) {
    final name = vm.avatarDisplayName;
    if (name.isEmpty) return const SizedBox.shrink();
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _kFieldText,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Dynamic fields ─────────────────────────────────────────────────────────

  List<Widget> _buildDynamicFields(EditProfileViewModel vm) =>
      vm.buildFieldList().map((field) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(field.label),
              const SizedBox(height: 6),
              _buildFieldInput(field, vm),
            ],
          ),
        );
      }).toList();

  Widget _buildFieldInput(ProfileFieldConfig field, EditProfileViewModel vm) {
    switch (field.type) {
      case ProfileFieldType.editableText:
        return TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
              color: _kFieldText, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: _underlineDecoration(),
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? 'Name cannot be empty' : null,
        );

      case ProfileFieldType.readOnly:
        return InputDecorator(
          decoration: _underlineDecoration(),
          child: Text(
            vm.fieldValue(field.key),
            style: const TextStyle(
                color: _kFieldLabel, fontSize: 15, fontWeight: FontWeight.w400),
          ),
        );

      case ProfileFieldType.readOnlyVerified:
        return InputDecorator(
          decoration: _underlineDecoration().copyWith(
            suffixIcon: const Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 20),
          ),
          child: Text(
            vm.fieldValue(field.key),
            style: const TextStyle(
                color: _kFieldText, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        );

      case ProfileFieldType.datePicker:
        return InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: _underlineDecoration().copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined,
                  color: _kFieldLabel, size: 20),
            ),
            child: Text(
              vm.dobDisplay.isEmpty ? 'Select date of birth' : vm.dobDisplay,
              style: TextStyle(
                color: vm.dobDisplay.isEmpty ? _kFieldLabel : _kFieldText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );

      case ProfileFieldType.genderPicker:
        return InputDecorator(
          decoration: _underlineDecoration().copyWith(
            suffixIcon: TextButton(
              onPressed: _editGender,
              style: TextButton.styleFrom(
                foregroundColor: _kPink,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('EDIT',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          child: Text(
            vm.genderDisplay.isEmpty ? 'Not set' : vm.genderDisplay,
            style: TextStyle(
              color: vm.genderDisplay.isEmpty ? _kFieldLabel : _kFieldText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _buildSaveButton(EditProfileViewModel vm) => SizedBox(
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: vm.isSaving
                ? null
                : const LinearGradient(
                    colors: [_kPink, _kOrange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: vm.isSaving ? Colors.grey[300] : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ElevatedButton(
            onPressed: vm.isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: vm.isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: _kPink, strokeWidth: 2.5),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      );

  Widget _buildDeleteButton(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'Account deletion coming soon. Contact support.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: const Text(
            'Delete Account',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ),
      );
}

// ── Avatar image with fallback ────────────────────────────────────────────────

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.vm});
  final EditProfileViewModel vm;

  @override
  Widget build(BuildContext context) {
    final pending = vm.pendingImage;
    if (pending != null) {
      return Image.file(pending,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity);
    }

    final url = vm.profilePictureUrl;
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => _DefaultAvatar(initials: _initials()),
        errorWidget: (_, _, _) => _DefaultAvatar(initials: _initials()),
      );
    }

    return _DefaultAvatar(initials: _initials());
  }

  String _initials() {
    final n = vm.fullName.trim();
    if (n.isEmpty) return '';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (initials.isEmpty) {
      return const Icon(Icons.person_rounded, size: 52, color: Colors.grey);
    }
    return Container(
      color: const Color(0xFF9E9E9E),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Subscription card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.plan});
  final SubscriptionPlanModel plan;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGreen, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.planName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kFieldText),
                    ),
                    if (plan.expiryLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _PlanExpiryLabel(
                        label:   plan.expiryLabel,
                        expired: plan.isExpired,
                      ),
                    ],
                  ],
                ),
              ),
              if (plan.hasPrice)
                Text(
                  plan.priceDisplay,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kFieldText),
                ),
            ],
          ),
        ),

        // "CURRENT PLAN" badge overlapping the top border
        Positioned(
          top: -10,
          left: 12,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: const Text(
              'CURRENT PLAN',
              style: TextStyle(
                  color: _kGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Plan expiry label ─────────────────────────────────────────────────────────

class _PlanExpiryLabel extends StatelessWidget {
  const _PlanExpiryLabel({required this.label, required this.expired});

  final String label;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    if (expired) {
      return Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kFieldLabel,
          letterSpacing: 0.4,
        ),
      );
    }

    // Split "EXPIRE IN " from "120 DAYS" — prefix lighter, suffix bolder.
    final parts  = label.split(RegExp(r'(?<=IN )|(?=\d)'));
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

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: _kFieldLabel,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2),
      );
}

// ── Gender radio tile — fully custom to avoid any Radio/RadioListTile APIs. ───

class _GenderRadioTile extends StatelessWidget {
  const _GenderRadioTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _kPink : Colors.grey.shade400,
            width: selected ? 6.5 : 2,
          ),
        ),
      ),
      title: Text(label),
      onTap: () => onChanged(value),
    );
  }
}
