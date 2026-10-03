import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/billing_model.dart';
import 'package:shopzo_pos/model/product_model.dart';
import 'package:shopzo_pos/model/recipt_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/product_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/view/sell/payment_sheet.dart';
import 'package:shopzo_pos/repo/billing_repo.dart';
import '../../service/receipt_pdf.dart';
import 'customer_box_card.dart';

class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(posProductsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onProductTap(ProductModel p) {
    FocusScope.of(context).unfocus();
    if (p.hasVariants && p.variants.isNotEmpty) {
      _pickVariant(p);
    } else {
      ref.read(billingViewModelProvider.notifier).add(p);
    }
  }

  Future<void> _pickVariant(ProductModel p) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (BuildContext ctx) => _VariantSheet(
        product: p,
        onPick: (ProductVariant v) {
          ref.read(billingViewModelProvider.notifier).add(p, variant: v);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (BuildContext _, ScrollController sc) {
            final AppPalette palette = context.palette;
            return Container(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _CartPanel(
                scrollController: sc,
                onClose: () => Navigator.of(sheetCtx).pop(),
                onPaid: (CreatedOrder o) {
                  Navigator.of(sheetCtx).pop();
                  _showDone(o);
                },
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _showDone(CreatedOrder order) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _DoneDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool tablet = context.isTablet;
    final ProductState state = ref.watch(posProductsProvider);
    final List<CartItem> cart =
    ref.watch(billingViewModelProvider.select((BillingState s) => s.cart));
    final double subtotal =
    ref.watch(billingViewModelProvider.select((BillingState s) => s.subtotal));
    final int count =
    ref.watch(billingViewModelProvider.select((BillingState s) => s.itemCount));

    // product id -> cart me kitni qty
    final Map<String, int> inCart = <String, int>{};
    for (final CartItem c in cart) {
      inCart[c.productId] = (inCart[c.productId] ?? 0) + c.qty;
    }

    final Widget products = Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: PosField(
            controller: _search,
            hint: 'Search product name or SKU',
            icon: Icons.search_rounded,
            onChanged: (String v) {
              ref.read(posProductsProvider.notifier).setSearch(v);
              setState(() {});
            },
            suffix: _search.text.isEmpty
                ? null
                : IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: palette.textSecondary),
              onPressed: () {
                _search.clear();
                ref.read(posProductsProvider.notifier).setSearch('');
                setState(() {});
              },
            ),
          ),
        ),
        Expanded(child: _buildList(state, inCart, tablet)),
        if (!tablet && cart.isNotEmpty)
          _CartBar(count: count, total: subtotal, onTap: _openCart),
      ],
    );

    return SafeArea(
      bottom: false,
      child: tablet
          ? Row(
        children: <Widget>[
          Expanded(flex: 3, child: products),
          VerticalDivider(width: 1, color: palette.border),
          Expanded(
            flex: 2,
            child: _CartPanel(onPaid: _showDone),
          ),
        ],
      )
          : products,
    );
  }

  Widget _buildList(ProductState state, Map<String, int> inCart, bool tablet) {
    final ProductViewModel vm = ref.read(posProductsProvider.notifier);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.items.isEmpty) {
      return AppErrorView(failure: state.failure!, onRetry: () => vm.load());
    }
    final List<ProductModel> list = state.visible;
    if (list.isEmpty) {
      return Center(
        child: AdaptiveText('No products found', AppTextStyles.body,
            m: 13, secondary: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.load(refresh: true),
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: tablet ? 340 : 700,
          mainAxisExtent: 86,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: list.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (BuildContext context, int i) {
          if (i >= list.length) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final ProductModel p = list[i];
          return _ProductTile(
            product: p,
            qtyInCart: inCart[p.id] ?? 0,
            onTap: () => _onProductTap(p),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product tile
// ═══════════════════════════════════════════════════════════════════════════

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.qtyInCart,
    required this.onTap,
  });

  final ProductModel product;
  final int qtyInCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool out = product.stockLevel == StockLevel.out;
    final bool low = product.stockLevel == StockLevel.low;

    final String price = product.hasPriceRange
        ? '${FormatUtils.inr(product.minPrice)} – ${FormatUtils.inr(product.maxPrice)}'
        : FormatUtils.inr(product.price, decimals: true);

    return Opacity(
      opacity: out ? 0.5 : 1,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: out ? () => AppUtils.showWarning('This item is out of stock.') : onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: qtyInCart > 0
                    ? AppColors.primary
                    : palette.border.withValues(alpha: 0.6),
                width: qtyInCart > 0 ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                ProductThumb(url: product.image, name: product.name, size: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AdaptiveText(product.name, AppTextStyles.bodyBold,
                          m: 13, t: 14, maxLines: 1),
                      const SizedBox(height: 2),
                      AdaptiveText(
                        product.hasVariants
                            ? '${product.variantCount} variants'
                            : (product.sku.isEmpty ? '—' : product.sku),
                        AppTextStyles.caption,
                        m: 11, t: 12, secondary: true, maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: AdaptiveText(price, AppTextStyles.bodyBold,
                                m: 13, t: 14, maxLines: 1, tabular: true),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            out
                                ? 'Out of stock'
                                : low
                                ? 'Only ${product.effectiveStock}'
                                : '',
                            style: AppTextStyles.caption.copyWith(
                              color: out ? AppColors.coral : const Color(0xFFE08A00),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (qtyInCart > 0)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('$qtyInCart',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: Colors.white, fontSize: 12)),
                  )
                else
                  Icon(Icons.add_circle_outline_rounded,
                      color: palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Variant picker
// ═══════════════════════════════════════════════════════════════════════════

class _VariantSheet extends StatelessWidget {
  const _VariantSheet({required this.product, required this.onPick});

  final ProductModel product;
  final ValueChanged<ProductVariant> onPick;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
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
          AdaptiveText(product.name, AppTextStyles.h2, m: 17, t: 19, maxLines: 2),
          const SizedBox(height: 2),
          AdaptiveText('Choose a variant', AppTextStyles.body,
              m: 12, t: 13, secondary: true),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: product.variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          : () => onPick(v),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            ProductThumb(
                              url: v.image ?? product.image,
                              name: v.displayName,
                              size: 40,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  AdaptiveText(v.displayName, AppTextStyles.bodyBold,
                                      m: 13, t: 14, maxLines: 1),
                                  AdaptiveText(
                                    out ? 'Out of stock' : '${v.stock} in stock',
                                    AppTextStyles.caption,
                                    m: 11, t: 12,
                                    color: out ? AppColors.coral : null,
                                    secondary: !out,
                                  ),
                                ],
                              ),
                            ),
                            AdaptiveText(
                              FormatUtils.inr(v.price, decimals: true),
                              AppTextStyles.bodyBold,
                              m: 13, t: 14, tabular: true,
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

// ═══════════════════════════════════════════════════════════════════════════
// Mobile: neeche "View cart" bar
// ═══════════════════════════════════════════════════════════════════════════

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.total, required this.onTap});

  final int count;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Text('$count ${count == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              const Spacer(),
              Text(FormatUtils.inr(total, decimals: true),
                  style: AppTextStyles.bodyBold
                      .copyWith(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Cart panel (tablet pe side me, mobile pe sheet me)
// ═══════════════════════════════════════════════════════════════════════════

class _CartPanel extends ConsumerWidget {
  const _CartPanel({required this.onPaid, this.onClose, this.scrollController});

  final ValueChanged<CreatedOrder> onPaid;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    if (ref.read(billingViewModelProvider).cart.isEmpty) {
      AppUtils.showWarning('Add at least one item to the cart.');
      return;
    }
    final CreatedOrder? order = await showPaymentSheet(context);
    if (order != null) {
      onPaid(order);
    } else if (context.mounted &&
        ref.read(billingViewModelProvider).cart.isEmpty) {
      onClose?.call(); // sale hold ho gayi, cart sheet band
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final BillingState s = ref.watch(billingViewModelProvider);
    final BillingViewModel vm = ref.read(billingViewModelProvider.notifier);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
            children: <Widget>[
              AdaptiveText('Current sale', AppTextStyles.h2, m: 18, t: 20),
              const SizedBox(width: 8),
              if (s.itemCount > 0)
                AdaptiveText('${s.itemCount} items', AppTextStyles.body,
                    m: 12, t: 13, secondary: true),
              const Spacer(),
              if (s.cart.isNotEmpty)
                TextButton(
                  onPressed: vm.clearCart,
                  child: Text('Clear',
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.coral, fontSize: 13)),
                ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            children: <Widget>[
              const CustomerBox(),
              const SizedBox(height: 12),
              PosCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: s.cart.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: <Widget>[
                      Icon(Icons.shopping_cart_outlined,
                          size: 34, color: palette.textHint),
                      const SizedBox(height: 8),
                      AdaptiveText('Cart is empty', AppTextStyles.body,
                          m: 13, secondary: true),
                      AdaptiveText('Tap a product to add it.',
                          AppTextStyles.caption,
                          m: 11, secondary: true),
                    ],
                  ),
                )
                    : Column(
                  children: <Widget>[
                    for (final CartItem c in s.cart)
                      _CartLine(
                        item: c,
                        onInc: () => vm.increase(c.key),
                        onDec: () => vm.decrease(c.key),
                        onRemove: () => vm.remove(c.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AdaptiveText('Total', AppTextStyles.bodyBold, m: 15, t: 17),
                    const Spacer(),
                    AdaptiveText(
                      FormatUtils.inr(s.subtotal, decimals: true),
                      AppTextStyles.h2,
                      m: 20, t: 24, tabular: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AdaptiveText('Tax / discount are calculated by the server.',
                    AppTextStyles.caption, m: 10, t: 11, secondary: true),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Pay now',
                  leadingIcon: Icons.payments_outlined,
                  isLoading: s.isPlacing,
                  onPressed: s.cart.isEmpty ? null : () => _pay(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    Widget stepBtn(IconData icon, VoidCallback? onTap) => InkResponse(
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16,
            color: onTap == null ? palette.textHint : palette.textPrimary),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          ProductThumb(url: item.image, name: item.name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText(item.name, AppTextStyles.bodyBold,
                    m: 12, t: 13, maxLines: 2),
                AdaptiveText(
                  '${FormatUtils.inr(item.price, decimals: true)} × ${item.qty}',
                  AppTextStyles.caption,
                  m: 11, t: 12, secondary: true, tabular: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AdaptiveText(
                FormatUtils.inr(item.lineTotal, decimals: true),
                AppTextStyles.bodyBold,
                m: 13, t: 14, tabular: true,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  stepBtn(
                    item.qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                    item.qty <= 1 ? onRemove : onDec,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${item.qty}', style: AppTextStyles.bodyBold),
                  ),
                  stepBtn(Icons.add_rounded, onInc),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order success dialog + receipt print
// ═══════════════════════════════════════════════════════════════════════════

class _DoneDialog extends ConsumerStatefulWidget {
  const _DoneDialog({required this.order});

  final CreatedOrder order;

  @override
  ConsumerState<_DoneDialog> createState() => _DoneDialogState();
}

class _DoneDialogState extends ConsumerState<_DoneDialog> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    final ApiResult<Receipt> result =
    await ref.read(billingRepoProvider).getReceipt(widget.order.id);
    if (!mounted) return;
    setState(() => _printing = false);

    final Receipt? receipt = result.dataOrNull;
    if (receipt == null) {
      AppUtils.showFailure(result.failureOrNull!);
      return;
    }
    await Printing.layoutPdf(
      name: receipt.orderNumber,
      onLayout: (_) => buildReceiptPdf(receipt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.mint),
            const SizedBox(height: 10),
            Center(child: AdaptiveText('Order placed', AppTextStyles.h2, m: 20)),
            const SizedBox(height: 4),
            Center(
              child: AdaptiveText(
                '#${widget.order.orderNumber}  •  ${FormatUtils.inr(widget.order.total, decimals: true)}',
                AppTextStyles.body,
                m: 13, secondary: true,
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Print receipt',
              leadingIcon: Icons.print_outlined,
              isLoading: _printing,
              onPressed: _print,
            ),
            const SizedBox(height: 4),
            AppButton(
              label: 'New sale',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.medium,
              onPressed: _printing ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}