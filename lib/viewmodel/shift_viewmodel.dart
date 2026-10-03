import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../model/pos_history_model.dart';
import '../model/shift_model.dart';
import '../repo/pos_order_repo.dart';
import '../repo/shift_repo.dart';
import 'auth_viewmodel.dart';

enum ShiftPhase { checking, none, open, error }

@immutable
class ShiftState {
  const ShiftState({
    this.phase = ShiftPhase.checking,
    this.shift,
    this.failure,
    this.isSubmitting = false,
    this.summary,
    this.isSummaryLoading = false,
    this.summaryFailure,
    this.closedShift,
    this.closedSummary,
  });

  final ShiftPhase phase;
  final Shift? shift;
  final Failure? failure;
  final bool isSubmitting;
  final ShiftSummary? summary;
  final bool isSummaryLoading;
  final Failure? summaryFailure;
  final Shift? closedShift;
  final ShiftSummary? closedSummary;
  bool get hasOpenShift => phase == ShiftPhase.open && shift != null;

  ShiftState copyWith({
    ShiftPhase? phase,
    Shift? shift,
    Failure? failure,
    bool? isSubmitting,
    ShiftSummary? summary,
    bool? isSummaryLoading,
    Failure? summaryFailure,
    bool clearShift = false,
    bool clearFailure = false,
    bool clearSummary = false,
    bool clearSummaryFailure = false,
  }) {
    return ShiftState(
      phase: phase ?? this.phase,
      shift: clearShift ? null : (shift ?? this.shift),
      failure: clearFailure ? null : (failure ?? this.failure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      summary: clearSummary ? null : (summary ?? this.summary),
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      summaryFailure: clearSummaryFailure
          ? null
          : (summaryFailure ?? this.summaryFailure),
      closedShift: closedShift,
      closedSummary: closedSummary,
    );
  }
}

class ShiftViewModel extends Notifier<ShiftState> {
  CancelToken _cancel = CancelToken();

  ShiftRepo get _repo => ref.read(shiftRepoProvider);
  OrderRepo get _orders => ref.read(orderRepoProvider);

  @override
  ShiftState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    ref.onDispose(() => token.cancel('disposed'));
    final String? userId = ref.watch(
      authViewModelProvider.select((AuthState s) => s.user?.id),
    );
    if (userId == null) return const ShiftState(phase: ShiftPhase.none);

    Future<void>.microtask(() => refreshActive());
    return const ShiftState(phase: ShiftPhase.checking);
  }

  Future<void> refreshActive({bool silent = false}) async {
    if (silent && (state.phase == ShiftPhase.checking || state.isSubmitting)) {
      return;
    }
    final CancelToken token = _cancel;
    if (!silent) {
      state = state.copyWith(phase: ShiftPhase.checking, clearFailure: true);
    }

    final ApiResult<Shift?> result = await _repo.getActiveShift(
      cancelToken: token,
    );
    if (token.isCancelled) return;

    if (result is ApiSuccess<Shift?>) {
      final Shift? shift = result.data;
      if (shift != null && shift.isOpen) {
        state = state.copyWith(
          phase: ShiftPhase.open,
          shift: shift,
          clearFailure: true,
        );
      } else {
        state = state.copyWith(
          phase: ShiftPhase.none,
          clearShift: true,
          clearFailure: true,
        );
      }
    } else if (result is ApiFailure<Shift?> && !silent) {
      state = state.copyWith(phase: ShiftPhase.error, failure: result.failure);
    }
  }

  Future<ApiResult<Shift>> openShift(double openingCash) async {
    if (state.isSubmitting) {
      return const ApiFailure<Shift>(
        Failure(message: 'Please wait, shift is being opened.'),
      );
    }

    final CancelToken token = _cancel;
    state = state.copyWith(isSubmitting: true, clearFailure: true);

    final ApiResult<Shift> result = await _repo.openShift(
      openingCash: openingCash,
      cancelToken: token,
    );
    if (token.isCancelled) return result;

    if (result is ApiSuccess<Shift>) {
      state = ShiftState(phase: ShiftPhase.open, shift: result.data);
    } else if (result is ApiFailure<Shift>) {
      state = state.copyWith(isSubmitting: false, failure: result.failure);
      final Failure f = result.failure;
      if (f.type == FailureType.conflict ||
          (f.type == FailureType.badRequest &&
              f.message.toLowerCase().contains('already'))) {
        unawaited(refreshActive(silent: true));
      }
    }
    return result;
  }

  Future<void> loadSummary() async {
    final Shift? shift = state.shift;
    final DateTime? since = shift?.openedAt;
    if (shift == null || since == null || state.isSummaryLoading) return;
    final CancelToken token = _cancel;
    state = state.copyWith(isSummaryLoading: true, clearSummaryFailure: true);
    final ApiResult<List<PosOrder>> result = await _orders.getOrdersSince(
      since: since,
      cancelToken: token,
    );
    if (token.isCancelled) return;
    if (result is ApiSuccess<List<PosOrder>>) {
      final String me = (ref.read(currentUserProvider)?.name ?? '')
          .trim()
          .toLowerCase();
      final Iterable<PosOrder> mine = me.isEmpty
          ? result.data
          : result.data.where(
              (PosOrder o) => o.cashierName.trim().toLowerCase() == me,
            );
      state = state.copyWith(
        isSummaryLoading: false,
        summary: ShiftSummary.fromOrders(mine),
      );
    } else if (result is ApiFailure<List<PosOrder>>) {
      state = state.copyWith(
        isSummaryLoading: false,
        summaryFailure: result.failure,
      );
    }
  }

  Future<ApiResult<Shift>> closeShift(double closingCash) async {
    final Shift? shift = state.shift;
    if (shift == null) {
      return const ApiFailure<Shift>(
        Failure(message: 'There is no open shift to close.'),
      );
    }
    if (state.isSubmitting) {
      return const ApiFailure<Shift>(
        Failure(message: 'Please wait, shift is being closed.'),
      );
    }

    final CancelToken token = _cancel;
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final ApiResult<Shift> result = await _repo.closeShift(
      shiftId: shift.id,
      closingCash: closingCash,
      cancelToken: token,
    );
    if (token.isCancelled) return result;
    if (result is ApiSuccess<Shift>) {
      state = ShiftState(
        phase: ShiftPhase.none,
        closedShift: result.data,
        closedSummary: state.summary,
      );
    } else if (result is ApiFailure<Shift>) {
      state = state.copyWith(isSubmitting: false, failure: result.failure);
      if (result.failure.type == FailureType.notFound ||
          result.failure.type == FailureType.conflict) {
        unawaited(refreshActive(silent: true));
      }
    }
    return result;
  }

  void dismissClosedReport() {
    state = ShiftState(phase: state.phase, shift: state.shift);
  }
}

final NotifierProvider<ShiftViewModel, ShiftState> shiftViewModelProvider =
    NotifierProvider<ShiftViewModel, ShiftState>(ShiftViewModel.new);
final Provider<Shift?> activeShiftProvider = Provider<Shift?>(
  (Ref ref) =>
      ref.watch(shiftViewModelProvider.select((ShiftState s) => s.shift)),
);

final Provider<bool> hasOpenShiftProvider = Provider<bool>(
  (Ref ref) => ref.watch(
    shiftViewModelProvider.select((ShiftState s) => s.hasOpenShift),
  ),
);
