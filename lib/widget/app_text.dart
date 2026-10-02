import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_textstyle.dart';

enum AppTextType {
  hero,
  display,
  h1,
  h2,
  title,
  bodyLarge,
  body,
  bodyBold,
  caption,
  label,
  price,
}

/// Poore app mein Text ki jagah yehi use karo, taaki font / size / color
/// design system se bahar na jaye. Light/dark mode automatic.
///
/// ```dart
/// const AppText.h1('Dashboard')
/// const AppText.body('Sales, transactions at a glance', secondary: true)
/// AppText.price('₹62,655.48')
/// AppText.hero('₹62,655.48', color: Colors.white)
/// ```
class AppText extends StatelessWidget {
  const AppText(
      this.text, {
        super.key,
        this.type = AppTextType.body,
        this.color,
        this.align,
        this.maxLines,
        this.weight,
        this.secondary,
        this.softWrap,
      });

  const AppText.hero(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.hero,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.display(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.display,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.h1(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.h1,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.h2(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.h2,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.title(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.title,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.body(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.body,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.bodyBold(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.bodyBold,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.caption(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.caption,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.label(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.label,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  const AppText.price(
      String text, {
        Key? key,
        Color? color,
        TextAlign? align,
        int? maxLines,
        bool? secondary,
      }) : this(
    text,
    key: key,
    type: AppTextType.price,
    color: color,
    align: align,
    maxLines: maxLines,
    secondary: secondary,
  );

  final String text;
  final AppTextType type;

  /// Explicit color. Na do to theme se aata hai.
  final Color? color;
  final TextAlign? align;

  /// Set karoge to overflow par "..." aayega.
  final int? maxLines;
  final FontWeight? weight;

  /// true = secondary (grey) text color. Null pe caption/label automatic secondary.
  final bool? secondary;
  final bool? softWrap;

  TextStyle _baseStyle() {
    switch (type) {
      case AppTextType.hero:
        return AppTextStyles.hero;
      case AppTextType.display:
        return AppTextStyles.display;
      case AppTextType.h1:
        return AppTextStyles.h1;
      case AppTextType.h2:
        return AppTextStyles.h2;
      case AppTextType.title:
        return AppTextStyles.title;
      case AppTextType.bodyLarge:
        return AppTextStyles.bodyLarge;
      case AppTextType.body:
        return AppTextStyles.body;
      case AppTextType.bodyBold:
        return AppTextStyles.bodyBold;
      case AppTextType.caption:
        return AppTextStyles.caption;
      case AppTextType.label:
        return AppTextStyles.label;
      case AppTextType.price:
        return AppTextStyles.price;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool useSecondary = secondary ??
        (type == AppTextType.caption || type == AppTextType.label);
    final Color resolved =
        color ?? (useSecondary ? palette.textSecondary : palette.textPrimary);

    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: _baseStyle().copyWith(color: resolved, fontWeight: weight),
    );
  }
}