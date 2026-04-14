import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppColors — custom ThemeExtension for brand-specific tokens that live
// outside the standard Material ColorScheme.
//
// Usage anywhere in the widget tree:
//   final colors = Theme.of(context).extension<AppColors>()!;
//   color: colors.brand
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandAccent,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.cardBackground,
    required this.sectionTitleText,
    required this.metaText,
    required this.cardShadow,
    required this.imagePlaceholder,
    required this.errorSurface,
  });

  /// Primary brand / accent color (pink).
  final Color brand;

  /// Slightly lighter brand for dark mode pop.
  final Color brandAccent;

  /// Shimmer animation — darker base block.
  final Color shimmerBase;

  /// Shimmer animation — lighter sweep highlight.
  final Color shimmerHighlight;

  /// Course card / banner error container background.
  final Color cardBackground;

  /// Section header title color.
  final Color sectionTitleText;

  /// Secondary metadata text (e.g. "12 Courses").
  final Color metaText;

  /// Card drop-shadow color (use with opacity).
  final Color cardShadow;

  /// Image placeholder / fallback container color.
  final Color imagePlaceholder;

  /// Error state container background.
  final Color errorSurface;

  // ── Presets ──────────────────────────────────────────────────────────────

  static const AppColors light = AppColors(
    brand: Color(0xFFE91E63),
    brandAccent: Color(0xFFEC407A),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF8F8F8),
    cardBackground: Color(0xFFFFFFFF),
    sectionTitleText: Color(0xFFE91E63),
    metaText: Color(0xFF9E9E9E),
    cardShadow: Color(0xFF000000),
    imagePlaceholder: Color(0xFFF0F0F0),
    errorSurface: Color(0xFFFFF3F3),
  );

  static const AppColors dark = AppColors(
    brand: Color(0xFFFF4081),
    brandAccent: Color(0xFFFF80AB),
    shimmerBase: Color(0xFF2C2C2C),
    shimmerHighlight: Color(0xFF3D3D3D),
    cardBackground: Color(0xFF1E1E1E),
    sectionTitleText: Color(0xFFFF4081),
    metaText: Color(0xFF757575),
    cardShadow: Color(0xFF000000),
    imagePlaceholder: Color(0xFF2C2C2C),
    errorSurface: Color(0xFF2A1515),
  );

  // ── ThemeExtension boilerplate ────────────────────────────────────────────

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandAccent,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? cardBackground,
    Color? sectionTitleText,
    Color? metaText,
    Color? cardShadow,
    Color? imagePlaceholder,
    Color? errorSurface,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandAccent: brandAccent ?? this.brandAccent,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      cardBackground: cardBackground ?? this.cardBackground,
      sectionTitleText: sectionTitleText ?? this.sectionTitleText,
      metaText: metaText ?? this.metaText,
      cardShadow: cardShadow ?? this.cardShadow,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      errorSurface: errorSurface ?? this.errorSurface,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      sectionTitleText:
          Color.lerp(sectionTitleText, other.sectionTitleText, t)!,
      metaText: Color.lerp(metaText, other.metaText, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      imagePlaceholder:
          Color.lerp(imagePlaceholder, other.imagePlaceholder, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — single source of truth for light & dark ThemeData.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static const _brand = Color(0xFFE91E63);
  static const _brandDark = Color(0xFFFF4081);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brand,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: Color(0xFF9E9E9E),
          ),
        ),
        extensions: const [AppColors.light],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandDark,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: Color(0xFF9E9E9E),
          ),
        ),
        extensions: const [AppColors.dark],
      );
}
