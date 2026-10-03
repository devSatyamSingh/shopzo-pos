import 'package:flutter/foundation.dart';

enum FailureType {
  noInternet,
  timeout,
  badRequest, // 400
  validation, // 422
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  conflict, // 409
  tooManyRequests,
  server,
  cancelled,
  parsing,
  unknown,
}

@immutable
class Failure {
  const Failure({
    required this.message,
    this.type = FailureType.unknown,
    this.statusCode,
    this.fieldErrors = const <String, String>{},
    this.raw,
  });
  final String message;
  final FailureType type;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final dynamic raw;

  bool get isNoInternet => type == FailureType.noInternet;
  bool get isTimeout => type == FailureType.timeout;
  bool get isUnauthorized => type == FailureType.unauthorized;
  bool get isServerError => type == FailureType.server;

  String? fieldError(String field) => fieldErrors[field];

  @override
  String toString() => 'Failure(status: $statusCode, type: $type, message: $message)';
}

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
  final String? message;
  final int? statusCode;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.failure);

  final Failure failure;
}