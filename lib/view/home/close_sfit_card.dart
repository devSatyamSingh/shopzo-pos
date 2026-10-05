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
import 'package:shopzo_pos/widget/app_loader.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textfield.dart';

Future<void> showCloseShiftDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.overlay,
    builder: (BuildContext context) => const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(16),
      child: CloseShiftCard(),
    ),
  );
}

class CloseShiftCard extends ConsumerStatefulWidget {
  const CloseShiftCard({super.key});

  @override
  ConsumerState<CloseShiftCard> createState() => _CloseShiftCardState();
}

class _CloseShiftCardState extends ConsumerState<CloseShiftCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cash = TextEditingController();

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

  double? get _counted =>
      double.tryParse(_cash.text.replaceAll(',', '').trim());

  Future<void> _submit() async {
    AppUtils.hideKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final double? amount = _counted;
    if (amount == null) return;

    final ApiResult<Shift> result = await ref
        .read(shiftViewModelProvider.notifier)
        .closeShift(amount);
    AppUtils.showResult(result, successFallback: 'Shift closed');

    if (!mounted) return;
    if (result.isSuccess) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftState s = ref.watch(shiftViewModelProvider);
    final Shift? shift = s.shift;
    if (shift == null) return const SizedBox.shrink();

    final ShiftSummary? summary = s.summary;
    final bool busy = s.isSubmitting;
    final double? counted = _counted;
    final double? expected = summary?.estimatedCash(shift);

    return PopScope(
      canPop: !busy,
      child: ShiftCardShell(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Center(
                child: ShiftHeaderIcon(
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 16),
              const AppText.h2('End your shift?', align: TextAlign.center),
              const SizedBox(height: 6),
              const AppText.body(
                'Count the cash in your drawer and enter it to close the shift.',
                align: TextAlign.center,
                secondary: true,
              ),
              const SizedBox(height: 18),
              ShiftInfoGroup(
                title: 'This shift',
                children: <Widget>[
                  ShiftInfoRow(
                    label: 'Opened',
                    value: FormatUtils.dateTime(shift.openedAt),
                  ),
                  ShiftInfoRow(
                    label: 'Duration',
                    value: FormatUtils.duration(shift.duration),
                  ),
                  ShiftInfoRow(
                    label: 'Opening cash',
                    value: FormatUtils.inr(shift.openingCash),
                    bold: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SalesBlock(
                state: s,
                shift: shift,
                onRetry: () =>
                    ref.read(shiftViewModelProvider.notifier).loadSummary(),
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
              const SizedBox(height: 18),

              AppTextField.amount(
                controller: _cash,
                label: 'Counted cash (₹)',
                hint: '0',
                autofocus: false,
                validator: Validators.amount(
                  fieldName: 'Counted cash',
                  allowZero: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: (counted != null && expected != null)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: <Widget>[
                            CashDifferenceBadge(difference: counted - expected),
                            const SizedBox(height: 6),
                            const AppText.caption(
                              'Estimate. The final difference is calculated by the server.',
                              align: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 20),

              AppButton(
                label: 'End shift',
                variant: AppButtonVariant.danger,
                leadingIcon: Icons.logout_rounded,
                isLoading: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 6),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.medium,
                onPressed: busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final bool dark = context.palette.isDark;

    if (summary == null) {
      if (state.summaryFailure != null) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.amber,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: AppText.body(
                  'Could not load sales. You can still close the shift.',
                  secondary: true,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AppLoader(size: 18, strokeWidth: 2.4),
            SizedBox(width: 10),
            AppText.body('Calculating shift sales…', secondary: true),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ShiftStatGrid(
          children: <Widget>[
            ShiftStatTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Total sales',
              value: FormatUtils.inr(summary.totalSales),
              color: AppColors.primary,
            ),
            ShiftStatTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Orders',
              value: '${summary.orderCount}',
              color: dark ? AppColors.sky : const Color(0xFF0E9FC4),
            ),
            ShiftStatTile(
              icon: Icons.payments_outlined,
              label: 'Cash sales',
              value: FormatUtils.inr(summary.cashSales),
              color: dark ? AppColors.mint : AppColors.mintDark,
            ),
            ShiftStatTile(
              icon: Icons.qr_code_2_rounded,
              label: 'UPI sales',
              value: FormatUtils.inr(summary.upiSales),
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
        ShiftInfoGroup(
          title: 'Cash drawer',
          children: <Widget>[
            ShiftInfoRow(
              label: 'Expected cash (approx.)',
              value: FormatUtils.inr(summary.estimatedCash(shift)),
              bold: true,
            ),
          ],
        ),
      ],
    );
  }
}
