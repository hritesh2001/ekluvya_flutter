import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

/// Checks for an existing auth token and routes the user accordingly.
/// Users with a valid saved token skip the login flow entirely.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_initApp);
  }

  Future<void> _initApp() async {
    // Minimum splash duration so the logo is visible
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final token = await context.read<ApiService>().getToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('assets/icons/logo.png', width: 150),
      ),
    );
  }
}
