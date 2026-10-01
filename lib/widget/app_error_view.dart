import 'package:flutter/material.dart';

import '../core/errors/failure.dart';
import 'app_button.dart';
import 'app_colors.dart';
import 'app_text.dart';

/// Screen ka data load na ho paye (products, dashboard, history) to ye dikhao.
/// Message wahi hai jo server ne bheja (ya no-internet ka friendly message).
///
/// ```dart
/// if (state.failure != null) {
///   return AppErrorView(failure: state.failure!, onRetry: notifier.load);
/// }
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.palette.isDark;
    final _ErrorLook look = _lookFor(failure.type, isDark);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: look.soft, shape: BoxShape.circle),
                child: Icon(look.icon, size: 40, color: look.color),
              ),
              const SizedBox(height: 20),
              AppText.h2(look.title, align: TextAlign.center),
              const SizedBox(height: 8),
              AppText.body(
                failure.message,
                align: TextAlign.center,
                secondary: true,
              ),
              if (failure.statusCode != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: look.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppText.label(
                    'Error code ${failure.statusCode}',
                    color: look.color,
                  ),
                ),
              ],
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 24),
                AppButton(
                  label: 'Try again',
                  leadingIcon: Icons.refresh_rounded,
                  size: AppButtonSize.medium,
                  fullWidth: false,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ErrorLook _lookFor(FailureType type, bool isDark) {
    Color soft(Color base, Color light) => isDark ? base.withAlpha(36) : light;

    switch (type) {
      case FailureType.noInternet:
        return _ErrorLook(
          icon: Icons.wifi_off_rounded,
          title: 'No internet connection',
          color: AppColors.amber,
          soft: soft(AppColors.amber, AppColors.amberSoft),
        );
      case FailureType.timeout:
        return _ErrorLook(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Request timed out',
          color: AppColors.amber,
          soft: soft(AppColors.amber, AppColors.amberSoft),
        );
      case FailureType.unauthorized:
      case FailureType.forbidden:
        return _ErrorLook(
          icon: Icons.lock_outline_rounded,
          title: type == FailureType.forbidden ? 'Access denied' : 'Unauthorized',
          color: AppColors.coral,
          soft: soft(AppColors.coral, AppColors.coralSoft),
        );
      case FailureType.notFound:
        return _ErrorLook(
          icon: Icons.search_off_rounded,
          title: 'Not found',
          color: AppColors.primary,
          soft: soft(AppColors.primary, AppColors.primarySoft),
        );
      case FailureType.server:
        return _ErrorLook(
          icon: Icons.cloud_off_rounded,
          title: 'Server error',
          color: AppColors.coral,
          soft: soft(AppColors.coral, AppColors.coralSoft),
        );
      case FailureType.badRequest:
      case FailureType.validation:
      case FailureType.conflict:
      case FailureType.tooManyRequests:
      case FailureType.cancelled:
      case FailureType.parsing:
      case FailureType.unknown:
        return _ErrorLook(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          color: AppColors.coral,
          soft: soft(AppColors.coral, AppColors.coralSoft),
        );
    }
  }
}

class _ErrorLook {
  const _ErrorLook({
    required this.icon,
    required this.title,
    required this.color,
    required this.soft,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color soft;
}