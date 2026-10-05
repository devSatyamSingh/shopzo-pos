import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopzo_pos/model/user_model.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/role_permission_screen.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';

import '../core/constants/session_reset.dart';
import '../core/routes/route_name.dart';
import '../model/permission_model.dart';
import '../viewmodel/access_viewmodel.dart';
import '../widget/app_shimmer.dart';
import 'cms_screen.dart';
import 'logout_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    final GoRouter router = GoRouter.of(context);
    final ProviderContainer container =
    ProviderScope.containerOf(context, listen: false);
    final AuthViewModel authVm = ref.read(authViewModelProvider.notifier);

    final bool? done = await showLogoutDialog(
      context,
      onConfirm: () => authVm.logout(),
    );
    if (done != true) return;

    nav.popUntil((Route<dynamic> r) => r.isFirst);
    router.go(AppRoutes.login);

    WidgetsBinding.instance.addPostFrameCallback(
          (_) => resetSessionProviders(container),
    );
  }
  void _openCms(BuildContext context, String title, String slug) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CmsPage(title: title, slug: slug),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final UserModel? user = ref.watch(currentUserProvider);
    final double gap = m ? 12 : 16;

    final String name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'User';
    final String role = (user?.roleName.trim().isNotEmpty ?? false)
        ? user!.roleName.trim().toUpperCase()
        : 'USER';

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: m ? 16 : 32,
            vertical: 10,
          ),
          child: ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Top bar
                Row(
                  children: <Widget>[
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    const AppText.h2('My Profile'),
                  ],
                ),
                SizedBox(height: gap),

                _ProfileHeroCard(name: name, role: role),
                SizedBox(height: gap),

                _SectionCard(
                  title: 'Role & Permissions',
                  icon: Icons.verified_user_outlined,
                  child: _PermissionsWrap(role: role),
                ),
                SizedBox(height: gap),

                _SectionCard(
                  title: 'More',
                  icon: Icons.apps_rounded,
                  padding: EdgeInsets.symmetric(
                    horizontal: m ? 6 : 10,
                    vertical: m ? 4 : 6,
                  ),
                  child: Column(
                    children: <Widget>[
                      if (user?.isAdmin ?? false) ...<Widget>[
                        _CmsTile(
                          icon: Icons.admin_panel_settings_outlined,
                          color: AppColors.mintDark,
                          soft: AppColors.mintSoft,
                          title: 'Roles & Permissions',
                          subtitle: 'Control what each role can do',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RolesPermissionsScreen(),
                            ),
                          ),
                        ),
                        const _TileDivider(),
                      ],
                      _CmsTile(
                        icon: Icons.description_outlined,
                        color: AppColors.primary,
                        soft: AppColors.primarySoft,
                        title: 'Terms & Conditions',
                        subtitle: 'Usage rules and policies',
                        onTap: () => _openCms(
                            context, 'Terms & Conditions', 'terms-and-conditions'),
                      ),
                      const _TileDivider(),
                      _CmsTile(
                        icon: Icons.info_outline_rounded,
                        color: const Color(0xFF0E9FC4),
                        soft: AppColors.skySoft,
                        title: 'About Us',
                        subtitle: 'Know more about Pulse POS',
                        onTap: () =>
                            _openCms(context, 'About Us', 'about-us'),
                      ),
                      const _TileDivider(),
                      _CmsTile(
                        icon: Icons.headset_mic_outlined,
                        color: const Color(0xFFE08A00),
                        soft: AppColors.amberSoft,
                        title: 'Help & Support',
                        subtitle: 'Get help, contact our team',
                        onTap: () => _openCms(
                            context, 'Help & Support', 'help-and-support'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: m ? 20 : 28),

                AppButton(
                  label: 'Logout',
                  variant: AppButtonVariant.danger,
                  leadingIcon: Icons.logout_rounded,
                  onPressed: () => _logout(context, ref),
                ),
                const SizedBox(height: 16),
                Center(
                  child: AppText.caption('Pulse POS • v1.0.0'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    final double avatar = m ? 76 : 96;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: m ? 22 : 30,
        horizontal: m ? 16 : 24,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(m ? 22 : AppRadius.xxl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: m ? 18 : 24,
            offset: Offset(0, m ? 7 : 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: m ? 30 : 38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: m ? 12 : 16),
          AppText.h1(
            name,
            color: Colors.white,
            align: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AppText.label(role, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.padding,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(m ? 14 : 20, m ? 14 : 20, m ? 14 : 20, 0),
            child: Row(
              children: <Widget>[
                Icon(icon,
                    size: m ? 18 : 20,
                    color: palette.isDark
                        ? AppColors.primaryLight
                        : AppColors.primary),
                const SizedBox(width: 8),
                AppText.title(title),
              ],
            ),
          ),
          Padding(
            padding: padding ?? EdgeInsets.all(m ? 14 : 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PermissionsWrap extends ConsumerWidget {
  const _PermissionsWrap({required this.role});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final AccessState access = ref.watch(accessViewModelProvider);
    final Color tone = palette.isDark ? AppColors.mint : AppColors.mintDark;

    final List<PermissionModel> granted = access.posItems;
    Widget content;
    switch (access.status) {
      case AccessStatus.loading:
        content = AppShimmer(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < 5; i++)
                ShimmerBone(
                  width: 90.0 + (i % 3) * 24,
                  height: m ? 28 : 32,
                  radius: 100,
                ),
            ],
          ),
        );
      case AccessStatus.error:
        content = Row(
          children: <Widget>[
            const Expanded(
              child: AppText.body('Could not load permissions.', secondary: true),
            ),
            TextButton(
              onPressed: () => ref.read(accessViewModelProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        );
      case AccessStatus.ready:
        content = granted.isEmpty
            ? const AppText.body('No permissions assigned', secondary: true)
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final PermissionModel p in granted)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: m ? 10 : 12,
                  vertical: m ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? AppColors.mint.withAlpha(36)
                      : AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.check_circle_rounded,
                        size: m ? 14 : 16, color: tone),
                    const SizedBox(width: 6),
                AppText.body(p.label, color: tone),
                  ],
                ),
              ),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const AppText.body('Role: ', secondary: true),
            AppText.bodyBold(role),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}
class _CmsTile extends StatelessWidget {
  const _CmsTile({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: m ? 8 : 10,
            vertical: m ? 8 : 10,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: m ? 40 : 46,
                height: m ? 40 : 46,
                decoration: BoxDecoration(
                  color: palette.isDark ? color.withAlpha(36) : soft,
                  borderRadius: BorderRadius.circular(m ? 12 : 14),
                ),
                child: Icon(icon, color: color, size: m ? 20 : 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppText.bodyBold(title, maxLines: 1),
                    AppText.caption(subtitle, maxLines: 1),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      endIndent: 8,
      color: context.palette.border,
    );
  }
}