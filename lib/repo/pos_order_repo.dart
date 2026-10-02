import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/failure.dart';
import '../model/pos_history_model.dart';

/// POS orders ka data layer. Aage createPosOrder, receipt, held orders
/// bhi isi mein judenge.
class OrderRepo {
  const OrderRepo(this._api);

  final ApiService _api;

  /// GET /orders/pos/history?page=1&limit=20
  ///
  /// Response: `{ "data": [...], "pagination": {...} }`. Pagination `data` ke
  /// bahar hai, isliye `bodyParser` (poori body) use hota hai.
  Future<ApiResult<PosOrderPage>> getPosOrderHistory({
    int page = 1,
    int limit = AppConstants.pageSize,
    CancelToken? cancelToken,
  }) {
    return _api.get<PosOrderPage>(
      ApiUrls.posOrderHistory,
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      cancelToken: cancelToken,
      bodyParser: (dynamic body) =>
          PosOrderPage.fromJson(Map<String, dynamic>.from(body as Map)),
    );
  }
}

final Provider<OrderRepo> orderRepoProvider = Provider<OrderRepo>(
      (Ref ref) => OrderRepo(ref.watch(apiServiceProvider)),
);