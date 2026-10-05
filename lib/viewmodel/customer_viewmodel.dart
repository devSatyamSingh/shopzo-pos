import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failure.dart';
import '../model/customer_model.dart';
import '../repo/customer_repo.dart';

class CustomerSearchState {
  const CustomerSearchState({
    this.query = '',
    this.results = const <CustomerModel>[],
    this.isLoading = false,
    this.failure,
  });

  final String query;
  final List<CustomerModel> results;
  final bool isLoading;
  final Failure? failure;
  static const int minDigits = 3;

  bool get isSearching => query.length >= minDigits;

  CustomerSearchState copyWith({
    String? query,
    List<CustomerModel>? results,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CustomerSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Phone se customer search (350ms debounce) aur quick create.
class CustomerSearchViewModel extends Notifier<CustomerSearchState> {
  Timer? _debounce;
  int _requestId = 0;

  CustomerRepo get _repo => ref.read(customerRepoProvider);

  @override
  CustomerSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const CustomerSearchState();
  }

  void onChanged(String value) {
    _debounce?.cancel();
    final String q = value.trim();
    _requestId++;

    if (q.length < CustomerSearchState.minDigits) {
      state = CustomerSearchState(query: q);
      return;
    }
    state = CustomerSearchState(query: q, isLoading: true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final int id = ++_requestId;
    final ApiResult<List<CustomerModel>> result = await _repo.searchByPhone(q);
    if (!ref.mounted || id != _requestId) return;

    final List<CustomerModel>? data = result.dataOrNull;
    state = data != null
        ? state.copyWith(isLoading: false, results: data, clearFailure: true)
        : state.copyWith(
      isLoading: false,
      results: const <CustomerModel>[],
      failure: result.failureOrNull,
    );
  }

  void clear() {
    _debounce?.cancel();
    _requestId++;
    state = const CustomerSearchState();
  }

  Future<ApiResult<CustomerModel>> create({
    required String name,
    required String phone,
  }) {
    return _repo.quickCreate(name: name.trim(), phone: phone.trim());
  }
}

final NotifierProvider<CustomerSearchViewModel, CustomerSearchState>
customerSearchProvider = NotifierProvider<CustomerSearchViewModel, CustomerSearchState>(
  CustomerSearchViewModel.new,
);