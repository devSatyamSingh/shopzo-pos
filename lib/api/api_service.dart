import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../core/network/api_exceptions.dart';
import 'api_client.dart';

/// Repository layer isi ko use karti hai.
///
/// Exception kabhi bahar nahi aata. Hamesha [ApiResult] milta hai:
///  - [ApiSuccess]: data + server ka message + status code
///  - [ApiFailure]: [Failure] (server ka message + status code + field errors)
///
/// Do tarah ke parser:
///  - `parser`: sirf `data` key ka hissa milta hai (login, single object)
///  - `bodyParser`: POORI body milti hai, jab `data` ke bahar bhi kuch chahiye
///    (jaise list ke saath `pagination`). `bodyParser` ho to wahi chalta hai.
///
/// Example:
/// ```dart
/// _api.get<PosOrderPage>(
///   ApiUrls.posOrderHistory,
///   queryParameters: {'page': 1, 'limit': 20},
///   bodyParser: (body) => PosOrderPage.fromJson(body as Map<String, dynamic>),
/// );
/// ```
class ApiService {
  const ApiService(this._client);

  final ApiClient _client;

  /// Session expire (refresh fail) hone par event.
  Stream<void> get onSessionExpired => _client.onSessionExpired;

  Future<ApiResult<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
        T Function(dynamic body)? bodyParser,
      }) {
    return _run<T>(
          () => _client.get(
        path,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
      bodyParser,
    );
  }

  Future<ApiResult<T>> post<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
        T Function(dynamic body)? bodyParser,
      }) {
    return _run<T>(
          () => _client.post(
        path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
      bodyParser,
    );
  }

  Future<ApiResult<T>> put<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
        T Function(dynamic body)? bodyParser,
      }) {
    return _run<T>(
          () => _client.put(
        path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
      bodyParser,
    );
  }

  Future<ApiResult<T>> patch<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
        T Function(dynamic body)? bodyParser,
      }) {
    return _run<T>(
          () => _client.patch(
        path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
      bodyParser,
    );
  }

  Future<ApiResult<T>> delete<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
        T Function(dynamic body)? bodyParser,
      }) {
    return _run<T>(
          () => _client.delete(
        path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
      bodyParser,
    );
  }

  Future<ApiResult<T>> _run<T>(
      Future<ApiResponse> Function() call,
      T Function(dynamic data)? parser,
      T Function(dynamic body)? bodyParser,
      ) async {
    try {
      final ApiResponse res = await call();
      final T data = bodyParser != null
          ? bodyParser(res.body)
          : parser != null
          ? parser(res.data)
          : res.data as T;
      return ApiSuccess<T>(
        data: data,
        message: res.message,
        statusCode: res.statusCode,
      );
    } on ApiException catch (e) {
      return ApiFailure<T>(e.toFailure());
    } catch (e, stack) {
      // Response aaya lekin model.fromJson fail hua (key missing / type mismatch).
      debugPrint('ApiService parsing error: $e\n$stack');
      return ApiFailure<T>(
        Failure(
          message: 'Unable to read the server response. Please try again.',
          type: FailureType.parsing,
          raw: e,
        ),
      );
    }
  }
}

final Provider<ApiService> apiServiceProvider = Provider<ApiService>(
      (Ref ref) => ApiService(ref.watch(apiClientProvider)),
);