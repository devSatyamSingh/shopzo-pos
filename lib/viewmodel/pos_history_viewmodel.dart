import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failure.dart';
import '../model/pos_history_model.dart';
import '../repo/pos_order_repo.dart';
import 'auth_viewmodel.dart';

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

  final List<PosOrder> orders;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Failure? failure;
  final Failure? loadMoreFailure;
  final int page;
  final bool hasMore;
  final int total;
  final OrderFilter filter;
  final String query;

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

class OrderHistoryViewModel extends Notifier<OrderHistoryState> {
  CancelToken _cancel = CancelToken();
  OrderRepo get _repo => ref.read(orderRepoProvider);

  @override
  OrderHistoryState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    ref.onDispose(() => token.cancel('disposed'));
    final String? userId = ref.watch(
      authViewModelProvider.select((AuthState s) => s.user?.id),
    );
    if (userId == null) return const OrderHistoryState();

    Future<void>.microtask(_fetchFirstPage);
    return const OrderHistoryState(isLoading: true);
  }

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

  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    await _fetchFirstPage();
  }

  Future<ApiResult<PosOrderPage>> refresh() {
    state = state.copyWith(isRefreshing: true, clearLoadMoreFailure: true);
    return _fetchFirstPage();
  }

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

  List<PosOrder> _merge(List<PosOrder> current, List<PosOrder> incoming) {
    final Set<String> seen = current.map((PosOrder o) => o.id).toSet();
    return <PosOrder>[
      ...current,
      ...incoming.where((PosOrder o) => seen.add(o.id)),
    ];
  }

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