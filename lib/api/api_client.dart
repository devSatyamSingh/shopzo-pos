import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_exceptions.dart';
import '../service/storage_service.dart';
import 'api_urls.dart';

const String _kRequiresAuth = 'requiresAuth';
const String _kAuthRetried = 'authRetried';

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    this.message,
  });

  final int statusCode;
  final dynamic body;
  final String? message;

  dynamic get data {
    final dynamic b = body;
    if (b is Map && b.containsKey('data')) return b['data'];
    return b;
  }

  factory ApiResponse.fromResponse(Response<dynamic> response) {
    final dynamic body = response.data;
    String? message;
    if (body is Map && body['message'] is String) {
      final String m = (body['message'] as String).trim();
      if (m.isNotEmpty) message = m;
    }
    return ApiResponse(
      statusCode: response.statusCode ?? 200,
      body: body,
      message: message,
    );
  }
}


class ApiClient {
  ApiClient({required StorageService storage, String? baseUrl})
    : _storage = storage {
    final BaseOptions options = BaseOptions(
      baseUrl: baseUrl ?? ApiUrls.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      sendTimeout: AppConstants.sendTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: <String, dynamic>{'Accept': 'application/json'},
    );

    _dio = Dio(options);
    _plainDio = Dio(options.copyWith());
    _dio.interceptors.add(
      _AuthInterceptor(
        storage: _storage,
        plainDio: _plainDio,
        onSessionExpired: _emitSessionExpired,
      ),
    );
    if (kDebugMode) _dio.interceptors.add(_LogInterceptor());
  }

  final StorageService _storage;
  late final Dio _dio;
  late final Dio _plainDio;

  final StreamController<void> _sessionController =
      StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _sessionController.stream;

  void _emitSessionExpired() {
    if (!_sessionController.isClosed) _sessionController.add(null);
  }

  void dispose() {
    _sessionController.close();
    _dio.close();
    _plainDio.close();
  }


  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) {
    return _send(
      'GET',
      path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      headers: headers,
    );
  }

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      headers: headers,
    );
  }

  Future<ApiResponse> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) {
    return _send(
      'PUT',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      headers: headers,
    );
  }

  Future<ApiResponse> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) {
    return _send(
      'PATCH',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      headers: headers,
    );
  }

  Future<ApiResponse> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) {
    return _send(
      'DELETE',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      headers: headers,
    );
  }


  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required bool requiresAuth,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          extra: <String, dynamic>{_kRequiresAuth: requiresAuth},
        ),
      );

      final dynamic data = response.data;
      if (data is Map && data['success'] == false) {
        throw ApiException.fromBody(data, statusCode: response.statusCode);
      }
      return ApiResponse.fromResponse(response);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException.unknown(e);
    }
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final ApiClient client = ApiClient(
    storage: ref.watch(storageServiceProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});


enum _RefreshOutcome { success, rejected, failed }

class _Tokens {
  const _Tokens(this.access, this.refresh);
  final String access;
  final String? refresh;
}

/// QueuedInterceptor: errors ek ek karke process hote hain. Isliye 5 requests
/// ek saath 401 laayen to refresh sirf pehli ke liye hota hai, baaki naya token
/// dekh kar seedha retry ho jaati hain.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor({
    required this.storage,
    required this.plainDio,
    required this.onSessionExpired,
  });

  final StorageService storage;
  final Dio plainDio;
  final VoidCallback onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_kRequiresAuth] != false) {
      final String? token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final bool requiresAuth = options.extra[_kRequiresAuth] != false;
    final bool alreadyRetried = options.extra[_kAuthRetried] == true;

    if (err.response?.statusCode != 401 || !requiresAuth || alreadyRetried) {
      return handler.next(err);
    }

    final String? refreshToken = await storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expire();
      return handler.next(err);
    }

    // Kisi pehli queued request ne token already refresh kar diya ho to dobara mat karo.
    final String? sentHeader = options.headers['Authorization'] as String?;
    final String? currentToken = await storage.getAccessToken();
    final bool alreadyRefreshed =
        currentToken != null && sentHeader != 'Bearer $currentToken';

    if (!alreadyRefreshed) {
      final _RefreshOutcome outcome = await _refresh(refreshToken);
      if (outcome == _RefreshOutcome.rejected) {
        await _expire();
        return handler.next(err);
      }
      if (outcome == _RefreshOutcome.failed) {
        return handler.next(err);
      }
    }

    try {
      final String? newToken = await storage.getAccessToken();
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra[_kAuthRetried] = true;
      final Response<dynamic> retryResponse = await plainDio.fetch<dynamic>(
        options,
      );
      return handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<_RefreshOutcome> _refresh(String refreshToken) async {
    try {
      final Response<dynamic> res = await plainDio.post<dynamic>(
        ApiUrls.refreshToken,
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final _Tokens? tokens = _readTokens(res.data);
      if (tokens == null) return _RefreshOutcome.rejected;

      await storage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh ?? refreshToken,
      );
      return _RefreshOutcome.success;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return _RefreshOutcome.rejected;
      }
      return _RefreshOutcome.failed;
    } catch (_) {
      return _RefreshOutcome.failed;
    }
  }

  _Tokens? _readTokens(dynamic body) {
    dynamic data = body;
    if (body is Map && body['data'] is Map) data = body['data'];
    if (data is! Map) return null;

    final dynamic access = data['accessToken'] ?? data['access_token'];
    final dynamic refresh = data['refreshToken'] ?? data['refresh_token'];
    if (access is! String || access.isEmpty) return null;

    return _Tokens(
      access,
      refresh is String && refresh.isNotEmpty ? refresh : null,
    );
  }

  Future<void> _expire() async {
    await storage.clearTokens();
    onSessionExpired();
  }
}


class _LogInterceptor extends Interceptor {
  static const Set<String> _secretKeys = <String>{
    'password',
    'accesstoken',
    'refreshtoken',
    'token',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('➡️  ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('    body: ${_short(_redact(options.data))}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint('${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('    ${_short(_redact(response.data))}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '${err.response?.statusCode ?? err.type.name} ${err.requestOptions.uri}',
    );
    if (err.response?.data != null) {
      debugPrint('    ${_short(_redact(err.response?.data))}');
    }
    handler.next(err);
  }

  dynamic _redact(dynamic value) {
    if (value is Map) {
      return value.map<dynamic, dynamic>((dynamic k, dynamic v) {
        final bool secret = _secretKeys.contains(k.toString().toLowerCase());
        return MapEntry<dynamic, dynamic>(k, secret ? '***' : _redact(v));
      });
    }
    if (value is List) return value.map<dynamic>(_redact).toList();
    return value;
  }

  String _short(dynamic value) {
    final String s = value.toString();
    return s.length > 800 ? '${s.substring(0, 800)}…' : s;
  }
}
