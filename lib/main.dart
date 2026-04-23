import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'features/badge/data/remote/badge_api_service.dart';
import 'features/badge/data/repository/badge_repository_impl.dart';
import 'features/badge/domain/repositories/badge_repository.dart';
import 'features/rating/data/remote/rating_api_service.dart';
import 'features/rating/data/repository/rating_repository_impl.dart';
import 'features/rating/domain/repositories/rating_repository.dart';
import 'features/signed_cookie/data/remote/signed_cookie_api_service.dart';
import 'features/signed_cookie/data/repository/signed_cookie_repository_impl.dart';
import 'features/signed_cookie/domain/repositories/signed_cookie_repository.dart';
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
import 'features/auth/data/remote/session_api_service.dart';
import 'features/auth/presentation/view/device_restriction_screen.dart';
import 'features/auth/presentation/viewmodel/device_viewmodel.dart';
import 'features/auth/presentation/viewmodel/session_viewmodel.dart';
import 'features/video_access/data/repositories/video_access_repository_impl.dart';
import 'features/video_access/domain/repositories/video_access_repository.dart';
import 'features/video_access/domain/usecases/check_video_access_usecase.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';
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

        // ── Session (auth + subscription + device) ───────────────────
        Provider<SessionApiService>(create: (_) => SessionApiService()),

        ChangeNotifierProxyProvider2<ApiService, SessionApiService,
            SessionViewModel>(
          create: (ctx) => SessionViewModel(
            apiService: ctx.read<ApiService>(),
            sessionApiService: ctx.read<SessionApiService>(),
          ),
          update: (_, api, sessionApi, previous) =>
              previous ??
              SessionViewModel(
                apiService: api,
                sessionApiService: sessionApi,
              ),
        ),

        ChangeNotifierProxyProvider<ApiService, AuthViewModel>(
          create: (ctx) => AuthViewModel(ctx.read<ApiService>()),
          update: (_, api, previous) => previous ?? AuthViewModel(api),
        ),

        ChangeNotifierProxyProvider<ApiService, RegistrationViewModel>(
          create: (ctx) => RegistrationViewModel(ctx.read<ApiService>()),
          update: (_, api, previous) => previous ?? RegistrationViewModel(api),
        ),

        // ── Video access control (domain + data) ────────────────────────
        // Stateless singleton — pure function, no ChangeNotifier needed.
        Provider<VideoAccessRepository>(
          create: (_) => const VideoAccessRepositoryImpl(),
        ),

        ProxyProvider<VideoAccessRepository, CheckVideoAccessUseCase>(
          create: (ctx) => CheckVideoAccessUseCase(
            ctx.read<VideoAccessRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? CheckVideoAccessUseCase(repo),
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
        Provider<ChannelApiService>(create: (_) => ChannelApiService()),

        ProxyProvider<ChannelApiService, ChannelRepository>(
          create: (ctx) => ChannelRepositoryImpl(
            apiService: ctx.read<ChannelApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? ChannelRepositoryImpl(apiService: api),
        ),

        // ── Badge module ──────────────────────────────────────────────────
        // BadgeRepository is global so its cache persists across chapter
        // switches and screen re-visits.
        Provider<BadgeApiService>(create: (_) => BadgeApiService()),

        ProxyProvider<BadgeApiService, BadgeRepository>(
          create: (ctx) => BadgeRepositoryImpl(
            apiService: ctx.read<BadgeApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? BadgeRepositoryImpl(apiService: api),
        ),

        // ── Rating module ─────────────────────────────────────────────────
        // RatingRepository is global so its cache persists across chapter
        // switches and screen re-visits.
        Provider<RatingApiService>(create: (_) => RatingApiService()),

        ProxyProvider<RatingApiService, RatingRepository>(
          create: (ctx) => RatingRepositoryImpl(
            apiService: ctx.read<RatingApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? RatingRepositoryImpl(apiService: api),
        ),

        // ── Signed Cookie module ──────────────────────────────────────────
        // Global singleton — cache persists for the cookie's validity window.
        Provider<SignedCookieApiService>(
          create: (_) => SignedCookieApiService(),
        ),

        ProxyProvider<SignedCookieApiService, SignedCookieRepository>(
          create: (ctx) => SignedCookieRepositoryImpl(
            apiService: ctx.read<SignedCookieApiService>(),
          ),
          update: (_, api, previous) =>
              previous ?? SignedCookieRepositoryImpl(apiService: api),
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
        '/reset-password': (context) => const ResetPasswordScreen(),
        DeviceRestrictionScreen.routeName: (ctx) => ChangeNotifierProvider(
          create: (c) => DeviceViewModel(
            sessionVM: c.read<SessionViewModel>(),
            authVM:    c.read<AuthViewModel>(),
          ),
          child: const DeviceRestrictionScreen(),
        ),
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
