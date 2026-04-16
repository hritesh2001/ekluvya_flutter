import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'features/banner/data/remote/banner_api_service.dart';
import 'features/banner/data/repository/banner_repository_impl.dart';
import 'features/banner/domain/repositories/banner_repository.dart';
import 'features/banner/presentation/viewmodel/banner_viewmodel.dart';
import 'features/channel/data/remote/channel_api_service.dart';
import 'features/channel/data/repository/channel_repository_impl.dart';
import 'features/channel/domain/repositories/channel_repository.dart';
import 'features/class_subject/data/remote/class_subject_api_service.dart';
import 'features/class_subject/data/repository/class_subject_repository_impl.dart';
import 'features/class_subject/domain/repositories/class_subject_repository.dart';
import 'features/course/data/remote/course_api_service.dart';
import 'features/course/data/repository/course_repository_impl.dart';
import 'features/course/domain/repositories/course_repository.dart';
import 'features/course/presentation/viewmodel/course_viewmodel.dart';
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

        // ── Banner module ────────────────────────────────────────────────
        Provider<BannerApiService>(create: (_) => BannerApiService()),

        ProxyProvider<BannerApiService, BannerRepository>(
          create: (ctx) => BannerRepositoryImpl(
            apiService: ctx.read<BannerApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? BannerRepositoryImpl(apiService: api),
        ),

        ChangeNotifierProxyProvider<BannerRepository, BannerViewModel>(
          create: (ctx) => BannerViewModel(ctx.read<BannerRepository>()),
          update: (_, repo, previous) => previous ?? BannerViewModel(repo),
        ),

        // ── Course module ────────────────────────────────────────────────
        Provider<CourseApiService>(create: (_) => CourseApiService()),

        ProxyProvider<CourseApiService, CourseRepository>(
          create: (ctx) => CourseRepositoryImpl(
            apiService: ctx.read<CourseApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? CourseRepositoryImpl(apiService: api),
        ),

        ChangeNotifierProxyProvider<CourseRepository, CourseViewModel>(
          create: (ctx) => CourseViewModel(ctx.read<CourseRepository>()),
          update: (_, repo, previous) => previous ?? CourseViewModel(repo),
        ),

        // ── Class + Subject module ───────────────────────────────────────
        // ClassSubjectRepository is registered globally so every
        // CourseDetailScreen can read it via context.read<ClassSubjectRepository>()
        // and the in-memory cache is shared across screen visits.
        Provider<ClassSubjectApiService>(
          create: (_) => ClassSubjectApiService(),
        ),

        ProxyProvider<ClassSubjectApiService, ClassSubjectRepository>(
          create: (ctx) => ClassSubjectRepositoryImpl(
            apiService: ctx.read<ClassSubjectApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? ClassSubjectRepositoryImpl(apiService: api),
        ),

        // ── Channel (partner content) module ─────────────────────────────
        // ChannelRepository is registered globally so the in-memory cache
        // survives navigation and avoids duplicate requests across visits.
        Provider<ChannelApiService>(create: (_) => ChannelApiService()),

        ProxyProvider<ChannelApiService, ChannelRepository>(
          create: (ctx) => ChannelRepositoryImpl(
            apiService: ctx.read<ChannelApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? ChannelRepositoryImpl(apiService: api),
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
