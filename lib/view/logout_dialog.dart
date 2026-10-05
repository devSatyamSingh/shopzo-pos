import 'package:flutter/material.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';

Future<bool?> showLogoutDialog(
    BuildContext context, {
      required Future<void> Function() onConfirm,
    }) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Logout',
    barrierColor: AppColors.overlay,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
        _LogoutDialog(onConfirm: onConfirm),
    transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim,
        Animation<double> secondary,
        Widget child,
        ) {
      final Animation<double> pop = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(pop),
          child: child,
        ),
      );
    },
  );
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _loading = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppUtils.showError('Logout failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;

    return PopScope(
      canPop: !_loading, // loading ke time back se band nahi hoga
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                border: Border.all(color: palette.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Bubble icon + pulse rings
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        for (final double delay in const <double>[0, 0.5])
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (BuildContext context, Widget? _) {
                              final double t = (_pulse.value + delay) % 1;
                              return Opacity(
                                opacity: (1 - t) * 0.35,
                                child: Container(
                                  width: 64 + 56 * t,
                                  height: 64 + 56 * t,
                                  decoration: const BoxDecoration(
                                    color: AppColors.coral,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (BuildContext context, double v, Widget? _) {
                            return Transform.scale(
                              scale: v,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF3A2230)
                                      : AppColors.coralSoft,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.coral.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  size: 32,
                                  color: AppColors.coral,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AppText.h2('Logout?', align: TextAlign.center),
                  const SizedBox(height: 8),
                  AppText.body(
                    _loading
                        ? 'Logging you out…'
                        : "You'll be logged out of this device. You'll need to log in again.",
                    align: TextAlign.center,
                    secondary: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.medium,
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Logout',
                          variant: AppButtonVariant.danger,
                          size: AppButtonSize.medium,
                          isLoading: _loading,
                          onPressed: _confirm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}