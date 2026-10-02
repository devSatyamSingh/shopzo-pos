import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failure.dart';
import '../model/pos_history_model.dart';
import '../repo/pos_order_repo.dart';
import 'auth_viewmodel.dart';

/// Status chips. Filter abhi loaded orders par local chalta hai.
enum OrderFilter {
  all,
  completed,
  pending,
  refunded,
  cancelled;

  String get label {
    switch (this) {
      case OrderFilter.all:
        return 'All';
      case OrderFilter.completed:
        return 'Completed';
      case OrderFilter.pending:
        return 'Pending';
      case OrderFilter.refunded:
        return 'Refunded';
      case OrderFilter.cancelled:
        return 'Cancelled';
    }
  }

  bool matches(PosOrder o) {
    switch (this) {
      case OrderFilter.all:
        return true;
      case OrderFilter.completed:
        return o.status == OrderStatus.completed;
      case OrderFilter.pending:
        return o.status == OrderStatus.pending;
      case OrderFilter.refunded:
        return o.status == OrderStatus.refunded;
      case OrderFilter.cancelled:
        return o.status == OrderStatus.cancelled;
    }
  }
}

@immutable
class OrderHistoryState {
  const OrderHistoryState({
    this.orders = const <PosOrder>[],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.failure,
    this.loadMoreFailure,
    this.page = 0,
    this.hasMore = false,
    this.total = 0,
    this.filter = OrderFilter.all,
    this.query = '',
  });

  /// Ab tak load hue saare orders (sab pages).
  final List<PosOrder> orders;

  /// Pehli baar load: skeleton dikhta hai.
  final bool isLoading;

  /// Pull-to-refresh chal raha hai.
  final bool isRefreshing;

  /// Neeche scroll karke agla page aa raha hai.
  final bool isLoadingMore;

  /// Pehle load ka error. Orders khali ho tabhi full-screen error dikhta hai.
  final Failure? failure;

  /// Agle page ka error (footer mein Retry).
  final Failure? loadMoreFailure;

  final int page;
  final bool hasMore;

  /// Server ke hisaab se total orders.
  final int total;
  final OrderFilter filter;
  final String query;

  /// Filter + search lagakar jo dikhana hai.
  List<PosOrder> get visible {
    final String q = query.trim().toLowerCase();
    return orders.where((PosOrder o) {
      if (!filter.matches(o)) return false;
      if (q.isEmpty) return true;
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.cashierName.toLowerCase().contains(q);
    }).toList();
  }

  /// Chip ke saath count. Agle pages baaki hon to count galat hoga, isliye null.
  int? countOf(OrderFilter f) {
    if (hasMore) return null;
    return orders.where(f.matches).length;
  }

  OrderHistoryState copyWith({
    List<PosOrder>? orders,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Failure? failure,
    Failure? loadMoreFailure,
    int? page,
    bool? hasMore,
    int? total,
    OrderFilter? filter,
    String? query,
    bool clearFailure = false,
    bool clearLoadMoreFailure = false,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      loadMoreFailure:
      clearLoadMoreFailure ? null : (loadMoreFailure ?? this.loadMoreFailure),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      filter: filter ?? this.filter,
      query: query ?? this.query,
    );
  }
}

/// Order History ka pura logic: pehla load, pull-to-refresh, agla page,
/// filter aur search.
///
/// Logged-in user badalte hi (logout / login) state apne aap reset ho jati hai,
/// isliye naye user ko purana data nahi dikhta.
class OrderHistoryViewModel extends Notifier<OrderHistoryState> {
  CancelToken _cancel = CancelToken();

  OrderRepo get _repo => ref.read(orderRepoProvider);

  @override
  OrderHistoryState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    // Provider dispose / rebuild par chalti request cancel, purana response ignore.
    ref.onDispose(() => token.cancel('disposed'));

    final String? userId = ref.watch(
      authViewModelProvider.select((AuthState s) => s.user?.id),
    );
    if (userId == null) return const OrderHistoryState();

    Future<void>.microtask(_fetchFirstPage);
    return const OrderHistoryState(isLoading: true);
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Page 1 laata hai aur list replace karta hai.
  Future<ApiResult<PosOrderPage>> _fetchFirstPage() async {
    final CancelToken token = _cancel;
    final ApiResult<PosOrderPage> result =
    await _repo.getPosOrderHistory(page: 1, cancelToken: token);
    if (token.isCancelled) return result;

    if (result is ApiSuccess<PosOrderPage>) {
      final PosOrderPage page = result.data;
      state = state.copyWith(
        orders: page.items,
        page: page.pageInfo.page,
        hasMore: page.pageInfo.hasMore,
        total: page.pageInfo.total,
        isLoading: false,
        isRefreshing: false,
        clearFailure: true,
        clearLoadMoreFailure: true,
      );
    } else if (result is ApiFailure<PosOrderPage>) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        failure: result.failure,
      );
    }
    return result;
  }

  /// Error screen ke "Try again" se: skeleton dikhakar dobara.
  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    await _fetchFirstPage();
  }

  /// Pull-to-refresh. Result wapas aata hai taaki UI error bubble dikha sake.
  /// Fail hone par purani list screen par rehti hai.
  Future<ApiResult<PosOrderPage>> refresh() {
    state = state.copyWith(isRefreshing: true, clearLoadMoreFailure: true);
    return _fetchFirstPage();
  }

  /// Scroll neeche pahunchne par agla page. Ek time pe ek hi request chalti hai.
  /// Pichla load-more fail hua ho to sirf `retry: true` se dobara chalega.
  Future<void> loadMore({bool retry = false}) async {
    if (state.isLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    if (state.loadMoreFailure != null && !retry) return;

    final CancelToken token = _cancel;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreFailure: true);

    final ApiResult<PosOrderPage> result = await _repo.getPosOrderHistory(
      page: state.page + 1,
      cancelToken: token,
    );
    if (token.isCancelled) return;

    if (result is ApiSuccess<PosOrderPage>) {
      final PosOrderPage page = result.data;
      state = state.copyWith(
        orders: _merge(state.orders, page.items),
        page: page.pageInfo.page,
        hasMore: page.pageInfo.hasMore,
        total: page.pageInfo.total,
        isLoadingMore: false,
      );
    } else if (result is ApiFailure<PosOrderPage>) {
      debugPrint('OrderHistory loadMore failed: ${result.failure}');
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreFailure: result.failure,
      );
    }
  }

  /// Naye orders beech me aa jaye (pagination shift) to duplicate na dikhe.
  List<PosOrder> _merge(List<PosOrder> current, List<PosOrder> incoming) {
    final Set<String> seen = current.map((PosOrder o) => o.id).toSet();
    return <PosOrder>[
      ...current,
      ...incoming.where((PosOrder o) => seen.add(o.id)),
    ];
  }

  // ── Filter / search ──────────────────────────────────────────────────────

  void setFilter(OrderFilter filter) {
    if (filter != state.filter) state = state.copyWith(filter: filter);
  }

  void setQuery(String query) {
    if (query != state.query) state = state.copyWith(query: query);
  }
}

final NotifierProvider<OrderHistoryViewModel, OrderHistoryState>
orderHistoryViewModelProvider =
NotifierProvider<OrderHistoryViewModel, OrderHistoryState>(
  OrderHistoryViewModel.new,
);