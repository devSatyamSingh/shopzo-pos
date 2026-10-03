import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/billing_model.dart';
import '../model/held_order_model.dart';

class HeldRepo {
  const HeldRepo(this._api);

  final ApiService _api;

  HeldOrder _one(dynamic data) =>
      HeldOrder.fromJson(Map<String, dynamic>.from(data as Map));

  Future<ApiResult<HeldOrder>> hold({
    required List<CartItem> items,
    String? customerId,
    String? note,
    CancelToken? cancelToken,
  }) {
    final String n = (note ?? '').trim();
    return _api.post<HeldOrder>(
      ApiUrls.holdOrder,
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (final CartItem i in items) i.toOrderJson(),
        ],
        if (customerId != null) 'customerId': customerId,
        if (n.isNotEmpty) 'note': n,
      },
      cancelToken: cancelToken,
      parser: _one,
    );
  }

  /// GET /pos/held-orders
  Future<ApiResult<List<HeldOrder>>> list({CancelToken? cancelToken}) {
    return _api.get<List<HeldOrder>>(
      ApiUrls.heldOrders,
      cancelToken: cancelToken,
      parser: (dynamic data) => <HeldOrder>[
        if (data is List)
          for (final dynamic o in data)
            if (o is Map) HeldOrder.fromJson(Map<String, dynamic>.from(o)),
      ],
    );
  }

  /// POST /pos/held-orders/{id}/resume  -> 200 "Order resumed"
  Future<ApiResult<HeldOrder>> resume(String id, {CancelToken? cancelToken}) {
    return _api.post<HeldOrder>(
      ApiUrls.resumeHeldOrder(id),
      cancelToken: cancelToken,
      parser: _one,
    );
  }

  Future<ApiResult<HeldOrder>> cancel(String id, {CancelToken? cancelToken}) {
    return _api.delete<HeldOrder>(
      ApiUrls.cancelHeldOrder(id),
      cancelToken: cancelToken,
      parser: _one,
    );
  }
}

final Provider<HeldRepo> heldRepoProvider = Provider<HeldRepo>(
      (Ref ref) => HeldRepo(ref.watch(apiServiceProvider)),
);