import 'package:flutter/material.dart';

/// Spacing scale (padding / gap). Hardcoded numbers ki jagah yehi use karo.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radius scale.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // buttons, inputs
  static const double xl = 20; // cards
  static const double xxl = 24; // large cards
  static const double sheet = 32; // bottom sheet / login panel
  static const double pill = 100;

  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Fixed component sizes.
class AppSizes {
  AppSizes._();

  static const double buttonLarge = 56;
  static const double buttonMedium = 48;
  static const double buttonSmall = 40;
  static const double input = 56;
  static const double iconButton = 44;
  static const double minTouchTarget = 48;
}