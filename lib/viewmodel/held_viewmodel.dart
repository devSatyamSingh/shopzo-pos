import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../model/billing_model.dart';
import '../model/customer_model.dart';
import '../model/held_order_model.dart';
import '../model/product_model.dart';
import '../repo/held_repo.dart';
import '../repo/product_repo.dart';
import '../utils/app_utils.dart';
import 'auth_viewmodel.dart';
import 'billing_viewmodel.dart';

class HeldState {
  const HeldState({
    this.items = const <HeldOrder>[],
    this.isLoading = true,
    this.isHolding = false,
    this.busyIds = const <String>{},
    this.failure,
  });

  final List<HeldOrder> items;
  final bool isLoading;
  final bool isHolding;
  final Set<String> busyIds;
  final Failure? failure;

  HeldState copyWith({
    List<HeldOrder>? items,
    bool? isLoading,
    bool? isHolding,
    Set<String>? busyIds,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return HeldState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isHolding: isHolding ?? this.isHolding,
      busyIds: busyIds ?? this.busyIds,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class ResumeOutcome {
  const ResumeOutcome(this.result, {this.warnings = const <String>[]});

  ResumeOutcome.fail(String message)
    : result = ApiFailure<HeldOrder>(Failure(message: message)),
      warnings = const <String>[];

  final ApiResult<HeldOrder> result;
  final List<String> warnings;
  bool get ok => result is ApiSuccess<HeldOrder>;
}

class HeldViewModel extends Notifier<HeldState> {
  static const int _pageSize = 50;
  static const int _maxPages = 15;
  int _requestId = 0;
  HeldRepo get _repo => ref.read(heldRepoProvider);

  @override
  HeldState build() {
    ref.watch(authViewModelProvider.select((AuthState s) => s.user?.id));
    Future<void>.microtask(() => load());
    return const HeldState();
  }

  void _setBusy(String id, bool busy) {
    if (!ref.mounted) return;
    final Set<String> next = Set<String>.of(state.busyIds);
    busy ? next.add(id) : next.remove(id);
    state = state.copyWith(busyIds: next);
  }

  Future<void> load({bool refresh = false}) async {
    final int id = ++_requestId;
    if (!refresh) {
      state = state.copyWith(isLoading: true, clearFailure: true);
    }

    final ApiResult<List<HeldOrder>> result = await _repo.list();
    if (!ref.mounted || id != _requestId) return;

    final List<HeldOrder>? data = result.dataOrNull;
    if (data != null) {
      final List<HeldOrder> held =
          data.where((HeldOrder o) => o.isHeld).toList()..sort(
            (HeldOrder a, HeldOrder b) => (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)),
          );
      state = state.copyWith(isLoading: false, clearFailure: true, items: held);
      return;
    }

    final Failure failure = result.failureOrNull!;
    if (state.items.isNotEmpty) {
      AppUtils.showFailure(failure);
      state = state.copyWith(isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<ApiResult<HeldOrder>> holdCart({String? note}) async {
    final BillingState b = ref.read(billingViewModelProvider);
    if (state.isHolding) {
      return const ApiFailure<HeldOrder>(
        Failure(message: 'Please wait, the sale is being held.'),
      );
    }
    if (b.cart.isEmpty) {
      return const ApiFailure<HeldOrder>(
        Failure(message: 'The cart is empty.'),
      );
    }

    state = state.copyWith(isHolding: true);
    final ApiResult<HeldOrder> result = await _repo.hold(
      items: b.cart,
      customerId: b.customer?.id,
      note: note,
    );
    if (!ref.mounted) return result;
    state = state.copyWith(isHolding: false);

    if (result is ApiSuccess<HeldOrder>) {
      ref.read(billingViewModelProvider.notifier).reset();
      unawaited(load(refresh: true));
    }
    return result;
  }

  Future<ResumeOutcome> resume(HeldOrder held) async {
    if (state.busyIds.contains(held.id)) {
      return ResumeOutcome.fail('Please wait...');
    }
    _setBusy(held.id, true);
    try {
      final Set<String> ids = held.items
          .map((HeldItem i) => i.productId)
          .toSet();
      final (Map<String, ProductModel>? products, Failure? failure) =
          await _fetchProducts(ids);
      if (!ref.mounted) return ResumeOutcome.fail('Cancelled.');
      if (products == null) {
        return ResumeOutcome(ApiFailure<HeldOrder>(failure!));
      }

      final List<CartItem> cart = <CartItem>[];
      final List<String> warnings = <String>[];

      for (final HeldItem hi in held.items) {
        final ProductModel? p = products[hi.productId];
        if (p == null) {
          warnings.add('an unavailable item');
          continue;
        }
        ProductVariant? variant;
        if (hi.variantId != null) {
          variant = p.variants
              .where((ProductVariant v) => v.id == hi.variantId)
              .firstOrNull;
          if (variant == null) {
            warnings.add('${p.name} (variant removed)');
            continue;
          }
        }
        final String name = variant == null
            ? p.name
            : '${p.name} — ${variant.displayName}';
        final int stock = variant?.stock ?? p.effectiveStock;
        if (stock <= 0) {
          warnings.add('$name (out of stock)');
          continue;
        }
        final int qty = math.min(hi.quantity, stock);
        if (qty < hi.quantity) warnings.add('$name (only $stock left)');

        final CartItem line = CartItem(
          productId: p.id,
          variantId: variant?.id,
          name: name,
          sku: variant?.sku ?? p.sku,
          price: variant?.price ?? p.price,
          maxStock: stock,
          qty: qty,
          image: variant?.image ?? p.image,
        );
        if (cart.every((CartItem c) => c.key != line.key)) cart.add(line);
      }

      if (cart.isEmpty) {
        return ResumeOutcome.fail(
          'None of the items in this held sale are available right now.',
        );
      }

      final ApiResult<HeldOrder> result = await _repo.resume(held.id);
      if (!ref.mounted) return ResumeOutcome(result);
      if (result is! ApiSuccess<HeldOrder>) return ResumeOutcome(result);

      // Customer: list API object deta hai; na ho to id se basic customer.
      final CustomerModel? customer =
          held.customer ??
          (held.customerId != null
              ? CustomerModel(id: held.customerId!, name: 'Customer', phone: '')
              : null);

      ref
          .read(billingViewModelProvider.notifier)
          .restore(cart, customer: customer);
      state = state.copyWith(
        items: state.items.where((HeldOrder o) => o.id != held.id).toList(),
      );
      return ResumeOutcome(result, warnings: warnings);
    } finally {
      _setBusy(held.id, false);
    }
  }

  Future<(Map<String, ProductModel>?, Failure?)> _fetchProducts(
    Set<String> ids,
  ) async {
    final Map<String, ProductModel> found = <String, ProductModel>{};
    int page = 1;
    while (page <= _maxPages) {
      final ApiResult<ProductPage> result = await ref
          .read(productRepositoryProvider)
          .getProducts(page: page, limit: _pageSize);
      final ProductPage? data = result.dataOrNull;
      if (data == null) return (null, result.failureOrNull);

      for (final ProductModel p in data.items) {
        if (ids.contains(p.id)) found[p.id] = p;
      }
      if (found.length >= ids.length || !data.hasMore) break;
      page++;
    }
    return (found, null);
  }

  Future<ApiResult<HeldOrder>> cancel(HeldOrder held) async {
    if (state.busyIds.contains(held.id)) {
      return const ApiFailure<HeldOrder>(Failure(message: 'Please wait...'));
    }
    _setBusy(held.id, true);
    final ApiResult<HeldOrder> result = await _repo.cancel(held.id);
    if (!ref.mounted) return result;
    if (result is ApiSuccess<HeldOrder>) {
      state = state.copyWith(
        items: state.items.where((HeldOrder o) => o.id != held.id).toList(),
      );
    }
    _setBusy(held.id, false);
    return result;
  }
}

final NotifierProvider<HeldViewModel, HeldState> heldViewModelProvider =
    NotifierProvider<HeldViewModel, HeldState>(HeldViewModel.new);
