import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_textstyle.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final AppPalette palette = isDark ? AppPalette.dark : AppPalette.light;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.mint,
      onSecondary: AppColors.ink,
      error: AppColors.coral,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: palette.border,
    );

    final TextTheme textTheme = AppTextStyles.textTheme(
      primary: palette.textPrimary,
      secondary: palette.textSecondary,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1.5}) {
      return OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      splashFactory: InkRipple.splashFactory,

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: palette.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),

      // ── Inputs ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 18,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: palette.textHint),
        helperStyle: AppTextStyles.caption.copyWith(
          color: palette.textSecondary,
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.coral),
        errorMaxLines: 2,
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        disabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(AppColors.primary),
        errorBorder: inputBorder(AppColors.coral, width: 1.2),
        focusedErrorBorder: inputBorder(AppColors.coral),
      ),

      // ── Fallback buttons (hum mostly AppButton use karenge) ─────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, AppSizes.buttonLarge),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.bodyBold,
        ),
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.border,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Snackbar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.snackbar,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
      ),

      // ── Misc ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
