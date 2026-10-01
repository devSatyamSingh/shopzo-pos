import 'package:flutter/foundation.dart';

/// Error ka type. UI isse decide karta hai ki kya dikhana hai
/// (jaise noInternet pe retry button, unauthorized pe login screen).
enum FailureType {
  noInternet,
  timeout,
  badRequest, // 400
  validation, // 422
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  conflict, // 409
  tooManyRequests, // 429
  server, // 5xx
  cancelled,
  parsing, // response aaya lekin model mein convert nahi hua
  unknown,
}

/// API ya app ka error. [message] wahi hai jo server ne bheja (agar bheja ho),
/// isliye UI mein seedha dikha sakte ho.
@immutable
class Failure {
  const Failure({
    required this.message,
    this.type = FailureType.unknown,
    this.statusCode,
    this.fieldErrors = const <String, String>{},
    this.raw,
  });

  /// Server ka message (ya friendly fallback).
  final String message;
  final FailureType type;

  /// HTTP status code (401, 404, 500...). Network error mein null.
  final int? statusCode;

  /// Field-wise errors, jaise {'phone': 'Phone already exists'}.
  /// Form ke TextField ke neeche dikhane ke liye.
  final Map<String, String> fieldErrors;

  /// Server ki original body (debugging ke liye).
  final dynamic raw;

  bool get isNoInternet => type == FailureType.noInternet;
  bool get isTimeout => type == FailureType.timeout;
  bool get isUnauthorized => type == FailureType.unauthorized;
  bool get isServerError => type == FailureType.server;

  String? fieldError(String field) => fieldErrors[field];

  @override
  String toString() => 'Failure(status: $statusCode, type: $type, message: $message)';
}

/// API call ka result: ya to success ya failure. Exception UI tak nahi aata.
///
/// ```dart
/// final result = await api.post<User>(...);
/// result.when(
///   success: (s) => print(s.data),
///   failure: (f) => AppUtils.showFailure(f.failure),
/// );
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull {
    final self = this;
    return self is ApiSuccess<T> ? self.data : null;
  }

  Failure? get failureOrNull {
    final self = this;
    return self is ApiFailure<T> ? self.failure : null;
  }

  R when<R>({
    required R Function(ApiSuccess<T> success) success,
    required R Function(ApiFailure<T> failure) failure,
  }) {
    final self = this;
    if (self is ApiSuccess<T>) return success(self);
    return failure(self as ApiFailure<T>);
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess({required this.data, this.message, this.statusCode});

  final T data;

  /// Server ka success message, jaise "Login successful".
  final String? message;
  final int? statusCode;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.failure);

  final Failure failure;
}