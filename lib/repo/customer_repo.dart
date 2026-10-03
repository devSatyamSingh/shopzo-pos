import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/customer_model.dart';

class CustomerRepo {
  const CustomerRepo(this._api);

  final ApiService _api;

  Future<ApiResult<List<CustomerModel>>> searchByPhone(
    String phone, {
    CancelToken? cancelToken,
  }) {
    return _api.get<List<CustomerModel>>(
      ApiUrls.searchCustomer,
      queryParameters: <String, dynamic>{'phone': phone},
      cancelToken: cancelToken,
      parser: (dynamic data) => <CustomerModel>[
        if (data is List)
          for (final dynamic c in data)
            if (c is Map) CustomerModel.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }

  Future<ApiResult<CustomerModel>> quickCreate({
    required String name,
    required String phone,
    CancelToken? cancelToken,
  }) {
    return _api.post<CustomerModel>(
      ApiUrls.quickCreateCustomer,
      body: <String, dynamic>{'name': name, 'phone': phone},
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          CustomerModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}

final Provider<CustomerRepo> customerRepoProvider = Provider<CustomerRepo>(
  (Ref ref) => CustomerRepo(ref.watch(apiServiceProvider)),
);
