import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/model/permission_model.dart';
import 'package:shopzo_pos/model/user_model.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_shimmer.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/permission_guard.dart';

import '../viewmodel/role_permission_viewmodel.dart';

class RolesPermissionsScreen extends ConsumerWidget {
  const RolesPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final bool isAdmin = ref.watch(
      currentUserProvider.select((UserModel? u) => u?.isAdmin ?? false),
    );

    Widget content;
    if (!isAdmin) {
      content = Column(
        children: const <Widget>[
          _TopBar(),
          Expanded(
            child: NoAccessView(
              message: 'Only admins can manage roles and permissions.',
            ),
          ),
        ],
      );
    } else {
      final bool loading = ref.watch(
        rolePermissionsViewModelProvider.select(
          (RolePermissionsState s) => s.isLoading,
        ),
      );
      content = Column(
        children: <Widget>[
          _TopBar(
            onRefresh: loading
                ? null
                : () => ref
                      .read(rolePermissionsViewModelProvider.notifier)
                      .init(silent: true),
          ),
          const Expanded(child: _Body()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m ? 16 : 32, vertical: 10),
          child: ResponsiveCenter(maxWidth: 980, child: content),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        const Expanded(child: AppText.h2('Roles & Permissions', maxLines: 1)),
        if (onRefresh != null)
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: onRefresh,
          ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RolePermissionsState s = ref.watch(rolePermissionsViewModelProvider);
    final RolePermissionsViewModel vm = ref.read(
      rolePermissionsViewModelProvider.notifier,
    );
    final double gap = context.isMobile ? 12 : 16;

    if (s.isLoading) return const _PageSkeleton();

    if (s.sections.isEmpty) {
      return s.failure != null
          ? AppErrorView(failure: s.failure!, onRetry: () => vm.init())
          : const Center(
              child: AppText.body('No POS permissions found.', secondary: true),
            );
    }

    return RefreshIndicator(
      onRefresh: () => vm.init(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, bottom: 32),
        children: <Widget>[
          const AppText.body(
            'Control exactly what each role can see and do in this POS app. Changes apply immediately.',
            secondary: true,
          ),
          SizedBox(height: gap),
          _RoleTabs(selected: s.role, onChanged: vm.selectRole),
          SizedBox(height: gap),
          _SummaryCard(
            state: s,
            onGrant: vm.grantAll,
            onRevoke: () => _revoke(context, vm, s),
          ),
          SizedBox(height: gap),
          if (s.isRoleLoading)
            const _SectionsSkeleton()
          else if (!s.hasRole)
            s.roleFailure != null
                ? _RoleError(
                    message: s.roleFailure!.message,
                    onRetry: vm.reloadRole,
                  )
                : const _SectionsSkeleton()
          else
            for (final PermissionSection sec in s.sections) ...<Widget>[
              _SectionCard(section: sec, state: s, onToggle: vm.toggle),
              SizedBox(height: gap),
            ],
        ],
      ),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    RolePermissionsViewModel vm,
    RolePermissionsState s,
  ) async {
    final bool ok = await _confirm(
      context,
      title: 'Revoke all access?',
      message:
          'All POS permissions will be removed from the ${s.role.label} role. Users with this role will not be able to use the POS until you grant access again.',
      confirmLabel: 'Revoke all',
    );
    if (ok) await vm.revokeAll();
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final AppPalette palette = context.palette;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: AppText.h2(title),
      content: AppText.body(message, secondary: true),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: AppColors.coral),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────

int _columnsFor(double width) => width >= 760 ? 3 : (width >= 440 ? 2 : 1);

IconData _iconOf(String resource) {
  switch (resource) {
    case 'coupon':
      return Icons.local_offer_outlined;
    case 'customer':
      return Icons.people_outline_rounded;
    case 'dashboard':
      return Icons.dashboard_outlined;
    case 'order':
      return Icons.receipt_long_outlined;
    case 'product':
      return Icons.inventory_2_outlined;
    case 'report':
      return Icons.bar_chart_rounded;
    case 'settings':
      return Icons.settings_outlined;
    case 'shift':
      return Icons.schedule_rounded;
    case 'staff':
      return Icons.badge_outlined;
    default:
      return Icons.shield_outlined;
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(m ? 14 : 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: m ? 16 : 24,
            offset: Offset(0, m ? 5 : 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoleTabs extends StatelessWidget {
  const _RoleTabs({required this.selected, required this.onChanged});

  final ManagedRole selected;
  final ValueChanged<ManagedRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final ManagedRole r in ManagedRole.values) ...<Widget>[
            if (r != ManagedRole.values.first) SizedBox(width: m ? 8 : 10),
            Semantics(
              button: true,
              selected: r == selected,
              label: r.label,
              child: GestureDetector(
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: m ? 16 : 20,
                    vertical: m ? 9 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: r == selected ? AppColors.primary : palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: r == selected
                        ? null
                        : Border.all(color: palette.border),
                    boxShadow: r == selected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    r == ManagedRole.admin ? '${r.api} (you)' : r.api,
                    style: TextStyle(
                      fontSize: m ? 12 : 14,
                      fontWeight: r == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: r == selected
                          ? Colors.white
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.onGrant,
    required this.onRevoke,
  });

  final RolePermissionsState state;
  final VoidCallback onGrant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int granted = state.grantedCount;
    final int total = state.total;
    final double fraction = total == 0 ? 0 : granted / total;
    final bool ready = state.hasRole && !state.isRoleLoading;
    final bool busy = state.isBulkBusy;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: AppText.title('Editing ${state.role.label}')),
              AppText.bodyBold(
                ready ? '$granted / $total' : '–',
                color: palette.isDark
                    ? AppColors.primaryLight
                    : AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 2),
          AppText.caption(
            ready
                ? '$granted of $total POS permissions granted'
                : 'Loading permissions…',
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ready ? fraction : 0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? _) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: palette.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Grant all',
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.small,
                  leadingIcon: Icons.verified_user_outlined,
                  isLoading: state.bulkOp == BulkOp.grant,
                  onPressed: (!ready || busy || state.allGranted)
                      ? null
                      : onGrant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Revoke all',
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  leadingIcon: Icons.block_rounded,
                  isLoading: state.bulkOp == BulkOp.revoke,
                  onPressed: (!ready || busy || state.noneGranted)
                      ? null
                      : onRevoke,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.state,
    required this.onToggle,
  });

  final PermissionSection section;
  final RolePermissionsState state;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent = palette.isDark
        ? AppColors.primaryLight
        : AppColors.primary;
    final int on = section.items
        .where((PermissionModel p) => state.current.contains(p.key))
        .length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_iconOf(section.group.id), size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(child: AppText.title(section.group.title, maxLines: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$on/${section.items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final int cols = _columnsFor(box.maxWidth);
              final double w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final PermissionModel p in section.items)
                    SizedBox(
                      width: w,
                      child: _PermTile(
                        perm: p,
                        granted: state.current.contains(p.key),
                        busy: state.isBusy(p.key),
                        enabled: !state.isBulkBusy && !state.isBusy(p.key),
                        onTap: () => onToggle(p.key),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.perm,
    required this.granted,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final PermissionModel perm;
  final bool granted;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final bool m = context.isMobile;
    final Color accent = dark ? AppColors.primaryLight : AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: granted
            ? (dark
                  ? AppColors.primary.withAlpha(30)
                  : AppColors.primarySoft.withValues(alpha: 0.6))
            : palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: granted ? accent.withValues(alpha: 0.55) : palette.border,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: m ? 10 : 12,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: AppText.bodyBold(perm.key, maxLines: 1),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              'POS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (perm.description.isNotEmpty)
                        AppText.caption(perm.description, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 30,
                  child: busy
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              strokeCap: StrokeCap.round,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Switch(
                            value: granted,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: enabled ? (_) => onTap() : null,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleError extends StatelessWidget {
  const _RoleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.coral),
          const SizedBox(height: 10),
          AppText.body(message, align: TextAlign.center, secondary: true),
          const SizedBox(height: 14),
          AppButton(
            label: 'Try again',
            leadingIcon: Icons.refresh_rounded,
            size: AppButtonSize.small,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Skeletons ────────────────────────────────────────────────────────────────

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    final double gap = context.isMobile ? 12 : 16;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 14, bottom: 32),
      children: <Widget>[
        const AppShimmer(child: ShimmerBone(width: 280, height: 12)),
        SizedBox(height: gap),
        const AppShimmer(
          child: Row(
            children: <Widget>[
              ShimmerBone(width: 110, height: 38, radius: 100),
              SizedBox(width: 8),
              ShimmerBone(width: 92, height: 38, radius: 100),
              SizedBox(width: 8),
              ShimmerBone(width: 92, height: 38, radius: 100),
            ],
          ),
        ),
        SizedBox(height: gap),
        const _Card(
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShimmerBone(width: 130, height: 14),
                SizedBox(height: 8),
                ShimmerBone(width: 190, height: 10),
                SizedBox(height: 14),
                ShimmerBone(height: 8, radius: 100),
                SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(child: ShimmerBone(height: 40, radius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: ShimmerBone(height: 40, radius: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        const _SectionsSkeleton(),
      ],
    );
  }
}

class _SectionsSkeleton extends StatelessWidget {
  const _SectionsSkeleton({this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    final double gap = context.isMobile ? 12 : 16;
    return Column(
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: _Card(
              child: AppShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ShimmerBone(width: 150, height: 14),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        final int cols = _columnsFor(box.maxWidth);
                        final double w =
                            (box.maxWidth - 10 * (cols - 1)) / cols;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            for (int j = 0; j < (i == 0 ? 4 : 2); j++)
                              ShimmerBone(width: w, height: 58, radius: 12),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
