import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
      double size,
      FontWeight weight, {
        double? height,
        double? letterSpacing,
        bool tabular = false,
      }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? _tabular : null,
    );
  }

  /// Big dashboard numbers (Net Sales)
  static TextStyle get hero =>
      _style(30, FontWeight.w600, height: 1.1, letterSpacing: -1, tabular: true);

  static TextStyle get display =>
      _style(17, FontWeight.w600, height: 1.2, letterSpacing: -0.5);

  static TextStyle get h1 =>
      _style(18, FontWeight.w600, height: 1.25, letterSpacing: -0.3);

  static TextStyle get h2 => _style(18, FontWeight.w700, height: 1.3);

  static TextStyle get title => _style(16, FontWeight.w600, height: 1.4);

  static TextStyle get bodyLarge => _style(13, FontWeight.w500, height: 1.5);

  static TextStyle get body => _style(12, FontWeight.w500, height: 1.5);

  static TextStyle get bodyBold => _style(14, FontWeight.w700, height: 1.5);

  static TextStyle get caption => _style(12, FontWeight.w500, height: 1.4);

  static TextStyle get label =>
      _style(12, FontWeight.w600, height: 1.4, letterSpacing: 0.2);

  /// Prices / totals: tabular numbers so digits align.
  static TextStyle get price =>
      _style(18, FontWeight.w800, height: 1.2, tabular: true);

  static TextStyle get button =>
      _style(16, FontWeight.w700, height: 1.2, letterSpacing: 0.1);

  /// Material TextTheme, taaki default widgets bhi same font/size use karein.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: hero.copyWith(color: primary),
      displayMedium: display.copyWith(color: primary),
      headlineLarge: h1.copyWith(color: primary),
      headlineMedium: h2.copyWith(color: primary),
      headlineSmall: title.copyWith(color: primary),
      titleLarge: h2.copyWith(color: primary),
      titleMedium: title.copyWith(color: primary),
      titleSmall: bodyBold.copyWith(color: primary),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: body.copyWith(color: primary),
      bodySmall: caption.copyWith(color: secondary),
      labelLarge: button.copyWith(color: primary),
      labelMedium: label.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: secondary),
    );
  }
}