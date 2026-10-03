import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/model/shift_model.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

/// Shift band hone ke turant baad dikhta hai: final report.
/// Opened / closed date-time, duration, sales, aur cash ka hisaab (server ke
/// expectedCash aur discrepancy ke saath). "Done" par Open Shift popup aata hai.
class ShiftClosedReport extends ConsumerWidget {
  const ShiftClosedReport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShiftState s = ref.watch(shiftViewModelProvider);
    final Shift? shift = s.closedShift;
    if (shift == null) return const SizedBox.shrink();

    final ShiftSummary? summary = s.closedSummary;
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final double? difference = shift.difference;
    final Color diffColor = difference == null || difference.abs() < 0.005
        ? (dark ? AppColors.mint : AppColors.mintDark)
        : difference > 0
        ? const Color(0xFFE08A00)
        : AppColors.coral;

    return ShiftCardShell(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (BuildContext context, double t, Widget? child) {
                return Transform.scale(scale: t.clamp(0.0, 1.2), child: child);
              },
              child: const ShiftHeaderIcon(
                icon: Icons.check_rounded,
                color: AppColors.mintDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AppText.h2('Shift closed', align: TextAlign.center),
          const SizedBox(height: 6),
          AppText.body(
            'Here is your shift report.',
            align: TextAlign.center,
            secondary: true,
          ),
          const SizedBox(height: 18),

          // Sales (agar load ho paye the)
          if (summary != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Total sales',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            FormatUtils.inr(summary.totalSales),
                            style: AppTextStyles.hero
                                .copyWith(color: Colors.white, fontSize: 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${summary.orderCount}',
                        style: AppTextStyles.h1.copyWith(color: Colors.white),
                      ),
                      Text(
                        summary.orderCount == 1 ? 'order' : 'orders',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShiftStatGrid(
              children: <Widget>[
                ShiftStatTile(
                  icon: Icons.payments_outlined,
                  label: 'Cash sales',
                  value: FormatUtils.inr(summary.cashSales),
                  color: AppColors.primary,
                ),
                ShiftStatTile(
                  icon: Icons.qr_code_2_rounded,
                  label: 'UPI sales',
                  value: FormatUtils.inr(summary.upiSales),
                  color: dark ? AppColors.sky : const Color(0xFF0E9FC4),
                ),
                if (summary.cardSales > 0)
                  ShiftStatTile(
                    icon: Icons.credit_card_rounded,
                    label: 'Card sales',
                    value: FormatUtils.inr(summary.cardSales),
                    color: dark ? AppColors.mint : AppColors.mintDark,
                  ),
                if (summary.codSales > 0)
                  ShiftStatTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'COD',
                    value: FormatUtils.inr(summary.codSales),
                    color: const Color(0xFFE08A00),
                  ),
                if (summary.refundCount > 0)
                  ShiftStatTile(
                    icon: Icons.reply_rounded,
                    label: 'Refunds (${summary.refundCount})',
                    value: FormatUtils.inr(summary.refundTotal),
                    color: AppColors.coral,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          ShiftInfoGroup(
            title: 'Shift time',
            children: <Widget>[
              ShiftInfoRow(
                label: 'Opened',
                value: FormatUtils.dateTime(shift.openedAt),
              ),
              ShiftInfoRow(
                label: 'Closed',
                value: FormatUtils.dateTime(shift.closedAt),
              ),
              ShiftInfoRow(
                label: 'Duration',
                value: FormatUtils.duration(shift.duration),
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShiftInfoGroup(
            title: 'Cash drawer',
            children: <Widget>[
              ShiftInfoRow(
                label: 'Opening cash',
                value: FormatUtils.inr(shift.openingCash),
              ),
              ShiftInfoRow(
                label: 'Expected cash',
                value: FormatUtils.inr(shift.expectedCash),
              ),
              ShiftInfoRow(
                label: 'Counted cash',
                value: FormatUtils.inr(shift.closingCash),
                bold: true,
              ),
              if (difference != null)
                ShiftInfoRow(
                  label: 'Difference',
                  value: FormatUtils.signedInr(difference),
                  valueColor: diffColor,
                  bold: true,
                ),
            ],
          ),
          if (difference != null) ...<Widget>[
            const SizedBox(height: 12),
            Center(child: CashDifferenceBadge(difference: difference)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Done',
            leadingIcon: Icons.done_all_rounded,
            onPressed: () =>
                ref.read(shiftViewModelProvider.notifier).dismissClosedReport(),
          ),
          const SizedBox(height: 6),
          AppButton(
            label: 'Logout',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.medium,
            onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}