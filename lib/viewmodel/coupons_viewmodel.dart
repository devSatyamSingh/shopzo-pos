import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/coupon_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';

import '../repo/coupon_repo.dart';

enum CouponLoadStatus { loading, ready, error }

@immutable
class CouponState {
  const CouponState({
    this.status = CouponLoadStatus.loading,
    this.coupons = const <CouponModel>[],
    this.failure,
  });

  final CouponLoadStatus status;
  final List<CouponModel> coupons;
  final Failure? failure;

  bool get isEmpty => coupons.isEmpty;

  CouponState copyWith({
    CouponLoadStatus? status,
    List<CouponModel>? coupons,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CouponState(
      status: status ?? this.status,
      coupons: coupons ?? this.coupons,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class CouponViewModel extends Notifier<CouponState> {
  @override
  CouponState build() => const CouponState();

  /// [silent] = true (pull-to-refresh): purani list dikhti rahegi, skeleton nahi.
  Future<void> load({bool silent = false}) async {
    if (!silent) state = const CouponState();

    final result = await ref.read(couponRepositoryProvider).getCoupons();

    switch (result) {
      case ApiSuccess<List<CouponModel>>(:final data):
        state = CouponState(
          status: CouponLoadStatus.ready,
          coupons: _sorted(data),
        );
      case ApiFailure<List<CouponModel>>(:final failure):
      // Silent refresh fail ho to purani list rakho, bas message dikhao.
        if (silent && state.status == CouponLoadStatus.ready) {
          AppUtils.showFailure(failure);
          return;
        }
        state = CouponState(
          status: CouponLoadStatus.error,
          failure: failure,
        );
    }
  }

  /// Usable coupons pehle, baaki baad me. Same group me naya pehle.
  List<CouponModel> _sorted(List<CouponModel> list) {
    final List<CouponModel> copy = List<CouponModel>.of(list);
    copy.sort((CouponModel a, CouponModel b) {
      if (a.isUsable != b.isUsable) return a.isUsable ? -1 : 1;
      final DateTime aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return copy;
  }
}

final NotifierProvider<CouponViewModel, CouponState> couponViewModelProvider =
NotifierProvider<CouponViewModel, CouponState>(CouponViewModel.new);