import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/failure.dart';
import '../model/pos_history_model.dart';


class OrderRepo {
  const OrderRepo(this._api);

  final ApiService _api;

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

  Future<ApiResult<List<PosOrder>>> getOrdersSince({
    required DateTime since,
    int pageSize = 50,
    int maxPages = 10,
    CancelToken? cancelToken,
  }) async {
    final List<PosOrder> collected = <PosOrder>[];
    int page = 1;

    while (page <= maxPages) {
      final ApiResult<PosOrderPage> result = await getPosOrderHistory(
        page: page,
        limit: pageSize,
        cancelToken: cancelToken,
      );
      if (result is ApiFailure<PosOrderPage>) {
        return ApiFailure<List<PosOrder>>(result.failure);
      }

      final PosOrderPage data = (result as ApiSuccess<PosOrderPage>).data;
      bool reachedOlder = false;
      for (final PosOrder o in data.items) {
        final DateTime? at = o.createdAt;
        if (at != null && at.isBefore(since)) {
          reachedOlder = true;
          continue;
        }
        collected.add(o);
      }

      if (reachedOlder || !data.pageInfo.hasMore) break;
      page++;
    }

    return ApiSuccess<List<PosOrder>>(data: collected, statusCode: 200);
  }
}

final Provider<OrderRepo> orderRepoProvider = Provider<OrderRepo>(
      (Ref ref) => OrderRepo(ref.watch(apiServiceProvider)),
);