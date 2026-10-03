import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

/// Popup / dialog ka common card: round corner, soft shadow, andar scroll
/// (chhoti screen ya keyboard khulne par content scroll hota hai).
class ShiftCardShell extends StatelessWidget {
  const ShiftCardShell({super.key, required this.child, this.maxWidth = 460});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final BorderRadius radius = BorderRadius.circular(AppRadius.sheet);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: radius,
          border: Border.all(color: palette.border.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gol icon (card ke upar).
class ShiftHeaderIcon extends StatelessWidget {
  const ShiftHeaderIcon({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 60,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Server ka error inline dikhane ke liye (bubble ke saath).
class ShiftErrorBanner extends StatelessWidget {
  const ShiftErrorBanner({super.key, required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.coral.withAlpha(36) : AppColors.coralSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.coral.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              color: AppColors.coral, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppText.bodyBold(message, color: AppColors.coral),
                if (statusCode != null)
                  AppText.caption('Error code $statusCode', secondary: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Label ........ value" row.
class ShiftInfoRow extends StatelessWidget {
  const ShiftInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          AppText.body(label, secondary: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (bold ? AppTextStyles.bodyBold : AppTextStyles.body)
                  .copyWith(
                color: valueColor ?? context.palette.textPrimary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info rows ka rounded group (soft background).
class ShiftInfoGroup extends StatelessWidget {
  const ShiftInfoGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppText.label(title.toUpperCase()),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

/// Chhota stat tile (icon + label + value).
class ShiftStatTile extends StatelessWidget {
  const ShiftStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppText.caption(label, maxLines: 1),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppText.bodyBold(value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiles ko 2 column me lagata hai (odd number ho to aakhri adha width).
class ShiftStatGrid extends StatelessWidget {
  const ShiftStatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        const double gap = 10;
        final double width = (box.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

/// Cash match / extra / short ka pill.
/// Server ka rule: positive = extra cash, negative = shortfall.
class CashDifferenceBadge extends StatelessWidget {
  const CashDifferenceBadge({super.key, required this.difference});

  final double difference;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final bool matched = difference.abs() < 0.005;
    final bool extra = difference > 0;

    final Color color = matched
        ? (dark ? AppColors.mint : AppColors.mintDark)
        : extra
        ? const Color(0xFFE08A00)
        : AppColors.coral;
    final IconData icon = matched
        ? Icons.check_circle_rounded
        : extra
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final String text = matched
        ? 'Cash matched'
        : extra
        ? 'Extra ${FormatUtils.inr(difference)}'
        : 'Short ${FormatUtils.inr(difference.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard shift strip (real shift data)
// ═══════════════════════════════════════════════════════════════════════════

/// Dashboard ke upar: "Shift open since 09:30 AM ........ Register ₹1,000".
/// Dashboard ka purana `_ShiftStrip` aur `_Placeholder` hata kar ise lagao.
class ShiftStrip extends ConsumerWidget {
  const ShiftStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final ShiftState s = ref.watch(shiftViewModelProvider);

    final bool open = s.hasOpenShift;
    final bool checking = s.phase == ShiftPhase.checking;

    final Color tint = open ? AppColors.mint : AppColors.amber;
    final String text = open
        ? 'Shift open since ${FormatUtils.since(s.shift!.openedAt)}'
        : checking
        ? 'Checking your shift…'
        : 'No active shift';
    final double fontSize = m ? 12 : 14;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m ? 14 : 18,
        vertical: m ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: palette.isDark
            ? tint.withAlpha(30)
            : (open ? AppColors.mintSoft : AppColors.amberSoft),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: fontSize,
                color: palette.textPrimary,
              ),
            ),
          ),
          if (open) ...<Widget>[
            Text(
              'Register ',
              style: AppTextStyles.body.copyWith(
                fontSize: fontSize,
                color: palette.textSecondary,
              ),
            ),
            Text(
              FormatUtils.inr(s.shift!.openingCash),
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: fontSize,
                color: palette.isDark ? AppColors.mint : AppColors.mintDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}