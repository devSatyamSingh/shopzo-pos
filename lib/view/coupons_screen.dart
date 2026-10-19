import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/coupon_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_shimmer.dart';
import 'package:shopzo_pos/widget/app_text.dart';

import '../viewmodel/coupons_viewmodel.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  @override
  void initState() {
    super.initState();
    // Screen khulte hi fresh data laao.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(couponViewModelProvider.notifier).load();
    });
  }

  Future<void> _refresh() {
    return ref.read(couponViewModelProvider.notifier).load(silent: true);
  }

  void _reload() => ref.read(couponViewModelProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final CouponState state = ref.watch(couponViewModelProvider);
    final double gap = m ? 12 : 16;

    Widget body;
    switch (state.status) {
      case CouponLoadStatus.loading:
        body = const _CouponSkeleton();
      case CouponLoadStatus.error:
        body = AppErrorView(
          failure:
          state.failure ??
              const Failure(message: 'Something went wrong. Please try again.'),
          onRetry: _reload,
        );
      case CouponLoadStatus.ready:
        body = state.isEmpty
            ? _EmptyView(onRefresh: _refresh, onReload: _reload)
            : RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: state.coupons.length,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (BuildContext context, int i) =>
                _CouponCard(coupon: state.coupons[i]),
          ),
        );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m ? 16 : 32),
          child: ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: AppText.h2('Coupons')),
                  ],
                ),
                SizedBox(height: gap),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Coupon card
// ─────────────────────────────────────────────────────────────────────────

class _StatusLook {
  const _StatusLook({
    required this.label,
    required this.color,
    required this.soft,
  });

  final String label;
  final Color color;
  final Color soft;
}

_StatusLook _lookOf(CouponStatus status, AppPalette palette) {
  final bool dark = palette.isDark;
  switch (status) {
    case CouponStatus.active:
      return _StatusLook(
        label: 'Active',
        color: dark ? AppColors.mint : AppColors.mintDark,
        soft: dark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft,
      );
    case CouponStatus.expired:
      return _StatusLook(
        label: 'Expired',
        color: AppColors.coral,
        soft: dark ? AppColors.coral.withAlpha(36) : AppColors.coralSoft,
      );
    case CouponStatus.usedUp:
      return _StatusLook(
        label: 'Used up',
        color: dark ? AppColors.amber : const Color(0xFFE08A00),
        soft: dark ? AppColors.amber.withAlpha(36) : AppColors.amberSoft,
      );
    case CouponStatus.inactive:
      return _StatusLook(
        label: 'Inactive',
        color: palette.textSecondary,
        soft: palette.surfaceAlt,
      );
  }
}

String _trimNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

String _badgeText(CouponModel c) =>
    c.isPercentage ? '${_trimNum(c.value)}%' : FormatUtils.inr(c.value);

String _description(CouponModel c) {
  final String off = c.isPercentage
      ? 'Get ${_trimNum(c.value)}% off'
      : 'Flat ${FormatUtils.inr(c.value)} off';
  final String min = c.minOrderValue > 0
      ? ' on orders above ${FormatUtils.inr(c.minOrderValue)}'
      : ' on any order';
  return '$off$min';
}

String _expiryText(CouponModel c) {
  if (c.expiresAt == null) return 'No expiry';
  final String d = FormatUtils.date(c.expiresAt);
  return c.isExpired ? 'Expired $d' : 'Valid till $d';
}

String _usageText(CouponModel c) =>
    c.maxUses > 0 ? 'Used ${c.usedCount}/${c.maxUses}' : 'Used ${c.usedCount}';

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final CouponModel coupon;

  void _copy() {
    Clipboard.setData(ClipboardData(text: coupon.code));
    HapticFeedback.lightImpact();
    AppUtils.showSuccess('Code ${coupon.code} copied');
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final _StatusLook look = _lookOf(coupon.status, palette);
    final bool active = coupon.isUsable;

    final Color badgeColor = active
        ? (palette.isDark ? AppColors.primaryLight : AppColors.primary)
        : look.color;
    final Color badgeSoft = active ? palette.primarySoft : look.soft;
    final double badge = m ? 58 : 66;

    return Opacity(
      opacity: active ? 1 : 0.72,
      child: Container(
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
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.card,
            onTap: _copy,
            child: Padding(
              padding: EdgeInsets.all(m ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: badge,
                        height: badge,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AppText.bodyBold(
                                _badgeText(coupon),
                                color: badgeColor,
                              ),
                              AppText.label('OFF', color: badgeColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AppText.title(coupon.code, maxLines: 1),
                            const SizedBox(height: 2),
                            AppText.caption(_description(coupon), maxLines: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(look: look),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: palette.border),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: <Widget>[
                            _Meta(
                              icon: Icons.shopping_bag_outlined,
                              text: coupon.minOrderValue > 0
                                  ? 'Min ${FormatUtils.inr(coupon.minOrderValue)}'
                                  : 'No minimum',
                            ),
                            _Meta(
                              icon: Icons.confirmation_number_outlined,
                              text: _usageText(coupon),
                            ),
                            _Meta(
                              icon: Icons.event_outlined,
                              text: _expiryText(coupon),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: palette.textHint,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.look});

  final _StatusLook look;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: look.soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: AppText.label(look.label, color: look.color),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: context.palette.textHint),
        const SizedBox(width: 4),
        AppText.caption(text),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Loading + empty states
// ─────────────────────────────────────────────────────────────────────────

class _CouponSkeleton extends StatelessWidget {
  const _CouponSkeleton();

  @override
  Widget build(BuildContext context) {
    final double gap = context.isMobile ? 12 : 16;

    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (_, _) => const ShimmerBone(
          width: double.infinity,
          height: 128,
          radius: 20,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh, required this.onReload});

  final Future<void> Function() onRefresh;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final Color color = dark ? AppColors.primaryLight : AppColors.primary;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.palette.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_offer_outlined,
                          size: 40,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AppText.h2('No coupons yet', align: TextAlign.center),
                      const SizedBox(height: 8),
                      const AppText.body(
                        'Coupons created by your admin will show up here.',
                        align: TextAlign.center,
                        secondary: true,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Refresh',
                        leadingIcon: Icons.refresh_rounded,
                        variant: AppButtonVariant.tonal,
                        size: AppButtonSize.medium,
                        fullWidth: false,
                        onPressed: onReload,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}