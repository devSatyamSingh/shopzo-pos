import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/shift_model.dart';
import 'package:shopzo_pos/model/user_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/validators.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textfield.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

/// Login ke baad, agar koi shift open nahi hai to ye popup dikhta hai
/// (admin, manager, cashier sabke liye). Opening cash daalkar shift start hoti hai.
class OpenShiftCard extends ConsumerStatefulWidget {
  const OpenShiftCard({super.key});

  @override
  ConsumerState<OpenShiftCard> createState() => _OpenShiftCardState();
}

class _OpenShiftCardState extends ConsumerState<OpenShiftCard> {
  static const List<int> _quickAmounts = <int>[500, 1000, 2000, 5000];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cash = TextEditingController();

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    AppUtils.hideKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final double? amount = double.tryParse(_cash.text.replaceAll(',', '').trim());
    if (amount == null) return;

    final ApiResult<Shift> result =
    await ref.read(shiftViewModelProvider.notifier).openShift(amount);

    // Server ka message ("Shift opened") + status code (201) ya error.
    AppUtils.showResult(result, successFallback: 'Shift opened');
  }

  void _pickQuick(int amount) {
    setState(() => _cash.text = '$amount');
    // Quick chip se bhara ho to purana error hatao.
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftState s = ref.watch(shiftViewModelProvider);
    final UserModel? user = ref.watch(currentUserProvider);
    final AppPalette palette = context.palette;
    final bool busy = s.isSubmitting;

    return ShiftCardShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Center(
              child: ShiftHeaderIcon(icon: Icons.lock_open_rounded),
            ),
            const SizedBox(height: 16),
            const AppText.h2('Open your shift', align: TextAlign.center),
            const SizedBox(height: 6),
            const AppText.body(
              'Count the cash in your drawer and enter it to start billing.',
              align: TextAlign.center,
              secondary: true,
            ),
            const SizedBox(height: 18),
            _UserRow(user: user),
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
              label: 'Opening cash (₹)',
              hint: '0',
              autofocus: false,
              validator: Validators.amount(
                fieldName: 'Opening cash',
                allowZero: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int amount in _quickAmounts)
                  _QuickChip(
                    label: FormatUtils.inr(amount),
                    selected: _cash.text.trim() == '$amount',
                    onTap: busy ? null : () => _pickQuick(amount),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Start shift',
              leadingIcon: Icons.play_arrow_rounded,
              isLoading: busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 6),
            AppButton(
              label: 'Logout',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.medium,
              onPressed: busy
                  ? null
                  : () => ref.read(authViewModelProvider.notifier).logout(),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'You must open a shift to start billing.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kaun login hai + abhi ka date / time.
class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final String name =
    (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'User';
    final String role = user?.roleLabel ?? 'User';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              user?.initials ?? '?',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppText.bodyBold(name, maxLines: 1),
                const SizedBox(height: 2),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                      color: palette.isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _LiveClock(),
        ],
      ),
    );
  }
}

/// Date + time, har 30 sec me update.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AppText.bodyBold(FormatUtils.time(_now)),
        const SizedBox(height: 2),
        AppText.caption(FormatUtils.weekday(_now)),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : palette.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(
            fontSize: 13,
            color: selected
                ? Colors.white
                : (palette.isDark ? AppColors.primaryLight : AppColors.primary),
          ),
        ),
      ),
    );
  }
}