import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../utils/responsive.dart';

class AdaptiveText extends StatelessWidget {
  const AdaptiveText(
      this.text,
      this.base, {
        super.key,
        required this.m,
        this.t,
        this.color,
        this.secondary = false,
        this.weight,
        this.maxLines,
        this.align,
        this.tabular = false,
      });

  final String text;
  final TextStyle base;

  /// Mobile font size.
  final double m;

  /// Tablet font size (null = mobile + 2).
  final double? t;
  final Color? color;
  final bool secondary;
  final FontWeight? weight;
  final int? maxLines;
  final TextAlign? align;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Text(
      text,
      maxLines: maxLines,
      textAlign: align,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: base.copyWith(
        fontSize: context.isTablet ? (t ?? m + 2) : m,
        color: color ?? (secondary ? p.textSecondary : p.textPrimary),
        fontWeight: weight,
        fontFeatures: tabular
            ? const <FontFeature>[FontFeature.tabularFigures()]
            : null,
      ),
    );
  }
}

/// Rounded surface card (light/dark).
class PosCard extends StatelessWidget {
  const PosCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(m ? 14 : 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: m ? 14 : 20,
            offset: Offset(0, m ? 4 : 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// App ke design ka simple text field (name, phone, amount ke liye).
class PosField extends StatelessWidget {
  const PosField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? errorText;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final bool m = context.isMobile;
    final BorderRadius r = BorderRadius.circular(AppRadius.lg);

    OutlineInputBorder border(Color? c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: r,
      borderSide:
      c == null ? BorderSide.none : BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTextStyles.body.copyWith(
        color: p.textPrimary,
        fontSize: m ? 14 : 15,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: p.surfaceAlt,
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: TextStyle(color: p.textSecondary, fontSize: m ? 13 : 14),
        hintStyle: TextStyle(color: p.textHint, fontSize: m ? 13 : 14),
        prefixIcon:
        icon == null ? null : Icon(icon, size: 20, color: p.textSecondary),
        suffixIcon: suffix,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: m ? 12 : 14,
        ),
        border: border(null),
        enabledBorder: border(null),
        disabledBorder: border(null),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.coral, 1),
        focusedErrorBorder: border(AppColors.coral),
      ),
    );
  }
}

const List<List<Color>> _thumbTints = <List<Color>>[
  <Color>[AppColors.primarySoft, AppColors.primary],
  <Color>[AppColors.skySoft, Color(0xFF0E9FC4)],
  <Color>[AppColors.mintSoft, AppColors.mintDark],
  <Color>[AppColors.amberSoft, Color(0xFFE08A00)],
  <Color>[AppColors.coralSoft, AppColors.coral],
];

/// Product image; na ho ya fail ho to naam ke akshar.
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    required this.url,
    required this.name,
    this.size = 46,
  });

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final int seed = name.codeUnits.fold<int>(0, (int a, int b) => a + b);
    final List<Color> tint = _thumbTints[seed % _thumbTints.length];
    final double radius = size * 0.28;

    final Widget letters = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? tint[1].withAlpha(36) : tint[0],
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        name.trim().isEmpty
            ? '?'
            : name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase(),
        style: AppTextStyles.bodyBold.copyWith(
          color: tint[1],
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final String? u = url;
    if (u == null || u.isEmpty) return letters;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (BuildContext context, String _) => letters,
        errorWidget: (BuildContext context, String _, Object __) => letters,
      ),
    );
  }
}