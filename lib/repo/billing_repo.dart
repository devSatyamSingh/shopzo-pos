import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/billing_model.dart';
import '../model/recipt_model.dart';

class BillingRepo {
  const BillingRepo(this._api);
  final ApiService _api;

  Future<ApiResult<CreatedOrder>> createOrder({
    required List<CartItem> items,
    required List<PaymentLine> payments,
    String? customerId,
    CancelToken? cancelToken,
  }) {
    return _api.post<CreatedOrder>(
      ApiUrls.createPosOrder,
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (final CartItem i in items) i.toOrderJson(),
        ],
        if (customerId != null) 'customerId': customerId,
        'payments': <Map<String, dynamic>>[
          for (final PaymentLine p in payments) p.toJson(),
        ],
      },
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          CreatedOrder.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ApiResult<Receipt>> getReceipt(
      String orderId, {
        CancelToken? cancelToken,
      }) {
    return _api.get<Receipt>(
      ApiUrls.orderReceipt(orderId),
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          Receipt.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}

final Provider<BillingRepo> billingRepoProvider = Provider<BillingRepo>(
      (Ref ref) => BillingRepo(ref.watch(apiServiceProvider)),
);