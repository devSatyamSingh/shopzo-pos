import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/shift_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/validators.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_loader.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textfield.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  const CloseShiftDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const CloseShiftDialog(),
    );
  }

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cash = TextEditingController();
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(shiftViewModelProvider.notifier).loadSummary(),
    );
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  double? get _entered =>
      double.tryParse(_cash.text.replaceAll(',', '').trim());
  void _closeDialog() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    AppUtils.hideKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final double? amount = _entered;
    if (amount == null) return;

    final ApiResult<Shift> result = await ref
        .read(shiftViewModelProvider.notifier)
        .closeShift(amount);
    AppUtils.showResult(result, successFallback: 'Shift closed');
    if (result.isSuccess) _closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftState s = ref.watch(shiftViewModelProvider);
    final Shift? shift = s.shift;
    if (shift == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeDialog());
      return const SizedBox.shrink();
    }

    final ShiftSummary? summary = s.summary;
    final double? expected = summary?.estimatedCash(shift);
    final double? entered = _entered;
    final bool busy = s.isSubmitting;

    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ShiftCardShell(
          maxWidth: 480,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Header(onClose: busy ? null : _closeDialog),
                const SizedBox(height: 18),
                ShiftInfoGroup(
                  title: 'Shift time',
                  children: <Widget>[
                    ShiftInfoRow(
                      label: 'Opened',
                      value: FormatUtils.dateTime(shift.openedAt),
                    ),
                    ShiftInfoRow(
                      label: 'Open for',
                      value: FormatUtils.duration(shift.duration),
                    ),
                    ShiftInfoRow(
                      label: 'Opening cash',
                      value: FormatUtils.inr(shift.openingCash),
                      bold: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SalesBlock(
                  state: s,
                  shift: shift,
                  onRetry: () =>
                      ref.read(shiftViewModelProvider.notifier).loadSummary(),
                ),
                const SizedBox(height: 18),
                AppTextField.amount(
                  controller: _cash,
                  label: 'Counted cash in drawer (₹)',
                  hint: expected == null
                      ? '0'
                      : 'Expected ${FormatUtils.inr(expected)}',
                  validator: Validators.amount(
                    fieldName: 'Closing cash',
                    allowZero: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                // Live: cash match / extra / short.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  child: (entered != null && expected != null)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CashDifferenceBadge(
                              difference: entered - expected,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  alignment: Alignment.topCenter,
                  child: s.failure != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ShiftErrorBanner(
                            message: s.failure!.message,
                            statusCode: s.failure!.statusCode,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.outline,
                        onPressed: busy ? null : _closeDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Close shift',
                        variant: AppButtonVariant.danger,
                        isLoading: busy,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Row(
      children: <Widget>[
        const ShiftHeaderIcon(
          icon: Icons.power_settings_new_rounded,
          color: AppColors.coral,
          size: 48,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppText.h2('End shift'),
              SizedBox(height: 2),
              AppText.caption('Review sales and count your drawer'),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Cancel',
          icon: Icon(Icons.close_rounded, color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// Is shift ki sales: loading me shimmer, fail me retry, success me total + tiles.
class _SalesBlock extends StatelessWidget {
  const _SalesBlock({
    required this.state,
    required this.shift,
    required this.onRetry,
  });

  final ShiftState state;
  final Shift shift;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ShiftSummary? summary = state.summary;

    if (state.isSummaryLoading) return const _SalesSkeleton();

    if (state.summaryFailure != null) {
      return _SummaryError(failure: state.summaryFailure!, onRetry: onRetry);
    }
    if (summary == null) return const SizedBox.shrink();

    final bool dark = context.palette.isDark;
    final Color upi = dark ? AppColors.sky : const Color(0xFF0E9FC4);

    final List<Widget> tiles = <Widget>[
      ShiftStatTile(
        icon: Icons.shopping_bag_outlined,
        label: 'Orders',
        value: '${summary.orderCount}',
        color: AppColors.primary,
      ),
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
        color: upi,
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
      if (summary.otherSales > 0)
        ShiftStatTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Other',
          value: FormatUtils.inr(summary.otherSales),
          color: AppColors.primary,
        ),
      if (summary.refundCount > 0)
        ShiftStatTile(
          icon: Icons.reply_rounded,
          label: 'Refunds (${summary.refundCount})',
          value: FormatUtils.inr(summary.refundTotal),
          color: AppColors.coral,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Total sales hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Total sales this shift',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: summary.totalSales),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double v, Widget? _) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FormatUtils.inr(v, decimals: v % 1 != 0),
                      style: AppTextStyles.hero.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.orderCount} orders  •  Avg ${FormatUtils.inr(summary.avgOrderValue)}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShiftStatGrid(children: tiles),
        const SizedBox(height: 12),
        ShiftInfoGroup(
          title: 'Cash drawer',
          children: <Widget>[
            ShiftInfoRow(
              label: 'Opening cash',
              value: FormatUtils.inr(shift.openingCash),
            ),
            ShiftInfoRow(
              label: '+ Cash sales',
              value: FormatUtils.inr(summary.cashSales),
            ),
            ShiftInfoRow(
              label: 'Expected in drawer',
              value: FormatUtils.inr(summary.estimatedCash(shift)),
              bold: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _SalesSkeleton extends StatelessWidget {
  const _SalesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppSkeleton(height: 104, radius: 20),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double w = (box.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (int i = 0; i < 4; i++)
                  AppSkeleton(width: w, height: 58, radius: 16),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const AppSkeleton(height: 96, radius: 16),
      ],
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.amber.withAlpha(30) : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE08A00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppText.bodyBold('Could not load this shift\'s sales'),
                const SizedBox(height: 2),
                AppText.caption(
                  '${failure.message} You can still close the shift.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Retry',
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.small,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
