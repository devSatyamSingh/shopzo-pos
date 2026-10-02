import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ Apne project ke hisaab se path adjust karna (jahan api_service.dart / api_urls.dart hain).
import 'package:shopzo_pos/api/api_service.dart';
import 'package:shopzo_pos/api/api_urls.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/product_model.dart';

/// POS products. Exception kabhi bahar nahi aata, hamesha [ApiResult].
class ProductRepository {
  const ProductRepository(this._api);

  final ApiService _api;

  /// GET /products/pos/search?page=1&limit=20&search=...
  ///
  /// ⚠️ Query param ke naam (`page`, `limit`, `search`) mera andaza hain,
  /// Postman ke Params tab se match kar lena.
  Future<ApiResult<ProductPage>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    CancelToken? cancelToken,
  }) {
    final String q = (search ?? '').trim();
    return _api.get<ProductPage>(
      ApiUrls.posProducts,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (q.isNotEmpty) 'search': q,
      },
      cancelToken: cancelToken,
      bodyParser: (dynamic body) =>
          ProductPage.fromJson(Map<String, dynamic>.from(body as Map)),
    );
  }
}

final Provider<ProductRepository> productRepositoryProvider =
Provider<ProductRepository>(
      (Ref ref) => ProductRepository(ref.watch(apiServiceProvider)),
);