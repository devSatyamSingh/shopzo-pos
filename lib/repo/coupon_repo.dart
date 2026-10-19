import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/api/api_service.dart';
import 'package:shopzo_pos/api/api_urls.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/coupon_model.dart';

import '../model/coupon_model.dart';

class CouponRepository {
  const CouponRepository(this._api);

  final ApiService _api;

  /// GET /coupons  ->  { data: [ ... ] }
  Future<ApiResult<List<CouponModel>>> getCoupons() {
    return _api.get<List<CouponModel>>(
      ApiUrls.coupons,
      parser: (dynamic data) {
        if (data is! List) return const <CouponModel>[];
        return data
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> m) =>
              CouponModel.fromJson(Map<String, dynamic>.from(m)),
        )
            .toList();
      },
    );
  }
}

final Provider<CouponRepository> couponRepositoryProvider =
Provider<CouponRepository>(
      (Ref ref) => CouponRepository(ref.watch(apiServiceProvider)),
);