import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/billing_model.dart';
import 'package:shopzo_pos/model/exchange_model.dart';
import 'package:shopzo_pos/model/pos_history_model.dart';
import 'package:shopzo_pos/model/product_model.dart';
import 'package:shopzo_pos/repo/exchange_repo.dart';
import 'package:shopzo_pos/repo/product_repo.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/pos_history_viewmodel.dart';

enum PreviewStatus { idle, loading, ready, error }

@immutable
class ExchangeState {
  const ExchangeState({
    this.order,
    this.itemId,
    this.qty = 1,
    this.product,
    this.variant,
    this.previewStatus = PreviewStatus.idle,
    this.preview,
    this.previewFailure,
    this.query = '',
    this.products = const <ProductModel>[],
    this.isSearching = false,
    this.searchFailure,
    this.isSubmitting = false,
  });

  final PosOrder? order;

  /// Return hone wali order line (orderItemId).
  final String? itemId;
  final int qty;

  /// Naya item.
  final ProductModel? product;
  final ProductVariant? variant;

  final PreviewStatus previewStatus;
  final ExchangePreview? preview;
  final Failure? previewFailure;

  final String query;
  final List<ProductModel> products;
  final bool isSearching;
  final Failure? searchFailure;

  final bool isSubmitting;

  OrderLine? get selectedLine {
    final PosOrder? o = order;
    if (o == null || itemId == null) return null;
    return o.items.where((OrderLine l) => l.id == itemId).firstOrNull;
  }

  int get maxQty {
    final int r = selectedLine?.remaining ?? 1;
    return r < 1 ? 1 : r;
  }

  bool get hasNewItem {
    final ProductModel? p = product;
    if (p == null) return false;
    final bool needsVariant = p.hasVariants && p.variants.isNotEmpty;
    return !needsVariant || variant != null;
  }

  String? get newItemLabel {
    final ProductModel? p = product;
    if (p == null) return null;
    final ProductVariant? v = variant;
    return v == null ? p.name : '${p.name} — ${v.displayName}';
  }

  double? get newItemPrice {
    final ProductModel? p = product;
    if (p == null) return null;
    return variant?.price ?? p.price;
  }

  ExchangeState copyWith({
    PosOrder? order,
    String? itemId,
    int? qty,
    ProductModel? product,
    ProductVariant? variant,
    bool clearNewItem = false,
    PreviewStatus? previewStatus,
    ExchangePreview? preview,
    bool clearPreview = false,
    Failure? previewFailure,
    bool clearPreviewFailure = false,
    String? query,
    List<ProductModel>? products,
    bool? isSearching,
    Failure? searchFailure,
    bool clearSearchFailure = false,
    bool? isSubmitting,
  }) {
    return ExchangeState(
      order: order ?? this.order,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      product: clearNewItem ? null : (product ?? this.product),
      variant: clearNewItem ? null : (variant ?? this.variant),
      previewStatus: previewStatus ?? this.previewStatus,
      preview: clearPreview ? null : (preview ?? this.preview),
      previewFailure:
      clearPreviewFailure ? null : (previewFailure ?? this.previewFailure),
      query: query ?? this.query,
      products: products ?? this.products,
      isSearching: isSearching ?? this.isSearching,
      searchFailure:
      clearSearchFailure ? null : (searchFailure ?? this.searchFailure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class ExchangeViewModel extends Notifier<ExchangeState> {
  int _previewId = 0;
  int _searchId = 0;
  Timer? _debounce;

  ExchangeRepo get _exchange => ref.read(exchangeRepoProvider);
  ProductRepository get _products => ref.read(productRepositoryProvider);

  @override
  ExchangeState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ExchangeState();
  }

  /// Screen khulte hi call karo. Pehli exchange-yogya line select ho jaati hai.
  void start(PosOrder order) {
    final OrderLine? first =
        order.items.where((OrderLine l) => l.canExchange).firstOrNull;
    state = ExchangeState(order: order, itemId: first?.id);
    unawaited(_search(''));
  }

  // ── Return item ──────────────────────────────────────────────────────────

  void selectItem(String id) {
    final OrderLine? line =
        state.order?.items.where((OrderLine l) => l.id == id).firstOrNull;
    if (line == null || !line.canExchange || id == state.itemId) return;
    state = state.copyWith(itemId: id, qty: 1);
    unawaited(_refreshPreview());
  }

  void setQty(int q) {
    final int max = state.maxQty;
    final int v = q < 1 ? 1 : (q > max ? max : q);
    if (v == state.qty) return;
    state = state.copyWith(qty: v);
    unawaited(_refreshPreview());
  }

  // ── New item ─────────────────────────────────────────────────────────────

  void setSearch(String value) {
    state = state.copyWith(query: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String q) async {
    final int id = ++_searchId;
    state = state.copyWith(
      query: q,
      isSearching: true,
      clearSearchFailure: true,
    );

    final ApiResult<ProductPage> result =
    await _products.getProducts(page: 1, limit: 20, search: q);
    if (!ref.mounted || id != _searchId) return;

    final ProductPage? page = result.dataOrNull;
    if (page != null) {
      state = state.copyWith(products: page.items, isSearching: false);
    } else {
      state = state.copyWith(
        isSearching: false,
        searchFailure: result.failureOrNull,
      );
    }
  }

  void selectProduct(ProductModel product, {ProductVariant? variant}) {
    state = state
        .copyWith(clearNewItem: true)
        .copyWith(product: product, variant: variant);
    unawaited(_refreshPreview());
  }

  void clearNewItem() {
    _previewId++;
    state = state.copyWith(
      clearNewItem: true,
      clearPreview: true,
      clearPreviewFailure: true,
      previewStatus: PreviewStatus.idle,
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────────

  Future<void> retryPreview() => _refreshPreview();

  Future<void> _refreshPreview() async {
    final ExchangeState s = state;
    final int id = ++_previewId;

    if (s.itemId == null || !s.hasNewItem) {
      state = s.copyWith(
        previewStatus: PreviewStatus.idle,
        clearPreview: true,
        clearPreviewFailure: true,
      );
      return;
    }

    state = s.copyWith(
      previewStatus: PreviewStatus.loading,
      clearPreview: true,
      clearPreviewFailure: true,
    );

    final ApiResult<ExchangePreview> result = await _exchange.preview(
      orderItemId: s.itemId!,
      quantity: s.qty,
      newProductId: s.product!.id,
      newVariantId: s.variant?.id,
    );
    if (!ref.mounted || id != _previewId) return;

    final ExchangePreview? data = result.dataOrNull;
    if (data != null) {
      state = state.copyWith(
        previewStatus: PreviewStatus.ready,
        preview: data,
        clearPreviewFailure: true,
      );
    } else {
      state = state.copyWith(
        previewStatus: PreviewStatus.error,
        previewFailure: result.failureOrNull,
      );
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<ApiResult<ExchangeResult>> submit({
    List<ExchangePayment> payments = const <ExchangePayment>[],
    PaymentMethod refundMethod = PaymentMethod.cash,
    String? reason,
  }) async {
    final ExchangeState s = state;
    final ExchangePreview? preview = s.preview;

    if (s.isSubmitting) {
      return ApiFailure<ExchangeResult>(
        const Failure(message: 'Please wait, the exchange is being processed.'),
      );
    }
    if (s.itemId == null || !s.hasNewItem || preview == null) {
      return ApiFailure<ExchangeResult>(
        const Failure(message: 'Select the item to return and the new item first.'),
      );
    }

    state = s.copyWith(isSubmitting: true);

    final ExchangeAction action = preview.action;
    final ApiResult<ExchangeResult> result = await _exchange.create(
      ExchangeRequest(
        orderItemId: s.itemId!,
        quantity: s.qty,
        newProductId: s.product!.id,
        newVariantId: s.variant?.id,
        payments: action == ExchangeAction.collect
            ? payments
            : const <ExchangePayment>[],
        refundMethod: action == ExchangeAction.refund ? refundMethod : null,
        reason: reason,
      ),
    );

    if (!ref.mounted) return result;
    state = state.copyWith(isSubmitting: false);

    if (result is ApiSuccess<ExchangeResult>) {
      // Order history (returnedQty / naya order) aur product stock dono refresh.
      unawaited(ref.read(orderHistoryViewModelProvider.notifier).refresh());
      unawaited(ref.read(posProductsProvider.notifier).load(refresh: true));
    }
    return result;
  }
}

final exchangeViewModelProvider =
NotifierProvider.autoDispose<ExchangeViewModel, ExchangeState>(
  ExchangeViewModel.new,
);