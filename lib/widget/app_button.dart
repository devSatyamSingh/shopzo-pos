import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_textstyle.dart';

enum AppButtonVariant { primary, tonal, outline, danger, ghost }

enum AppButtonSize { large, medium, small }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = true,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool fullWidth;
  final bool haptic;

  _ButtonDims get _dims {
    switch (size) {
      case AppButtonSize.large:
        return const _ButtonDims(
          height: AppSizes.buttonLarge,
          fontSize: 15,
          iconSize: 20,
          horizontalPadding: 22,
          radius: 16,
        );
      case AppButtonSize.medium:
        return const _ButtonDims(
          height: AppSizes.buttonMedium,
          fontSize: 15,
          iconSize: 20,
          horizontalPadding: 20,
          radius: 14,
        );
      case AppButtonSize.small:
        return const _ButtonDims(
          height: AppSizes.buttonSmall,
          fontSize: 13,
          iconSize: 18,
          horizontalPadding: 16,
          radius: 12,
        );
    }
  }

  _ButtonColors _colors(AppPalette palette, bool active) {
    final bool transparentVariant =
        variant == AppButtonVariant.outline ||
        variant == AppButtonVariant.ghost;

    if (!active) {
      return _ButtonColors(
        foreground: palette.textHint,
        background: transparentVariant ? Colors.transparent : palette.border,
        border: variant == AppButtonVariant.outline ? palette.border : null,
      );
    }

    switch (variant) {
      case AppButtonVariant.primary:
        return const _ButtonColors(
          foreground: Colors.white,
          gradient: AppColors.primaryGradient,
          shadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x4D6D4AFF), // violet 30%
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        );
      case AppButtonVariant.tonal:
        return _ButtonColors(
          foreground: palette.isDark
              ? AppColors.primaryLight
              : AppColors.primary,
          background: palette.primarySoft,
        );
      case AppButtonVariant.outline:
        return _ButtonColors(
          foreground: palette.isDark
              ? AppColors.primaryLight
              : AppColors.primary,
          border: palette.isDark ? AppColors.primaryLight : AppColors.primary,
        );
      case AppButtonVariant.danger:
        return const _ButtonColors(
          foreground: Colors.white,
          background: AppColors.coral,
          shadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x40FF5C6C), // coral 25%
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        );
      case AppButtonVariant.ghost:
        return _ButtonColors(
          foreground: palette.isDark
              ? AppColors.primaryLight
              : AppColors.primary,
        );
    }
  }

  void _handleTap() {
    if (haptic) HapticFeedback.lightImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool enabled = onPressed != null && !isLoading;
    final _ButtonDims dims = _dims;
    final _ButtonColors colors = _colors(palette, onPressed != null);
    final BorderRadius radius = BorderRadius.circular(dims.radius);

    final TextStyle labelStyle = AppTextStyles.button.copyWith(
      fontSize: dims.fontSize,
      color: colors.foreground,
    );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          Icon(leadingIcon, size: dims.iconSize, color: colors.foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: dims.iconSize, color: colors.foreground),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, loading' : label,
      onTap: enabled ? _handleTap : null,
      excludeSemantics: true,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: dims.height,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.gradient == null ? colors.background : null,
              gradient: colors.gradient,
              borderRadius: radius,
              border: colors.border != null
                  ? Border.all(color: colors.border!, width: 1.5)
                  : null,
              boxShadow: colors.shadow,
            ),
            child: InkWell(
              onTap: enabled ? _handleTap : null,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.horizontalPadding,
                ),
                child: Center(
                  widthFactor: fullWidth ? null : 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Content ko hide karte hain par jagah rakhte hain, taaki size na badle.
                      Opacity(opacity: isLoading ? 0 : 1, child: content),
                      if (isLoading)
                        SizedBox(
                          width: dims.iconSize,
                          height: dims.iconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            strokeCap: StrokeCap.round,
                            color: colors.foreground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonDims {
  const _ButtonDims({
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
    required this.radius,
  });

  final double height;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double radius;
}

class _ButtonColors {
  const _ButtonColors({
    required this.foreground,
    this.background = Colors.transparent,
    this.gradient,
    this.border,
    this.shadow = const <BoxShadow>[],
  });

  final Color foreground;
  final Color background;
  final Gradient? gradient;
  final Color? border;
  final List<BoxShadow> shadow;
}

/// Round icon button (notification bell, back, scan...). Optional red badge dot.
///
/// ```dart
/// AppIconButton(icon: Icons.notifications_none_rounded, showBadge: true,
///     tooltip: 'Notifications', onPressed: () {})
/// ```
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.showBadge = false,
    this.size = AppSizes.iconButton,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool showBadge;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    Widget button = Semantics(
      button: true,
      label: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: backgroundColor ?? palette.surface,
            shape: CircleBorder(side: BorderSide(color: palette.border)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? palette.textPrimary,
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: size * 0.22,
              right: size * 0.24,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
