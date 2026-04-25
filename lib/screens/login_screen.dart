import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../features/subscription/presentation/view/subscription_plans_screen.dart';
import '../features/video_player/presentation/view/video_player_screen.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_toast.dart';

bool _isNotAuthRoute(Route<dynamic> route) =>
    route.settings.name != '/student-password' &&
    route.settings.name != '/login' &&
    route.settings.name != '/otp';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputController = TextEditingController();
  final _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signInWithGoogle() async {
    final authVM = context.read<AuthViewModel>();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return; // user cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        _showSnack('Google login failed. Please try again.');
        return;
      }

      final success = await authVM.googleLogin(idToken);
      if (!mounted) return;

      if (success) {
        final sessionVM = context.read<SessionViewModel>();
        await sessionVM.runPostLoginFlow();
        if (!mounted) return;

        if (sessionVM.isDeviceRestricted) {
          Navigator.pushReplacementNamed(context, '/device-restriction');
          return;
        }

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
        _showSnack(authVM.errorMessage ?? 'Google login failed');
      }
    } catch (e) {
      if (mounted) _showSnack('Google login failed. Please try again.');
    }
  }

  Future<void> _handleLogin() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showSnack('Enter mobile number or admission number');
      return;
    }

    final authVM = context.read<AuthViewModel>();

    // Step 1: identify user → get auth method + exists flag
    final identified = await authVM.identify(input);
    if (!mounted) return;

    if (identified == null) {
      _showSnack(authVM.errorMessage ?? 'User not found');
      return;
    }

    final method = identified['authMethod'] as String? ?? '';
    final exists = identified['exists'] as bool? ?? false;

    if (method == 'otp') {
      // Step 2 (OTP flow): send OTP
      final sent = await authVM.sendOtp(input);
      if (!mounted) return;

      if (sent) {
        Navigator.pushNamed(
          context,
          '/otp',
          // Pass phone + exists flag so OTP screen can decide post-login routing
          arguments: {'phone': input, 'exists': exists},
        );
      } else {
        _showSnack(authVM.errorMessage ?? 'Failed to send OTP');
      }
    } else if (method == 'password') {
      Navigator.pushNamed(context, '/student-password', arguments: input);
    } else {
      _showSnack('Unsupported login method. Please contact support.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          // LayoutBuilder + SingleChildScrollView prevents overflow on small
          // screens while keeping the gradient full-height on large ones.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: _LoginBody(
                    controller: _inputController,
                    onLogin: _handleLogin,
                    onGoogle: _signInWithGoogle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extracted to a separate widget so [Consumer] only rebuilds the button area,
/// not the entire screen, when loading state changes.
class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.controller,
    required this.onLogin,
    required this.onGoogle,
  });

  final TextEditingController controller;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVM, _) {
        final loading = authVM.isLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close / exit button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == '/home' || route.isFirst,
                ),
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'Continue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Login using mobile number or admission number',
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 40),

            // Dynamic input: shows +91 prefix when a 10-digit number is typed
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final isPhone =
                    RegExp(r'^[0-9]{10}$').hasMatch(value.text);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (isPhone) ...[
                        const Text(
                          '+91',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          height: 24,
                          child: VerticalDivider(thickness: 1),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Mobile Number / Admission Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: const [
                Expanded(child: Divider(color: Colors.white70)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR', style: TextStyle(color: Colors.white)),
                ),
                Expanded(child: Divider(color: Colors.white70)),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onGoogle,
                icon: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                  height: 20,
                  // Graceful fallback when offline or image fails to load
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.account_circle, size: 20),
                ),
                label: const Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
