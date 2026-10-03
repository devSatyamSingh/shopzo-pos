import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/billing_model.dart';
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
  late final double _total = ref.read(billingViewModelProvider).subtotal;
  late final int _itemCount = ref.read(billingViewModelProvider).itemCount;
  late final CustomerModel? _customer =
      ref.read(billingViewModelProvider).customer;

  _Mode _mode = _Mode.cash;
  Failure? _error;
  bool _holding = false;

  final TextEditingController _received = TextEditingController();
  final TextEditingController _sCash = TextEditingController();
  final TextEditingController _sUpi = TextEditingController();
  final TextEditingController _sCard = TextEditingController();

  @override
  void dispose() {
    _received.dispose();
    _sCash.dispose();
    _sUpi.dispose();
    _sCard.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  // ── Split auto-adjust ────────────────────────────────────────────────────

  /// Jo field user ne badli use chhod kar baaki ka balance dusre field me daalta hai:
  /// cash badla -> UPI adjust, UPI badla -> cash adjust, card badla -> UPI adjust.
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
    final ApiResult<CreatedOrder> result =
    await ref.read(billingViewModelProvider.notifier).placeOrder(_buildLines());
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
                ),
                const SizedBox(height: 16),
                _MethodSelector(mode: _mode, onChanged: busy ? null : _setMode),
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
                  onPressed: (_canConfirm && !_holding) ? _confirm : null,
                ),
                const SizedBox(height: 4),
                AppButton(
                  label: 'Hold sale',
                  leadingIcon: Icons.pause_circle_outline_rounded,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  isLoading: _holding,
                  onPressed: busy ? null : _hold,
                ),
              ],
            ),
          ),
        ),
      ),
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
  });

  final double total;
  final int itemCount;
  final CustomerModel? customer;

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