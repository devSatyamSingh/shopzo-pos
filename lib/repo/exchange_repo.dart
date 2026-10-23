import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/exchange_model.dart';

class ExchangeRepo {
  const ExchangeRepo(this._api);

  final ApiService _api;

  /// POST /orders/pos/exchange/preview
  Future<ApiResult<ExchangePreview>> preview({
    required String orderItemId,
    required int quantity,
    required String newProductId,
    String? newVariantId,
    CancelToken? cancelToken,
  }) {
    return _api.post<ExchangePreview>(
      ApiUrls.exchangePreview,
      body: <String, dynamic>{
        'orderItemId': orderItemId,
        'quantity': quantity,
        'newProductId': newProductId,
        if (newVariantId != null) 'newVariantId': newVariantId,
      },
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          ExchangePreview.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  /// POST /orders/pos/exchange
  Future<ApiResult<ExchangeResult>> create(
      ExchangeRequest request, {
        CancelToken? cancelToken,
      }) {
    return _api.post<ExchangeResult>(
      ApiUrls.createExchange,
      body: request.toJson(),
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          ExchangeResult.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}

final Provider<ExchangeRepo> exchangeRepoProvider = Provider<ExchangeRepo>(
      (Ref ref) => ExchangeRepo(ref.watch(apiServiceProvider)),
);