import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shopzo_pos/api/api_service.dart';
import 'package:shopzo_pos/api/api_urls.dart';
import 'package:shopzo_pos/core/errors/failure.dart';

import '../model/dashboard_model.dart';

class DashboardRepository {
  const DashboardRepository(this._api);

  final ApiService _api;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  Future<ApiResult<DailySalesReport>> getDailySales({
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) {
    return _api.get<DailySalesReport>(
      ApiUrls.dailySalesReport,
      queryParameters: <String, dynamic>{
        'from': _fmt.format(from),
        'to': _fmt.format(to),
      },
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          DailySalesReport.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}

final Provider<DashboardRepository> dashboardRepositoryProvider =
Provider<DashboardRepository>(
      (Ref ref) => DashboardRepository(ref.watch(apiServiceProvider)),
);