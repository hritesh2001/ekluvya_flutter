import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/utils/logger.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_password_screen.dart';
import 'services/api_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/registration_viewmodel.dart';

void main() {
  // runZonedGuarded catches all uncaught async errors — the last safety net
  // before an unhandled exception would crash a production app.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors (widget build, layout, etc.)
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          'FlutterError',
          details.exceptionAsString(),
          details.exception,
          details.stack,
        );
      };

      runApp(const _AppProviders());
    },
    (error, stack) {
      // Catches errors thrown in async gaps not inside a try-catch
      AppLogger.error('ZoneError', error.toString(), error, stack);
    },
  );
}

/// Hosts the Provider tree above the widget tree so every screen
/// can reach ViewModels without passing them down manually.
class _AppProviders extends StatelessWidget {
  const _AppProviders();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Single ApiService instance shared by all ViewModels
        Provider<ApiService>(create: (_) => ApiService()),

        ChangeNotifierProxyProvider<ApiService, AuthViewModel>(
          create: (ctx) => AuthViewModel(ctx.read<ApiService>()),
          update: (_, api, previous) => previous ?? AuthViewModel(api),
        ),

        ChangeNotifierProxyProvider<ApiService, RegistrationViewModel>(
          create: (ctx) => RegistrationViewModel(ctx.read<ApiService>()),
          update: (_, api, previous) => previous ?? RegistrationViewModel(api),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ekluvya',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/home': (context) => const HomeScreen(),
        '/student-password': (context) => const StudentPasswordScreen(),
      },
      // Widget-level error boundary — shows a friendly UI instead of a red screen
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          AppLogger.error('ErrorBoundary', details.exceptionAsString());
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please restart the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
