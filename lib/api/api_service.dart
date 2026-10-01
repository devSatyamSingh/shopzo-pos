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
/// Example (repo mein):
/// ```dart
/// Future<ApiResult<LoginResponse>> login(String phone, String password) {
///   return _api.post<LoginResponse>(
///     ApiUrls.login,
///     body: {'phone': phone, 'password': password},
///     requiresAuth: false,
///     parser: (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
///   );
/// }
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
      }) {
    return _run<T>(
          () => _client.get(
        path,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

  Future<ApiResult<T>> post<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
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
    );
  }

  Future<ApiResult<T>> put<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
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
    );
  }

  Future<ApiResult<T>> patch<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
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
    );
  }

  Future<ApiResult<T>> delete<T>(
      String path, {
        Object? body,
        Map<String, dynamic>? queryParameters,
        bool requiresAuth = true,
        CancelToken? cancelToken,
        T Function(dynamic data)? parser,
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
    );
  }

  Future<ApiResult<T>> _run<T>(
      Future<ApiResponse> Function() call,
      T Function(dynamic data)? parser,
      ) async {
    try {
      final ApiResponse res = await call();
      final T data = parser != null ? parser(res.data) : res.data as T;
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