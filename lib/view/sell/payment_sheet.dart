import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/billing_model.dart';
import 'package:shopzo_pos/model/coupon_model.dart';
import 'package:shopzo_pos/model/customer_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

import '../../repo/coupon_repo.dart';
import '../../viewmodel/held_viewmodel.dart';
import '../held/held_screen.dart';

/// Pay Now: payment method choose karke order create karta hai.
/// Success par [CreatedOrder] wapas deta hai (cancel / error par null).
Future<CreatedOrder?> showPaymentSheet(BuildContext context) {
  return showModalBottomSheet<CreatedOrder>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (BuildContext context) => const _PaymentSheet(),
  );
}

enum _Mode { cash, upi, card, split }

double _round2(double v) => double.parse(v.toStringAsFixed(2));

String _fmt(double v) {
  if (v <= 0) return '';
  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet();

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  // Sheet khulte waqt ki values (order success par cart saaf hota hai).
  late final double _subtotal = ref.read(billingViewModelProvider).subtotal;
  late final int _itemCount = ref.read(billingViewModelProvider).itemCount;
  late final CustomerModel? _customer =
      ref.read(billingViewModelProvider).customer;

  // Coupon lagne ke baad payable total = subtotal - discount.
  CouponModel? _applied;
  double _discount = 0;
  bool _applying = false;
  String? _couponError;

  double get _total => _round2(_subtotal - _discount);

  _Mode _mode = _Mode.cash;
  Failure? _error;
  bool _holding = false;

  final TextEditingController _received = TextEditingController();
  final TextEditingController _sCash = TextEditingController();
  final TextEditingController _sUpi = TextEditingController();
  final TextEditingController _sCard = TextEditingController();
  final TextEditingController _coupon = TextEditingController();

  @override
  void dispose() {
    _received.dispose();
    _sCash.dispose();
    _sUpi.dispose();
    _sCard.dispose();
    _coupon.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  // ── Coupon ───────────────────────────────────────────────────────────────

  /// Total badalne par purane amounts galat ho jaate hain, isliye saaf karo.
  void _resetAmounts() {
    _received.clear();
    _sCash.clear();
    _sUpi.clear();
    _sCard.clear();
  }

  double _discountFor(CouponModel c) {
    final double raw = c.isPercentage
        ? _round2(_subtotal * c.value / 100)
        : c.value;
    return _round2(math.min(raw, _subtotal));
  }

  /// null = coupon theek hai, warna error message.
  String? _validateCoupon(CouponModel c) {
    switch (c.status) {
      case CouponStatus.inactive:
        return 'This coupon is not active.';
      case CouponStatus.expired:
        return 'This coupon has expired.';
      case CouponStatus.usedUp:
        return 'This coupon has reached its usage limit.';
      case CouponStatus.active:
        break;
    }
    if (_subtotal < c.minOrderValue - 0.005) {
      return 'Minimum order ${FormatUtils.inr(c.minOrderValue)} is required for this coupon.';
    }
    return null;
  }

  Future<void> _applyCoupon() async {
    AppUtils.hideKeyboard();
    final String code = _coupon.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code.');
      return;
    }
    // Backend coupon ke saath customer maangta hai.
    if (_customer == null) {
      setState(() => _couponError = 'Select a customer first to use a coupon.');
      return;
    }

    setState(() {
      _applying = true;
      _couponError = null;
      _error = null;
    });

    final ApiResult<List<CouponModel>> result =
    await ref.read(couponRepositoryProvider).getCoupons();
    if (!mounted) return;

    final List<CouponModel>? list = result.dataOrNull;
    if (list == null) {
      setState(() => _applying = false);
      final Failure? f = result.failureOrNull;
      if (f != null) AppUtils.showFailure(f);
      return;
    }
    final CouponModel? found = list.where((CouponModel c) => c.code == code).firstOrNull;
    final String? problem = found == null ? 'Invalid coupon code.' : _validateCoupon(found);
    if (found == null || problem != null) {
      setState(() {
        _applying = false;
        _couponError = problem;
      });
      return;
    }
    final double discount = _discountFor(found);
    setState(() {
      _applying = false;
      _applied = found;
      _discount = discount;
      _resetAmounts();
    });
    AppUtils.showSuccess(
      'Coupon ${found.code} applied. You save ${FormatUtils.inr(discount, decimals: true)}.',
    );
  }

  void _removeCoupon() {
    setState(() {
      _applied = null;
      _discount = 0;
      _couponError = null;
      _error = null;
      _coupon.clear();
      _resetAmounts();
    });
  }

  void _onSplitChanged(String field) {
    final double cash = _val(_sCash);
    final double upi = _val(_sUpi);
    final double card = _val(_sCard);

    double rest(double a, double b) => math.max(0, _round2(_total - a - b));

    switch (field) {
      case 'cash':
        _sUpi.text = _fmt(rest(cash, card));
      case 'upi':
        _sCash.text = _fmt(rest(upi, card));
      case 'card':
        _sUpi.text = _fmt(rest(cash, card));
    }
    setState(() => _error = null);
  }

  List<PaymentLine> get _splitLines => <PaymentLine>[
    if (_val(_sCash) > 0) PaymentLine(PaymentMethod.cash, _round2(_val(_sCash))),
    if (_val(_sUpi) > 0) PaymentLine(PaymentMethod.upi, _round2(_val(_sUpi))),
    if (_val(_sCard) > 0) PaymentLine(PaymentMethod.card, _round2(_val(_sCard))),
  ];

  double get _splitPaid => _round2(_val(_sCash) + _val(_sUpi) + _val(_sCard));
  double get _splitRemaining => _round2(_total - _splitPaid);

  // ── Validation ───────────────────────────────────────────────────────────

  bool get _cashOk {
    if (_received.text.trim().isEmpty) return true; // exact cash
    return _val(_received) >= _total - 0.005;
  }

  bool get _canConfirm {
    switch (_mode) {
      case _Mode.cash:
        return _cashOk;
      case _Mode.upi:
      case _Mode.card:
        return true;
      case _Mode.split:
        return _splitLines.isNotEmpty && _splitRemaining.abs() < 0.005;
    }
  }

  List<PaymentLine> _buildLines() {
    switch (_mode) {
      case _Mode.cash:
        return <PaymentLine>[PaymentLine(PaymentMethod.cash, _total)];
      case _Mode.upi:
        return <PaymentLine>[PaymentLine(PaymentMethod.upi, _total)];
      case _Mode.card:
        return <PaymentLine>[PaymentLine(PaymentMethod.card, _total)];
      case _Mode.split:
        return _splitLines;
    }
  }

  Future<void> _confirm() async {
    AppUtils.hideKeyboard();
    if (!_canConfirm) return;

    setState(() => _error = null);
    final ApiResult<CreatedOrder> result = await ref
        .read(billingViewModelProvider.notifier)
        .placeOrder(_buildLines(), couponCode: _applied?.code);
    if (!mounted) return;

    // Server ka message ("Order created") + status code (201), ya error.
    AppUtils.showResult(result, successFallback: 'Order created');

    final CreatedOrder? order = result.dataOrNull;
    if (order != null) {
      Navigator.of(context).pop(order);
    } else {
      setState(() => _error = result.failureOrNull);
    }
  }

  Future<void> _hold() async {
    AppUtils.hideKeyboard();
    final String? note = await showHoldNoteDialog(context); // null = cancel
    if (note == null || !mounted) return;

    setState(() {
      _holding = true;
      _error = null;
    });
    final result =
    await ref.read(heldViewModelProvider.notifier).holdCart(note: note);
    if (!mounted) return;
    setState(() => _holding = false);

    AppUtils.showResult(result, successFallback: 'Order held');
    if (result.dataOrNull != null) {
      Navigator.of(context).pop(); // order nahi bana, isliye null wapas
    } else {
      setState(() => _error = result.failureOrNull);
    }
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final bool busy = ref.watch(
      billingViewModelProvider.select((BillingState s) => s.isPlacing),
    );

    return PopScope(
      canPop: !busy && !_holding,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(m ? 16 : 22, 12, m ? 16 : 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    AdaptiveText('Payment', AppTextStyles.h2, m: 18, t: 20),
                    const Spacer(),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _TotalCard(
                  total: _total,
                  itemCount: _itemCount,
                  customer: _customer,
                  note: _applied == null
                      ? null
                      : '${FormatUtils.inr(_subtotal, decimals: true)} − ${FormatUtils.inr(_discount, decimals: true)} (${_applied!.code})',
                ),
                const SizedBox(height: 14),
                _couponSection(busy),
                const SizedBox(height: 16),
                _MethodSelector(
                  mode: _mode,
                  onChanged: (busy || _applying) ? null : _setMode,
                ),
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _buildMode(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _error != null
                      ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ShiftErrorBanner(
                      message: _error!.message,
                      statusCode: _error!.statusCode,
                    ),
                  )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Confirm payment ${FormatUtils.inr(_total)}',
                  leadingIcon: Icons.check_circle_outline_rounded,
                  isLoading: busy,
                  onPressed:
                  (_canConfirm && !_holding && !_applying) ? _confirm : null,
                ),
                const SizedBox(height: 4),
                AppButton(
                  label: 'Hold sale',
                  leadingIcon: Icons.pause_circle_outline_rounded,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  isLoading: _holding,
                  onPressed: (busy || _applying) ? null : _hold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Coupon UI ────────────────────────────────────────────────────────────

  Widget _couponSection(bool busy) {
    final CouponModel? applied = _applied;

    if (applied != null) {
      return _AppliedCoupon(
        code: applied.code,
        saving: _discount,
        onRemove: busy ? null : _removeCoupon,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: PosField(
            controller: _coupon,
            label: 'Coupon code (optional)',
            hint: 'e.g. SAVE10',
            icon: Icons.local_offer_outlined,
            enabled: !busy && !_applying,
            textInputAction: TextInputAction.done,
            errorText: _couponError,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              LengthLimitingTextInputFormatter(30),
              TextInputFormatter.withFunction(
                    (TextEditingValue old, TextEditingValue next) =>
                    next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            onChanged: (_) {
              if (_couponError != null) setState(() => _couponError = null);
            },
            onSubmitted: (_) => _applyCoupon(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: AppButton(
            label: 'Apply',
            isLoading: _applying,
            onPressed: busy ? null : _applyCoupon,
          ),
        ),
      ],
    );
  }

  Widget _buildMode() {
    switch (_mode) {
      case _Mode.cash:
        return _cashMode();
      case _Mode.upi:
        return _InfoNote(
          icon: Icons.qr_code_2_rounded,
          text: 'Collect ${FormatUtils.inr(_total)} on UPI, then confirm.',
        );
      case _Mode.card:
        return _InfoNote(
          icon: Icons.credit_card_rounded,
          text: 'Swipe / tap the card for ${FormatUtils.inr(_total)}, then confirm.',
        );
      case _Mode.split:
        return _splitMode();
    }
  }

  // ── Cash ─────────────────────────────────────────────────────────────────

  Widget _cashMode() {
    final double received = _val(_received);
    final bool hasInput = _received.text.trim().isNotEmpty;
    final double change = _round2(received - _total);

    // Exact ke baad agle round amounts.
    double up(double v, double step) => (v / step).ceilToDouble() * step;
    final Set<double> quick = <double>{
      up(_total, 10),
      up(_total, 100),
      up(_total, 500),
      up(_total, 2000),
    }..removeWhere((double v) => (v - _total).abs() < 0.005);
    final List<double> chips = (quick.toList()..sort()).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PosField(
          controller: _received,
          label: 'Cash received (optional)',
          hint: FormatUtils.inr(_total),
          icon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Chip(
              label: 'Exact',
              selected: !hasInput,
              onTap: () => setState(() => _received.clear()),
            ),
            for (final double v in chips)
              _Chip(
                label: FormatUtils.inr(v),
                selected: hasInput && (received - v).abs() < 0.005,
                onTap: () => setState(() => _received.text = _fmt(v)),
              ),
          ],
        ),
        if (hasInput) ...<Widget>[
          const SizedBox(height: 12),
          _StatusLine(
            ok: change >= -0.005,
            text: change >= -0.005
                ? 'Return change ${FormatUtils.inr(math.max(0, change), decimals: true)}'
                : 'Short by ${FormatUtils.inr(-change, decimals: true)}',
          ),
        ],
      ],
    );
  }

  // ── Split ────────────────────────────────────────────────────────────────

  Widget _splitMode() {
    final double remaining = _splitRemaining;
    final bool done = remaining.abs() < 0.005 && _splitLines.isNotEmpty;

    Widget amount(String label, IconData icon, TextEditingController c, String id) {
      return PosField(
        controller: c,
        label: label,
        hint: '0',
        icon: icon,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onChanged: (_) => _onSplitChanged(id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        amount('Cash (₹)', Icons.payments_outlined, _sCash, 'cash'),
        const SizedBox(height: 10),
        amount('UPI (₹)', Icons.qr_code_2_rounded, _sUpi, 'upi'),
        const SizedBox(height: 10),
        amount('Card (₹)', Icons.credit_card_rounded, _sCard, 'card'),
        const SizedBox(height: 12),
        _StatusLine(
          ok: done,
          text: done
              ? 'Paid in full'
              : remaining > 0
              ? '${FormatUtils.inr(remaining, decimals: true)} remaining'
              : '${FormatUtils.inr(-remaining, decimals: true)} over the total',
        ),
        const SizedBox(height: 4),
        Text(
          'Enter one amount and the balance fills in automatically.',
          style: AppTextStyles.caption
              .copyWith(color: context.palette.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Small widgets
// ═══════════════════════════════════════════════════════════════════════════

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.itemCount,
    required this.customer,
    this.note,
  });

  final double total;
  final int itemCount;
  final CustomerModel? customer;

  /// Coupon laga ho to "₹599 − ₹59.90 (SAVE10)" jaisi line.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    return Container(
      padding: EdgeInsets.all(m ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(m ? 20 : AppRadius.xxl),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText('Amount to pay', AppTextStyles.body,
                    m: 12, t: 14, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AdaptiveText(
                    FormatUtils.inr(total, decimals: true),
                    AppTextStyles.hero,
                    m: 28,
                    t: 34,
                    color: Colors.white,
                    tabular: true,
                  ),
                ),
                if (note != null) ...<Widget>[
                  const SizedBox(height: 2),
                  AdaptiveText(
                    note!,
                    AppTextStyles.caption,
                    m: 11,
                    t: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AdaptiveText('$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  AppTextStyles.bodyBold, m: 12, t: 14, color: Colors.white),
              const SizedBox(height: 2),
              AdaptiveText(
                customer?.name ?? 'Walk-in customer',
                AppTextStyles.caption,
                m: 11,
                t: 12,
                color: Colors.white.withValues(alpha: 0.85),
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppliedCoupon extends StatelessWidget {
  const _AppliedCoupon({
    required this.code,
    required this.saving,
    required this.onRemove,
  });

  final String code;
  final double saving;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final Color tone = dark ? AppColors.mint : AppColors.mintDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.local_offer_rounded, size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$code applied',
                  style: AppTextStyles.bodyBold.copyWith(color: tone, fontSize: 13),
                ),
                Text(
                  'You save ${FormatUtils.inr(saving, decimals: true)}',
                  style: AppTextStyles.caption.copyWith(color: tone, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove coupon',
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode>? onChanged;

  static const List<(_Mode, String, IconData)> _items =
  <(_Mode, String, IconData)>[
    (_Mode.cash, 'Cash', Icons.payments_outlined),
    (_Mode.upi, 'UPI', Icons.qr_code_2_rounded),
    (_Mode.card, 'Card', Icons.credit_card_rounded),
    (_Mode.split, 'Split', Icons.call_split_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return Row(
      children: <Widget>[
        for (int i = 0; i < _items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(_items[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: m ? 10 : 12),
                decoration: BoxDecoration(
                  color: _items[i].$1 == mode
                      ? AppColors.primary
                      : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      _items[i].$3,
                      size: m ? 20 : 22,
                      color: _items[i].$1 == mode
                          ? Colors.white
                          : palette.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _items[i].$2,
                      style: AppTextStyles.bodyBold.copyWith(
                        fontSize: m ? 12 : 13,
                        color: _items[i].$1 == mode
                            ? Colors.white
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final Color color = ok
        ? (dark ? AppColors.mint : AppColors.mintDark)
        : const Color(0xFFE08A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: AdaptiveText(text, AppTextStyles.body,
                m: 13, t: 14, secondary: true),
          ),
        ],
      ),
    );
  }
}