import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/viewmodel/session_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_toast.dart';

class StudentPasswordScreen extends StatefulWidget {
  const StudentPasswordScreen({super.key});

  @override
  State<StudentPasswordScreen> createState() => _StudentPasswordScreenState();
}

class _StudentPasswordScreenState extends State<StudentPasswordScreen> {
  final _passwordController = TextEditingController();
  late String _username;
  bool _obscure = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _username =
        ModalRoute.of(context)?.settings.arguments?.toString() ?? '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showSnack('Enter your password');
      return;
    }

    final authVM = context.read<AuthViewModel>();
    final success = await authVM.studentLogin(_username, password);
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
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnack(authVM.errorMessage ?? 'Invalid credentials');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Extend behind status bar so gradient fills the entire screen
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // ── Lock icon ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Heading ──────────────────────────────────────────
                      const Text(
                        'Enter Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Sub-heading ──────────────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'Logging in as  ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ── Password field ───────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFFE91E63),
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: Colors.grey[500],
                                size: 22,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Login button ─────────────────────────────────────
                      Consumer<AuthViewModel>(
                        builder: (context, authVM, _) => SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: authVM.isLoading
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                      ],
                                    ),
                              color: authVM.isLoading
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: authVM.isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: authVM.isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 17),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: authVM.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFE91E63),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        color: Color(0xFFE91E63),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── Forgot password hint ─────────────────────────────
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            'Contact your institute if you forgot your password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
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
