import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/shift_model.dart';

class ShiftRepo {
  const ShiftRepo(this._api);
  final ApiService _api;

  Future<ApiResult<Shift?>> getActiveShift({CancelToken? cancelToken}) {
    return _api.get<Shift?>(
      ApiUrls.activeShift,
      cancelToken: cancelToken,
      parser: (dynamic data) =>
      data is Map ? Shift.fromJson(Map<String, dynamic>.from(data)) : null,
    );
  }

  Future<ApiResult<Shift>> openShift({
    required double openingCash,
    CancelToken? cancelToken,
  }) {
    return _api.post<Shift>(
      ApiUrls.openShift,
      body: <String, dynamic>{'openingCash': _amount(openingCash)},
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          Shift.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ApiResult<Shift>> closeShift({
    required String shiftId,
    required double closingCash,
    CancelToken? cancelToken,
  }) {
    return _api.patch<Shift>(
      ApiUrls.closeShift(shiftId),
      body: <String, dynamic>{'closingCash': _amount(closingCash)},
      cancelToken: cancelToken,
      parser: (dynamic data) =>
          Shift.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  /// 1000.0 -> 1000, 250.5 -> 250.5.
  Object _amount(double value) {
    if (value % 1 == 0) return value.toInt();
    return double.parse(value.toStringAsFixed(2));
  }
}

final Provider<ShiftRepo> shiftRepoProvider = Provider<ShiftRepo>(
      (Ref ref) => ShiftRepo(ref.watch(apiServiceProvider)),
);