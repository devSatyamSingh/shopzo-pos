import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../viewmodel/access_viewmodel.dart';
import 'app_button.dart';
import 'app_colors.dart';
import 'app_error_view.dart';
import 'app_shimmer.dart';
import 'app_text.dart';

/// Section / screen ko permission se guard karta hai.
///
/// ```dart
/// PermissionGuard(
///   permission: PermKey.dashboardView,
///   child: MyScreenBody(),
/// )
/// ```
/// loading -> skeleton, load fail -> retry view, permission nahi -> NoAccessView.
class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.loading,
  });

  final String permission;
  final Widget child;

  /// Custom skeleton (optional).
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (AccessStatus status, bool allowed) = ref.watch(
      accessViewModelProvider.select(
            (AccessState s) => (s.status, s.has(permission)),
      ),
    );
    final AccessViewModel vm = ref.read(accessViewModelProvider.notifier);

    if (status == AccessStatus.loading) {
      return loading ?? const _GuardSkeleton();
    }
    if (status == AccessStatus.error) {
      final Failure failure = ref.read(accessViewModelProvider).failure ??
          const Failure(message: 'Could not load your access. Please try again.');
      return _fit(AppErrorView(failure: failure, onRetry: () => vm.load()));
    }
    if (!allowed) {
      return _fit(NoAccessView(onRefresh: () => vm.refresh()));
    }
    return child;
  }
}

/// Scroll view ke andar (unbounded height) fixed height, warna jaisa hai waisa.
Widget _fit(Widget child) {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) =>
    c.hasBoundedHeight ? child : SizedBox(height: 360, child: child),
  );
}

class NoAccessView extends StatelessWidget {
  const NoAccessView({
    super.key,
    this.title = 'Access restricted',
    this.message =
    "Your role doesn't have permission to use this section. Ask your admin to enable it.",
    this.onRefresh,
  });

  final String title;
  final String message;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
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
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.amber.withAlpha(36)
                      : AppColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(height: 20),
              AppText.h2(title, align: TextAlign.center),
              const SizedBox(height: 8),
              AppText.body(message, align: TextAlign.center, secondary: true),
              if (onRefresh != null) ...<Widget>[
                const SizedBox(height: 24),
                AppButton(
                  label: 'Refresh access',
                  leadingIcon: Icons.refresh_rounded,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  fullWidth: false,
                  onPressed: onRefresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardSkeleton extends StatelessWidget {
  const _GuardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ShimmerBone(height: 150, radius: 22),
          SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: ShimmerBone(height: 84, radius: 16)),
              SizedBox(width: 10),
              Expanded(child: ShimmerBone(height: 84, radius: 16)),
            ],
          ),
        ],
      ),
    );
  }
}