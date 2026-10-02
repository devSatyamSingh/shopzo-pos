import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/product_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';

import '../repo/product_repo.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Filter
// ═══════════════════════════════════════════════════════════════════════════

enum ProductFilter {
  all('All'),
  inStock('In stock'),
  lowStock('Low stock'),
  outOfStock('Out of stock');

  const ProductFilter(this.label);
  final String label;

  bool matches(ProductModel p) {
    switch (this) {
      case ProductFilter.all:
        return true;
      case ProductFilter.inStock:
        return p.stockLevel != StockLevel.out;
      case ProductFilter.lowStock:
        return p.stockLevel == StockLevel.low;
      case ProductFilter.outOfStock:
        return p.stockLevel == StockLevel.out;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════════════════

class ProductState {
  const ProductState({
    this.items = const <ProductModel>[],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.failure,
    this.search = '',
    this.filter = ProductFilter.all,
  });

  /// Ab tak load hue products (saare pages jod kar).
  final List<ProductModel> items;
  final int page;
  final int totalPages;

  /// Server ke hisaab se kul products.
  final int total;

  /// Pehli baar / naya load: skeleton dikhta hai.
  final bool isLoading;
  final bool isLoadingMore;
  final Failure? failure;
  final String search;
  final ProductFilter filter;

  bool get hasMore => page < totalPages;

  /// Filter + search lagakar jo list dikhani hai.
  /// Search yahan local bhi chalta hai, taaki type karte hi turant result dikhe
  /// (server ka result baad mein aakar list badal deta hai).
  List<ProductModel> get visible {
    final String q = search.trim().toLowerCase();
    return items.where((ProductModel p) {
      if (!filter.matches(p)) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q);
    }).toList();
  }

  /// Load hue products mein se kitne is filter mein aate hain.
  int count(ProductFilter f) => items.where(f.matches).length;

  ProductState copyWith({
    List<ProductModel>? items,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
    String? search,
    ProductFilter? filter,
  }) {
    return ProductState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      search: search ?? this.search,
      filter: filter ?? this.filter,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ViewModel
// ═══════════════════════════════════════════════════════════════════════════

class ProductViewModel extends Notifier<ProductState> {
  static const int _limit = 20;

  int _requestId = 0;
  Timer? _debounce;

  ProductRepository get _repo => ref.read(productRepositoryProvider);

  @override
  ProductState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future<void>.microtask(() => load());
    return const ProductState();
  }

  void setFilter(ProductFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
  }

  /// Type karte hi local filter turant chalta hai; server call 400ms ruk kar.
  void setSearch(String value) {
    if (value == state.search) return;
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => load(refresh: true));
  }

  /// [refresh] true (pull-to-refresh / search) ho to purani list screen par
  /// rehti hai, skeleton nahi aata.
  Future<void> load({bool refresh = false}) async {
    final int id = ++_requestId;

    if (!refresh) {
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        clearFailure: true,
        items: const <ProductModel>[],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }

    final ApiResult<ProductPage> result =
    await _repo.getProducts(page: 1, limit: _limit, search: state.search);

    // Beech mein naya load shuru ho gaya ya screen band ho gayi.
    if (!ref.mounted || id != _requestId) return;

    final ProductPage? data = result.dataOrNull;
    if (data != null) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        clearFailure: true,
        items: data.items,
        page: data.page,
        totalPages: data.totalPages,
        total: data.total,
      );
      return;
    }

    final Failure failure = result.failureOrNull!;
    if (state.items.isNotEmpty) {
      // Purani list hai: bubble dikhao, screen mat todo.
      AppUtils.showFailure(failure);
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        failure: failure,
      );
    }
  }

  /// Agla page (scroll ke end par ya "Load more" button se).
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final int id = _requestId;
    state = state.copyWith(isLoadingMore: true);

    final ApiResult<ProductPage> result = await _repo.getProducts(
      page: state.page + 1,
      limit: _limit,
      search: state.search,
    );

    if (!ref.mounted || id != _requestId) return;

    final ProductPage? data = result.dataOrNull;
    if (data == null) {
      AppUtils.showFailure(result.failureOrNull!);
      state = state.copyWith(isLoadingMore: false);
      return;
    }

    // Duplicate (same id) dobara na judein.
    final Set<String> known = state.items.map((ProductModel p) => p.id).toSet();
    state = state.copyWith(
      isLoadingMore: false,
      items: <ProductModel>[
        ...state.items,
        ...data.items.where((ProductModel p) => !known.contains(p.id)),
      ],
      page: data.page,
      totalPages: data.totalPages,
      total: data.total,
    );
  }
}

final NotifierProvider<ProductViewModel, ProductState> productViewModelProvider =
NotifierProvider<ProductViewModel, ProductState>(ProductViewModel.new);