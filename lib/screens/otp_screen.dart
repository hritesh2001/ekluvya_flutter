import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/logger.dart';
import '../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../features/subscription/presentation/view/subscription_plans_screen.dart';
import '../features/video_player/presentation/view/video_player_screen.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_toast.dart';

bool _isNotAuthRoute(Route<dynamic> route) =>
    route.settings.name != '/student-password' &&
    route.settings.name != '/login' &&
    route.settings.name != '/otp';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _phone;
  bool _isRegistered = false; // true = existing user → home, false = new user → register
  bool _isInitialized = false;
  int _timerSeconds = 30;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _phone = args['phone']?.toString() ?? '';
        // exists: true  → registered user → route to /home after login
        // exists: false → new user        → route to /register after login
        _isRegistered = args['exists'] == true;
      } else {
        _phone = args?.toString() ?? '';
        _isRegistered = false;
      }
      AppLogger.info('OtpScreen',
          'phone=$_phone  isRegistered=$_isRegistered');
      _startTimer();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    if (mounted) setState(() => _timerSeconds = 30);
    _runTimer();
  }

  Future<void> _runTimer() async {
    while (mounted && _timerSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _timerSeconds--);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _otp => _controllers.map((c) => c.text).join();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      _showSnack('Enter the complete 6-digit OTP');
      return;
    }

    final authVM = context.read<AuthViewModel>();

    // Step 1: Verify OTP against the server
    final verified = await authVM.verifyOtp(_phone, _otp);
    if (!mounted) return;

    if (!verified) {
      _showSnack(authVM.errorMessage ?? 'Invalid OTP');
      return;
    }

    // Step 2: Complete login (phone-login API)
    final loggedIn = await authVM.phoneLogin(_phone);
    if (!mounted) return;

    if (loggedIn) {
      AppLogger.info('OtpScreen',
          'login success, isRegistered=$_isRegistered → running post-login flow');

      // Run the mandatory 4-step post-login sequence.
      final sessionVM = context.read<SessionViewModel>();
      await sessionVM.runPostLoginFlow();
      if (!mounted) return;

      // Device restriction blocks access entirely.
      if (sessionVM.isDeviceRestricted) {
        Navigator.pushReplacementNamed(context, '/device-restriction');
        return;
      }

      if (_isRegistered) {
        AppToast.show(context, message: 'You have successfully logged in');

        if (sessionVM.hasPendingVideo) {
          final video   = sessionVM.pendingVideo!;
          final headers = Map<String, String>.from(sessionVM.pendingVideoHeaders);
          sessionVM.clearPendingVideo();

          if (sessionVM.isSubscribed) {
            Navigator.of(context).pushAndRemoveUntil(
              VideoPlayerScreen.route(video, headers: headers),
              _isNotAuthRoute,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              SubscriptionPlansScreen.route(context),
              _isNotAuthRoute,
            );
          }
        } else {
          Navigator.of(context).popUntil(_isNotAuthRoute);
        }
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/register',
          arguments: {'phone': _phone},
        );
      }
    } else {
      _showSnack(authVM.errorMessage ?? 'Login failed. Please try again.');
    }
  }

  Future<void> _resendOtp() async {
    final authVM = context.read<AuthViewModel>();
    final success = await authVM.resendOtp(_phone);
    if (!mounted) return;

    if (success) {
      _showSnack('OTP resent successfully');
      _startTimer();
    } else {
      _showSnack(authVM.errorMessage ?? 'Failed to resend OTP');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Enter 6-digit code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Code sent to +91 $_phone',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Change number',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOtpBox),
              ),

              const SizedBox(height: 20),

              // Resend timer / button
              Center(
                child: _timerSeconds > 0
                    ? Text(
                        'Resend OTP in 00:${_timerSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.grey),
                      )
                    : TextButton(
                        onPressed: _resendOtp,
                        child: const Text('Resend OTP'),
                      ),
              ),

              const Spacer(),

              // Verify button — rebuilds only this area on loading state change
              Consumer<AuthViewModel>(
                builder: (context, authVM, _) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authVM.isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: authVM.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
