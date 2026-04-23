import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_toast.dart';

const _kPink   = Color(0xFFE91E63);
const _kOrange = Color(0xFFFF9800);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  String? _validationError;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final newPass     = _newCtrl.text.trim();
    final confirmPass = _confirmCtrl.text.trim();
    if (newPass.isEmpty)       return 'Enter your new password';
    if (newPass.length < 8)    return 'Password must be at least 8 characters';
    if (confirmPass.isEmpty)   return 'Please confirm your password';
    if (newPass != confirmPass) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    setState(() => _validationError = null);

    final authVM    = context.read<AuthViewModel>();
    final sessionVM = context.read<SessionViewModel>();

    final success = await authVM.resetPassword(_newCtrl.text.trim());
    if (!mounted) return;

    if (!success) {
      setState(() => _validationError = authVM.errorMessage ?? 'Failed to update password');
      return;
    }

    await sessionVM.runPostLoginFlow();
    if (!mounted) return;

    if (sessionVM.isDeviceRestricted) {
      Navigator.pushReplacementNamed(context, '/device-restriction');
      return;
    }
    AppToast.show(context, message: 'Password updated successfully');
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPink, _kOrange],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: ColoredBox(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
                      child: _ResetForm(
                        newCtrl:          _newCtrl,
                        confirmCtrl:      _confirmCtrl,
                        obscureNew:       _obscureNew,
                        obscureConfirm:   _obscureConfirm,
                        validationError:  _validationError,
                        onToggleNew:      () => setState(() => _obscureNew = !_obscureNew),
                        onToggleConfirm:  () => setState(() => _obscureConfirm = !_obscureConfirm),
                        onSubmit:         _submit,
                      ),
                    ),
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

// ── Form ──────────────────────────────────────────────────────────────────────

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    required this.newCtrl,
    required this.confirmCtrl,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.validationError,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool obscureNew;
  final bool obscureConfirm;
  final String? validationError;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (_, authVM, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────
          const Text(
            'Reset New Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D0D0D),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle ───────────────────────────────────────────────
          const Text(
            'Please create a strong password for your account',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF777777),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 40),

          // ── New password ───────────────────────────────────────────
          _PasswordField(
            controller:  newCtrl,
            hintText:    'New Password',
            obscureText: obscureNew,
            onToggle:    onToggleNew,
            onSubmitted: (_) {},
          ),
          const SizedBox(height: 16),

          // ── Confirm password ───────────────────────────────────────
          _PasswordField(
            controller:  confirmCtrl,
            hintText:    'Confirm Password',
            obscureText: obscureConfirm,
            onToggle:    onToggleConfirm,
            onSubmitted: (_) => onSubmit(),
          ),

          // ── Inline validation error ────────────────────────────────
          if (validationError != null) ...[
            const SizedBox(height: 12),
            Text(
              validationError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 36),

          // ── Submit button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authVM.isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPink,
                disabledBackgroundColor: _kPink.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 17),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: authVM.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'UPDATE PASSWORD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable password field ───────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggle,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggle;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      obscureText:  obscureText,
      onSubmitted:  onSubmitted,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
      decoration: InputDecoration(
        hintText:  hintText,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: const Color(0xFF888888),
            size: 22,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPink, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
