import 'package:flutter/material.dart';

/// Raw brand colors. Ye wahi colors hain jo Stitch / Figma design system mein diye the.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6D4AFF); // Electric Violet
  static const Color primaryLight = Color(0xFF8B6BFF);
  static const Color ink = Color(0xFF0E1020);

  // ── Status / accents ─────────────────────────────────────────────────────
  static const Color mint = Color(0xFF2DE2A6); // success, positive growth
  static const Color mintDark = Color(0xFF0FA67A); // success text on light bg
  static const Color coral = Color(0xFFFF5C6C); // danger, End Shift, refund
  static const Color amber = Color(0xFFFFB547); // held, low stock
  static const Color sky = Color(0xFF4CC9F0); // UPI / online

  // ── Soft (tinted) backgrounds for chips and icon chips ───────────────────
  static const Color primarySoft = Color(0xFFEFEBFF);
  static const Color mintSoft = Color(0xFFE8FBF4);
  static const Color coralSoft = Color(0xFFFFEBED);
  static const Color amberSoft = Color(0xFFFFF4E0);
  static const Color skySoft = Color(0xFFE6F8FD);

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F3FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F3FA); // input fill
  static const Color lightBorder = Color(0xFFE8E6F2);
  static const Color lightTextPrimary = Color(0xFF14142B);
  static const Color lightTextSecondary = Color(0xFF6E6D86);
  static const Color lightTextHint = Color(0xFFA3A2B8);

  // ── Dark theme ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0E1020);
  static const Color darkSurface = Color(0xFF181A30);
  static const Color darkSurfaceAlt = Color(0xFF20233F);
  static const Color darkBorder = Color(0xFF26294A);
  static const Color darkTextPrimary = Color(0xFFF4F3FA);
  static const Color darkTextSecondary = Color(0xFFA3A2C0);
  static const Color darkTextHint = Color(0xFF6F7192);

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const Color snackbar = Color(0xFF1E2140);
  static const Color overlay = Color(0x590E1020); // ~35% ink

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1F6B), ink],
  );
}

/// Theme ke saath badalne wale (light/dark) colors.
/// Use: `context.palette.surface`, `context.palette.textSecondary`
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.primarySoft,
    required this.shadow,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color primarySoft;
  final Color shadow;

  static const AppPalette light = AppPalette(
    isDark: false,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textHint: AppColors.lightTextHint,
    primarySoft: AppColors.primarySoft,
    shadow: Color(0x146D4AFF), // violet 8%
  );

  static const AppPalette dark = AppPalette(
    isDark: true,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textHint: AppColors.darkTextHint,
    primarySoft: Color(0xFF2A2352),
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    bool? isDark,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? primarySoft,
    Color? shadow,
  }) {
    return AppPalette(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      primarySoft: primarySoft ?? this.primarySoft,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}