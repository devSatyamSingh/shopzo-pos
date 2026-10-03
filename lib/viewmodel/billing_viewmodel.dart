import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../model/billing_model.dart';
import '../model/customer_model.dart';
import '../model/product_model.dart';
import '../repo/billing_repo.dart';
import '../utils/app_utils.dart';
import 'auth_viewmodel.dart';
import 'product_viewmodel.dart';

final NotifierProvider<ProductViewModel, ProductState> posProductsProvider =
    NotifierProvider<ProductViewModel, ProductState>(ProductViewModel.new);

class BillingState {
  const BillingState({
    this.cart = const <CartItem>[],
    this.customer,
    this.isPlacing = false,
  });

  final List<CartItem> cart;
  final CustomerModel? customer;
  final bool isPlacing;
  int get itemCount => cart.fold<int>(0, (int s, CartItem i) => s + i.qty);
  double get subtotal => double.parse(cart.fold<double>(0, (double s, CartItem i) => s + i.lineTotal).toStringAsFixed(2),);

  BillingState copyWith({
    List<CartItem>? cart,
    CustomerModel? customer,
    bool clearCustomer = false,
    bool? isPlacing,
  }) {
    return BillingState(
      cart: cart ?? this.cart,
      customer: clearCustomer ? null : (customer ?? this.customer),
      isPlacing: isPlacing ?? this.isPlacing,
    );
  }
}

class BillingViewModel extends Notifier<BillingState> {
  BillingRepo get _repo => ref.read(billingRepoProvider);

  @override
  BillingState build() {
    ref.watch(authViewModelProvider.select((AuthState s) => s.user?.id));
    return const BillingState();
  }

  void add(ProductModel product, {ProductVariant? variant}) {
    final int stock = variant?.stock ?? product.effectiveStock;
    if (stock <= 0) {
      AppUtils.showWarning('This item is out of stock.');
      return;
    }

    final CartItem item = CartItem(
      productId: product.id,
      variantId: variant?.id,
      name: variant == null
          ? product.name
          : '${product.name} — ${variant.displayName}',
      sku: variant?.sku ?? product.sku,
      price: variant?.price ?? product.price,
      maxStock: stock,
      qty: 1,
      image: variant?.image ?? product.image,
    );

    final List<CartItem> cart = List<CartItem>.of(state.cart);
    final int i = cart.indexWhere((CartItem c) => c.key == item.key);
    if (i == -1) {
      cart.add(item);
    } else {
      if (cart[i].qty + 1 > cart[i].maxStock) {
        AppUtils.showWarning('Only ${cart[i].maxStock} in stock.');
        return;
      }
      cart[i] = cart[i].withQty(cart[i].qty + 1);
    }
    state = state.copyWith(cart: cart);
  }

  void increase(String key) {
    final List<CartItem> cart = List<CartItem>.of(state.cart);
    final int i = cart.indexWhere((CartItem c) => c.key == key);
    if (i == -1) return;
    if (cart[i].qty + 1 > cart[i].maxStock) {
      AppUtils.showWarning('Only ${cart[i].maxStock} in stock.');
      return;
    }
    cart[i] = cart[i].withQty(cart[i].qty + 1);
    state = state.copyWith(cart: cart);
  }

  void decrease(String key) {
    final List<CartItem> cart = List<CartItem>.of(state.cart);
    final int i = cart.indexWhere((CartItem c) => c.key == key);
    if (i == -1 || cart[i].qty <= 1) return;
    cart[i] = cart[i].withQty(cart[i].qty - 1);
    state = state.copyWith(cart: cart);
  }

  void remove(String key) {
    state = state.copyWith(
      cart: state.cart.where((CartItem c) => c.key != key).toList(),
    );
  }

  void clearCart() => state = state.copyWith(cart: const <CartItem>[]);

  // ── Customer ─────────────────────────────────────────────────────────────

  void setCustomer(CustomerModel customer) =>
      state = state.copyWith(customer: customer);

  void clearCustomer() => state = state.copyWith(clearCustomer: true);

  void restore(List<CartItem> cart, {CustomerModel? customer}) {
    state = BillingState(cart: cart, customer: customer);
  }

  void reset() => state = const BillingState();

  Future<ApiResult<CreatedOrder>> placeOrder(List<PaymentLine> payments) async {
    if (state.isPlacing) {
      return const ApiFailure<CreatedOrder>(
        Failure(message: 'Please wait, the order is being placed.'),
      );
    }
    if (state.cart.isEmpty) {
      return const ApiFailure<CreatedOrder>(
        Failure(message: 'The cart is empty.'),
      );
    }

    state = state.copyWith(isPlacing: true);

    final ApiResult<CreatedOrder> result = await _repo.createOrder(
      items: state.cart,
      payments: payments,
      customerId: state.customer?.id,
    );

    if (!ref.mounted) return result;

    if (result is ApiSuccess<CreatedOrder>) {
      state = const BillingState();
      unawaited(ref.read(posProductsProvider.notifier).load(refresh: true));
    } else {
      state = state.copyWith(isPlacing: false);
    }
    return result;
  }
}

final NotifierProvider<BillingViewModel, BillingState>
billingViewModelProvider = NotifierProvider<BillingViewModel, BillingState>(
  BillingViewModel.new,
);
