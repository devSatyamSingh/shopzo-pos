import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/billing_model.dart';
import 'package:shopzo_pos/model/exchange_model.dart';
import 'package:shopzo_pos/model/pos_history_model.dart';
import 'package:shopzo_pos/model/product_model.dart';
import 'package:shopzo_pos/model/recipt_model.dart';
import 'package:shopzo_pos/repo/billing_repo.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
// ⚠️ Jis file me buildReceiptPdf() hai uska path yahan adjust karna.
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_shimmer.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

import '../service/receipt_pdf.dart';
import '../viewmodel/exchnage_viewmodel.dart';

double _round2(double v) => double.parse(v.toStringAsFixed(2));

String _fmt(double v) {
  if (v <= 0) return '';
  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
}

String _inr(num v) => FormatUtils.inr(v, decimals: true);

String _pretty(String raw) {
  final String t = raw.trim();
  if (t.length <= 3) return t.toUpperCase();
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

/// Payment ki ek line (cash / UPI).
class _Line {
  _Line(this.method);

  PaymentMethod method;
  final TextEditingController amount = TextEditingController();
  final TextEditingController txn = TextEditingController();

  void dispose() {
    amount.dispose();
    txn.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Exchange flow
// ═══════════════════════════════════════════════════════════════════════════

class ExchangeFlowScreen extends ConsumerStatefulWidget {
  const ExchangeFlowScreen({super.key, required this.order});

  final PosOrder order;

  @override
  ConsumerState<ExchangeFlowScreen> createState() => _ExchangeFlowScreenState();
}

class _ExchangeFlowScreenState extends ConsumerState<ExchangeFlowScreen> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final List<_Line> _lines = <_Line>[_Line(PaymentMethod.cash)];
  PaymentMethod _refundMethod = PaymentMethod.cash;
  Failure? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(exchangeViewModelProvider.notifier).start(widget.order);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    for (final _Line l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _val(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double get _entered =>
      _round2(_lines.fold<double>(0, (double s, _Line l) => s + _val(l.amount)));

  // ── Preview badalne par payment fields reset ─────────────────────────────

  void _onPreview(ExchangePreview? p) {
    final List<_Line> extra =
    _lines.length > 1 ? _lines.sublist(1) : <_Line>[];
    setState(() {
      if (_lines.length > 1) _lines.removeRange(1, _lines.length);
      _lines.first
        ..method = PaymentMethod.cash
        ..amount.text =
        (p != null && p.action == ExchangeAction.collect) ? _fmt(p.amount) : ''
        ..txn.clear();
      _error = null;
    });
    if (extra.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final _Line l in extra) {
          l.dispose();
        }
      });
    }
  }

  // ── Split payment ────────────────────────────────────────────────────────

  void _toggleSplit(ExchangePreview p) {
    setState(() {
      _error = null;
      if (_lines.length == 1) {
        final _Line second = _Line(
          _lines.first.method == PaymentMethod.cash
              ? PaymentMethod.upi
              : PaymentMethod.cash,
        );
        _lines.add(second);
        second.amount.text =
            _fmt(math.max(0, _round2(p.amount - _val(_lines.first.amount))));
      } else {
        final _Line removed = _lines.removeLast();
        _lines.first.amount.text = _fmt(p.amount);
        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      }
    });
  }

  void _onLineChanged(int i, ExchangePreview p) {
    if (_lines.length == 2) {
      final int other = 1 - i;
      _lines[other].amount.text =
          _fmt(math.max(0, _round2(p.amount - _val(_lines[i].amount))));
    }
    setState(() => _error = null);
  }

  void _setLineMethod(int i, PaymentMethod m) {
    setState(() {
      _lines[i].method = m;
      if (_lines.length == 2) {
        _lines[1 - i].method =
        m == PaymentMethod.cash ? PaymentMethod.upi : PaymentMethod.cash;
      }
      _error = null;
    });
  }

  // ── Validation ───────────────────────────────────────────────────────────

  bool _canConfirm(ExchangeState s) {
    final ExchangePreview? p = s.preview;
    if (p == null ||
        s.previewStatus != PreviewStatus.ready ||
        !p.inStock ||
        s.isSubmitting) {
      return false;
    }
    if (p.action != ExchangeAction.collect) return true;
    if (_lines.any((_Line l) => _val(l.amount) <= 0)) return false;
    return (_entered - p.amount).abs() < 0.005;
  }

  String _confirmLabel(ExchangePreview? p) {
    if (p == null) return 'Confirm Exchange';
    switch (p.action) {
      case ExchangeAction.collect:
        return 'Collect ${_inr(p.amount)} & Confirm';
      case ExchangeAction.refund:
        return 'Refund ${_inr(p.amount)} & Confirm';
      case ExchangeAction.even:
        return 'Confirm Exchange';
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickProduct(ProductModel p) async {
    AppUtils.hideKeyboard();
    final ExchangeViewModel vm = ref.read(exchangeViewModelProvider.notifier);

    if (p.stockLevel == StockLevel.out) {
      AppUtils.showWarning('This product is out of stock.');
      return;
    }
    if (p.hasVariants && p.variants.isNotEmpty) {
      final ProductVariant? v = await showModalBottomSheet<ProductVariant>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 520),
        builder: (BuildContext context) => _VariantSheet(product: p),
      );
      if (v != null && mounted) vm.selectProduct(p, variant: v);
      return;
    }
    vm.selectProduct(p);
  }

  Future<void> _confirm() async {
    AppUtils.hideKeyboard();
    final ExchangeState s = ref.read(exchangeViewModelProvider);
    final ExchangePreview? p = s.preview;
    if (p == null || !_canConfirm(s)) return;

    setState(() => _error = null);

    final List<ExchangePayment> payments = p.action == ExchangeAction.collect
        ? <ExchangePayment>[
      for (final _Line l in _lines)
        ExchangePayment(
          l.method,
          _round2(_val(l.amount)),
          transactionRef: l.method == PaymentMethod.upi ? l.txn.text : null,
        ),
    ]
        : const <ExchangePayment>[];

    final ApiResult<ExchangeResult> result = await ref
        .read(exchangeViewModelProvider.notifier)
        .submit(
      payments: payments,
      refundMethod: _refundMethod,
      reason: _reason.text,
    );
    if (!mounted) return;

    // Server ka message ("Exchange completed") + status code, ya error.
    AppUtils.showResult(result, successFallback: 'Exchange completed');

    final ExchangeResult? done = result.dataOrNull;
    if (done == null) {
      setState(() => _error = result.failureOrNull);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _SuccessDialog(result: done),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final double gap = m ? 12 : 16;
    final ExchangeState s = ref.watch(exchangeViewModelProvider);

    ref.listen<ExchangeState>(exchangeViewModelProvider, (
        ExchangeState? prev,
        ExchangeState next,
        ) {
      if (prev?.preview != next.preview) _onPreview(next.preview);
    });

    final ExchangePreview? preview = s.preview;
    final bool ready =
        preview != null && s.previewStatus == PreviewStatus.ready;

    return PopScope(
      canPop: !s.isSubmitting,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(m ? 16 : 32, 10, m ? 16 : 32, 0),
                child: ResponsiveCenter(
                  maxWidth: 640,
                  child: Row(
                    children: <Widget>[
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: s.isSubmitting
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText.h2(
                          'Exchange — ${widget.order.orderNumber}',
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    m ? 16 : 32,
                    gap,
                    m ? 16 : 32,
                    gap,
                  ),
                  child: ResponsiveCenter(
                    maxWidth: 640,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _returnSection(s),
                        SizedBox(height: gap),
                        _newItemSection(s),
                        if (s.hasNewItem) ...<Widget>[
                          SizedBox(height: gap),
                          _priceSection(s),
                        ],
                        if (ready) ...<Widget>[
                          SizedBox(height: gap),
                          _paymentSection(s, preview),
                          SizedBox(height: gap),
                          PosCard(
                            child: PosField(
                              controller: _reason,
                              label: 'Reason (optional)',
                              hint: 'e.g. Customer wanted a bigger size',
                              icon: Icons.edit_note_rounded,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          alignment: Alignment.topCenter,
                          child: _error != null
                              ? Padding(
                            padding: EdgeInsets.only(top: gap),
                            child: ShiftErrorBanner(
                              message: _error!.message,
                              statusCode: _error!.statusCode,
                            ),
                          )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(m ? 16 : 32, 10, m ? 16 : 32, 12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: ResponsiveCenter(
                  maxWidth: 640,
                  child: AppButton(
                    label: _confirmLabel(ready ? preview : null),
                    leadingIcon: Icons.swap_horiz_rounded,
                    isLoading: s.isSubmitting,
                    onPressed: _canConfirm(s) ? _confirm : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Item being returned ───────────────────────────────────────────────

  Widget _returnSection(ExchangeState s) {
    final ExchangeViewModel vm = ref.read(exchangeViewModelProvider.notifier);

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepHeader(number: 1, title: 'Item being returned'),
          const SizedBox(height: 12),
          for (final OrderLine line in widget.order.items) ...<Widget>[
            _ReturnItemTile(
              line: line,
              selected: line.id == s.itemId,
              onTap: line.canExchange && !s.isSubmitting
                  ? () => vm.selectItem(line.id)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  'Quantity to exchange',
                  AppTextStyles.bodyBold,
                  m: 13,
                  t: 14,
                ),
              ),
              _QtyStepper(
                value: s.qty,
                max: s.maxQty,
                onChanged: s.isSubmitting ? null : vm.setQty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. New item ──────────────────────────────────────────────────────────

  Widget _newItemSection(ExchangeState s) {
    final ExchangeViewModel vm = ref.read(exchangeViewModelProvider.notifier);

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepHeader(number: 2, title: 'New item'),
          const SizedBox(height: 12),
          if (s.hasNewItem)
            _SelectedNewItem(
              name: s.newItemLabel ?? '',
              price: s.newItemPrice ?? 0,
              onChange: s.isSubmitting ? null : vm.clearNewItem,
            )
          else ...<Widget>[
            PosField(
              controller: _search,
              hint: 'Search new product by name or SKU…',
              icon: Icons.search_rounded,
              onChanged: (String v) {
                vm.setSearch(v);
                setState(() {});
              },
              suffix: _search.text.isEmpty
                  ? null
                  : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
                onPressed: () {
                  _search.clear();
                  vm.setSearch('');
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 10),
            _productList(s),
          ],
        ],
      ),
    );
  }

  Widget _productList(ExchangeState s) {
    if (s.isSearching && s.products.isEmpty) {
      return AppShimmer(
        child: Column(
          children: <Widget>[
            for (int i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerBone(width: double.infinity, height: 60, radius: 14),
              ),
          ],
        ),
      );
    }
    if (s.searchFailure != null && s.products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AdaptiveText(
          s.searchFailure!.message,
          AppTextStyles.body,
          m: 12,
          t: 13,
          color: AppColors.coral,
        ),
      );
    }
    if (s.products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AdaptiveText(
          'No products found.',
          AppTextStyles.body,
          m: 12,
          t: 13,
          secondary: true,
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final ProductModel p in s.products)
          _ProductTile(product: p, onTap: () => _pickProduct(p)),
      ],
    );
  }

  // ── 3. Price difference ──────────────────────────────────────────────────

  Widget _priceSection(ExchangeState s) {
    final ExchangeViewModel vm = ref.read(exchangeViewModelProvider.notifier);
    Widget body;

    switch (s.previewStatus) {
      case PreviewStatus.idle:
        body = const SizedBox.shrink();
      case PreviewStatus.loading:
        body = const AppShimmer(
          child: ShimmerBone(width: double.infinity, height: 150, radius: 16),
        );
      case PreviewStatus.error:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ShiftErrorBanner(
              message: s.previewFailure?.message ?? 'Could not load the price difference.',
              statusCode: s.previewFailure?.statusCode,
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: vm.retryPreview,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        );
      case PreviewStatus.ready:
        final ExchangePreview p = s.preview!;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PriceBox(preview: p),
            if (!p.inStock) ...<Widget>[
              const SizedBox(height: 10),
              const ShiftErrorBanner(
                message: 'The new item is out of stock. Choose another item.',
              ),
            ],
          ],
        );
    }

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepHeader(number: 3, title: 'Price difference'),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  // ── 4. Payment / refund ──────────────────────────────────────────────────

  Widget _paymentSection(ExchangeState s, ExchangePreview p) {
    switch (p.action) {
      case ExchangeAction.collect:
        return _collectCard(s, p);
      case ExchangeAction.refund:
        return _refundCard(s);
      case ExchangeAction.even:
        return const PosCard(
          child: _Note(
            icon: Icons.check_circle_outline_rounded,
            text: 'Both items have the same value. No payment or refund is needed.',
          ),
        );
    }
  }

  Widget _collectCard(ExchangeState s, ExchangePreview p) {
    final bool busy = s.isSubmitting;
    final bool split = _lines.length == 2;

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdaptiveText(
            'Collect payment via',
            AppTextStyles.bodyBold,
            m: 14,
            t: 15,
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _lines.length; i++) ...<Widget>[
            if (split)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AdaptiveText(
                  'Payment ${i + 1}',
                  AppTextStyles.caption,
                  m: 11,
                  t: 12,
                  secondary: true,
                ),
              ),
            _MethodChips(
              value: _lines[i].method,
              onChanged: busy ? null : (PaymentMethod m) => _setLineMethod(i, m),
            ),
            const SizedBox(height: 10),
            PosField(
              controller: _lines[i].amount,
              label: 'Amount (₹)',
              hint: '0',
              icon: Icons.currency_rupee_rounded,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _onLineChanged(i, p),
            ),
            if (_lines[i].method == PaymentMethod.upi) ...<Widget>[
              const SizedBox(height: 10),
              PosField(
                controller: _lines[i].txn,
                label: 'Transaction ref (optional)',
                hint: 'e.g. UPI123456',
                icon: Icons.tag_rounded,
                enabled: !busy,
                textInputAction: TextInputAction.done,
              ),
            ],
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : () => _toggleSplit(p),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                split ? Icons.remove_circle_outline_rounded : Icons.call_split_rounded,
                size: 18,
              ),
              label: Text(
                split ? 'Use a single method' : 'Add another method (split)',
                style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SummaryBox(due: p.amount, entered: _entered),
        ],
      ),
    );
  }

  Widget _refundCard(ExchangeState s) {
    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdaptiveText(
            'Refund via',
            AppTextStyles.bodyBold,
            m: 14,
            t: 15,
          ),
          const SizedBox(height: 12),
          _MethodChips(
            value: _refundMethod,
            onChanged: s.isSubmitting
                ? null
                : (PaymentMethod m) => setState(() => _refundMethod = m),
          ),
          const SizedBox(height: 10),
          _Note(
            icon: Icons.info_outline_rounded,
            text: _refundMethod == PaymentMethod.cash
                ? 'The refund is paid from the cash drawer.'
                : 'UPI refunds are not counted in the drawer cash when the shift is closed.',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Small widgets
// ═══════════════════════════════════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTextStyles.bodyBold.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AdaptiveText(
            title,
            AppTextStyles.bodyBold,
            m: 14,
            t: 15,
          ),
        ),
      ],
    );
  }
}

class _ReturnItemTile extends StatelessWidget {
  const _ReturnItemTile({
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final OrderLine line;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool enabled = line.canExchange;
    final Color tone =
    palette.isDark ? AppColors.primaryLight : AppColors.primary;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? palette.primarySoft : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? tone : palette.textHint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AdaptiveText(
                        line.productName,
                        AppTextStyles.bodyBold,
                        m: 13,
                        t: 14,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      AdaptiveText(
                        'Bought: ${line.quantity}',
                        AppTextStyles.caption,
                        m: 11,
                        t: 12,
                        secondary: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveText(
                  enabled ? '${line.remaining} can be exchanged' : 'Already returned',
                  AppTextStyles.caption,
                  m: 11,
                  t: 12,
                  secondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool canDec = onChanged != null && value > 1;
    final bool canInc = onChanged != null && value < max;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canDec ? () => onChanged!(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(color: palette.textPrimary),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canInc ? () => onChanged!(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SelectedNewItem extends StatelessWidget {
  const _SelectedNewItem({
    required this.name,
    required this.price,
    required this.onChange,
  });

  final String name;
  final double price;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final Color tone = dark ? AppColors.mint : AppColors.mintDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText(
                  name,
                  AppTextStyles.bodyBold,
                  m: 13,
                  t: 14,
                  maxLines: 2,
                ),
                AdaptiveText(
                  '${_inr(price)} each',
                  AppTextStyles.caption,
                  m: 11,
                  t: 12,
                  secondary: true,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool out = product.stockLevel == StockLevel.out;

    Widget trailing;
    if (out) {
      trailing = Text(
        'Out of stock',
        style: AppTextStyles.caption.copyWith(color: AppColors.coral),
      );
    } else if (product.hasVariants && product.variants.isNotEmpty) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.layers_outlined, size: 14, color: palette.textSecondary),
          const SizedBox(width: 4),
          AdaptiveText(
            '${product.variantCount} variants',
            AppTextStyles.caption,
            m: 11,
            t: 12,
            secondary: true,
          ),
        ],
      );
    } else {
      trailing = AdaptiveText(
        _inr(product.price),
        AppTextStyles.bodyBold,
        m: 13,
        t: 14,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: out ? 0.5 : 1,
        child: Material(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: <Widget>[
                  ProductThumb(url: product.image, name: product.name, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AdaptiveText(
                          product.name,
                          AppTextStyles.bodyBold,
                          m: 13,
                          t: 14,
                          maxLines: 2,
                        ),
                        AdaptiveText(
                          product.sku,
                          AppTextStyles.caption,
                          m: 11,
                          t: 12,
                          secondary: true,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantSheet extends StatelessWidget {
  const _VariantSheet({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double maxH = MediaQuery.sizeOf(context).height * 0.6;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          AdaptiveText('Choose a variant', AppTextStyles.h2, m: 18, t: 20),
          const SizedBox(height: 2),
          AdaptiveText(
            product.name,
            AppTextStyles.body,
            m: 12,
            t: 13,
            secondary: true,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: product.variants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int i) {
                final ProductVariant v = product.variants[i];
                final bool out = v.stockLevel == StockLevel.out;
                return Opacity(
                  opacity: out ? 0.5 : 1,
                  child: Material(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: out
                          ? () => AppUtils.showWarning('This variant is out of stock.')
                          : () => Navigator.of(context).pop(v),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  AdaptiveText(
                                    v.displayName,
                                    AppTextStyles.bodyBold,
                                    m: 13,
                                    t: 14,
                                    maxLines: 1,
                                  ),
                                  AdaptiveText(
                                    out ? 'Out of stock' : '${v.stock} in stock',
                                    AppTextStyles.caption,
                                    m: 11,
                                    t: 12,
                                    color: out ? AppColors.coral : null,
                                    secondary: !out,
                                  ),
                                ],
                              ),
                            ),
                            AdaptiveText(
                              _inr(v.price),
                              AppTextStyles.bodyBold,
                              m: 13,
                              t: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.preview});

  final ExchangePreview preview;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final ExchangeAction action = preview.action;

    late final Color tone;
    late final Color soft;
    late final String title;
    late final String sub;
    late final String amount;

    switch (action) {
      case ExchangeAction.collect:
        tone = dark ? AppColors.primaryLight : AppColors.primary;
        soft = palette.primarySoft;
        title = 'CUSTOMER NEEDS TO PAY';
        sub = '${_inr(preview.newItemTotal)} − ${_inr(preview.originalValue)}';
        amount = _inr(preview.amount);
      case ExchangeAction.refund:
        tone = dark ? AppColors.mint : AppColors.mintDark;
        soft = dark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft;
        title = 'REFUND TO CUSTOMER';
        sub = '${_inr(preview.originalValue)} − ${_inr(preview.newItemTotal)}';
        amount = _inr(preview.amount);
      case ExchangeAction.even:
        tone = palette.textSecondary;
        soft = palette.surfaceAlt;
        title = 'NO PAYMENT NEEDED';
        sub = 'Both items have the same value';
        amount = _inr(0);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _Cell(
                      label: 'RETURN ITEM VALUE',
                      value: _inr(preview.originalValue),
                    ),
                  ),
                  VerticalDivider(width: 1, color: palette.border),
                  Expanded(
                    child: _Cell(
                      label: 'NEW ITEM VALUE',
                      value: _inr(preview.newItemTotal),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: soft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      color: tone,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount,
                      style: AppTextStyles.hero.copyWith(color: tone),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: <Widget>[
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: palette.textSecondary,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.bodyBold.copyWith(
                color: palette.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChips extends StatelessWidget {
  const _MethodChips({required this.value, required this.onChanged});

  final PaymentMethod value;
  final ValueChanged<PaymentMethod>? onChanged;

  static const List<(PaymentMethod, String, IconData)> _items =
  <(PaymentMethod, String, IconData)>[
    (PaymentMethod.cash, 'Cash', Icons.payments_outlined),
    (PaymentMethod.upi, 'UPI', Icons.qr_code_2_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Row(
      children: <Widget>[
        for (int i = 0; i < _items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(_items[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _items[i].$1 == value
                      ? AppColors.primary
                      : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      _items[i].$3,
                      size: 18,
                      color: _items[i].$1 == value
                          ? Colors.white
                          : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _items[i].$2,
                      style: AppTextStyles.bodyBold.copyWith(
                        fontSize: 13,
                        color: _items[i].$1 == value
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

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.due, required this.entered});

  final double due;
  final double entered;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final double remaining = _round2(due - entered);
    final bool ok = remaining.abs() < 0.005;
    final Color color = ok
        ? (dark ? AppColors.mint : AppColors.mintDark)
        : const Color(0xFFE08A00);

    Widget row(String l, String v, {TextStyle? style}) => Row(
      children: <Widget>[
        Expanded(
          child: Text(
            l,
            style: style ??
                AppTextStyles.body.copyWith(color: palette.textSecondary),
          ),
        ),
        Text(
          v,
          style: style ??
              AppTextStyles.bodyBold.copyWith(color: palette.textPrimary),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: <Widget>[
          row('Amount to collect', _inr(due)),
          const SizedBox(height: 6),
          row('Entered', _inr(entered)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: palette.border),
          ),
          row(
            remaining < -0.005 ? 'Over by' : 'Remaining',
            _inr(remaining.abs()),
            style: AppTextStyles.bodyBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: AdaptiveText(
              text,
              AppTextStyles.body,
              m: 12,
              t: 13,
              secondary: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Exchange completed (View / Print receipt)
// ═══════════════════════════════════════════════════════════════════════════

class _SuccessDialog extends ConsumerStatefulWidget {
  const _SuccessDialog({required this.result});

  final ExchangeResult result;

  @override
  ConsumerState<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends ConsumerState<_SuccessDialog> {
  bool _viewing = false;
  bool _printing = false;

  Future<Receipt?> _fetchReceipt() async {
    final ApiResult<Receipt> r =
    await ref.read(billingRepoProvider).getReceipt(widget.result.orderId);
    if (!mounted) return null;

    final Receipt? data = r.dataOrNull;
    if (data == null) {
      final Failure? f = r.failureOrNull;
      if (f != null) AppUtils.showFailure(f);
    }
    return data;
  }

  Future<void> _view() async {
    setState(() => _viewing = true);
    final Receipt? r = await _fetchReceipt();
    if (!mounted) return;
    setState(() => _viewing = false);
    if (r == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ReceiptPreviewScreen(receipt: r)),
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    final Receipt? r = await _fetchReceipt();
    if (!mounted) return;
    if (r == null) {
      setState(() => _printing = false);
      return;
    }

    try {
      final Uint8List bytes = await buildReceiptPdf(r);
      await Printing.layoutPdf(
        name: r.orderNumber.isEmpty ? 'Receipt' : r.orderNumber,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (_) {
      AppUtils.showError('Could not print the receipt. Please try again.');
    }
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final ExchangeResult res = widget.result;
    final ExchangeAction action = res.action;
    final bool busy = _viewing || _printing;

    late final String title;
    late final String amount;
    late final String note;
    late final Color tone;

    switch (action) {
      case ExchangeAction.collect:
        title = 'COLLECTED FROM CUSTOMER';
        amount = _inr(res.priceDiff.abs());
        note = 'New item costs more';
        tone = dark ? AppColors.primaryLight : AppColors.primary;
      case ExchangeAction.refund:
        final String via =
        res.refundMethod == null ? '' : ' • via ${_pretty(res.refundMethod!)}';
        title = 'REFUNDED TO CUSTOMER';
        amount = _inr(res.refundAmount ?? res.priceDiff.abs());
        note = 'New item costs less$via';
        tone = dark ? AppColors.mint : AppColors.mintDark;
      case ExchangeAction.even:
        title = 'NO PAYMENT NEEDED';
        amount = _inr(0);
        note = 'Both items have the same value';
        tone = palette.textSecondary;
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: palette.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 34,
                      color: dark ? AppColors.mint : AppColors.mintDark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const AppText.h2('Exchange Completed', align: TextAlign.center),
                const SizedBox(height: 4),
                AppText.body(
                  'New Order #${res.orderNumber}',
                  align: TextAlign.center,
                  secondary: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount,
                          style: AppTextStyles.hero.copyWith(color: tone),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: AppText.body('New order total', secondary: true),
                    ),
                    AppText.bodyBold(_inr(res.total)),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'View Receipt',
                  leadingIcon: Icons.receipt_long_outlined,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.medium,
                  isLoading: _viewing,
                  onPressed: busy ? null : _view,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Print Receipt',
                  leadingIcon: Icons.print_outlined,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.medium,
                  isLoading: _printing,
                  onPressed: busy ? null : _print,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Done',
                  leadingIcon: Icons.check_rounded,
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Receipt ka preview (zoom, print aur share ke buttons ke saath).
class _ReceiptPreviewScreen extends StatelessWidget {
  const _ReceiptPreviewScreen({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText.h2(
                      receipt.orderNumber.isEmpty ? 'Receipt' : receipt.orderNumber,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (PdfPageFormat format) => buildReceiptPdf(receipt),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                maxPageWidth: 420,
                pdfFileName: '${receipt.orderNumber.isEmpty ? 'receipt' : receipt.orderNumber}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}