import 'dart:io';
import 'package:dio/dio.dart';
import '../errors/failure.dart';

class ApiException implements Exception {
  const ApiException({
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


  factory ApiException.fromDioException(DioException e) {
    final Object? inner = e.error;
    if (inner is ApiException) return inner;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          message: 'The server is taking too long to respond. Please try again.',
          type: FailureType.timeout,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Request cancelled.',
          type: FailureType.cancelled,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'No internet connection. Please check your network and try again.',
          type: FailureType.noInternet,
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Secure connection failed. Please contact support.',
        );
      case DioExceptionType.badResponse:
        return ApiException.fromBody(
          e.response?.data,
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.unknown:
        if (inner is SocketException) {
          return const ApiException(
            message: 'No internet connection. Please check your network and try again.',
            type: FailureType.noInternet,
          );
        }
        return const ApiException(
          message: 'Something went wrong. Please try again.',
        );
    }
  }


  factory ApiException.fromBody(dynamic body, {int? statusCode}) {
    return ApiException(
      message: extractMessage(body) ?? _defaultMessage(statusCode),
      type: _typeFromStatus(statusCode),
      statusCode: statusCode,
      fieldErrors: extractFieldErrors(body),
      raw: body,
    );
  }

  factory ApiException.unknown(Object error) {
    return ApiException(
      message: 'Something went wrong. Please try again.',
      raw: error,
    );
  }

  Failure toFailure() {
    return Failure(
      message: message,
      type: type,
      statusCode: statusCode,
      fieldErrors: fieldErrors,
      raw: raw,
    );
  }

  static String? extractMessage(dynamic body) {
    if (body is String) {
      final String t = body.trim();
      if (t.isNotEmpty && t.length <= 200 && !t.contains('<')) return t;
      return null;
    }
    if (body is! Map) return null;
    for (final String key in const <String>[
      'message',
      'error',
      'msg',
      'detail',
      'error_description',
    ]) {
      final dynamic v = body[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is Map) {
        final dynamic nested = v['message'];
        if (nested is String && nested.trim().isNotEmpty) return nested.trim();
      }
    }

    final dynamic errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final dynamic first = errors.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is Map) {
        final dynamic m = first['message'] ?? first['msg'];
        if (m is String && m.trim().isNotEmpty) return m.trim();
      }
    }
    if (errors is Map && errors.isNotEmpty) {
      final dynamic first = errors.values.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is List && first.isNotEmpty && first.first is String) {
        return (first.first as String).trim();
      }
    }
    return null;
  }

  static Map<String, String> extractFieldErrors(dynamic body) {
    if (body is! Map) return const <String, String>{};
    final dynamic errors = body['errors'] ?? body['details'];
    final Map<String, String> result = <String, String>{};

    if (errors is Map) {
      errors.forEach((dynamic key, dynamic value) {
        String? msg;
        if (value is String) {
          msg = value;
        } else if (value is List && value.isNotEmpty && value.first is String) {
          msg = value.first as String;
        } else if (value is Map && value['message'] is String) {
          msg = value['message'] as String;
        }
        if (msg != null && msg.trim().isNotEmpty) {
          result[key.toString()] = msg.trim();
        }
      });
    } else if (errors is List) {
      for (final dynamic item in errors) {
        if (item is Map) {
          final dynamic field = item['field'] ?? item['path'] ?? item['param'];
          final dynamic msg = item['message'] ?? item['msg'];
          if (field is String && msg is String && msg.trim().isNotEmpty) {
            result[field] = msg.trim();
          }
        }
      }
    }
    return result;
  }

  static FailureType _typeFromStatus(int? status) {
    if (status == null) return FailureType.badRequest;
    if (status >= 500) return FailureType.server;
    switch (status) {
      case 400:
        return FailureType.badRequest;
      case 401:
        return FailureType.unauthorized;
      case 403:
        return FailureType.forbidden;
      case 404:
        return FailureType.notFound;
      case 409:
        return FailureType.conflict;
      case 422:
        return FailureType.validation;
      case 429:
        return FailureType.tooManyRequests;
      default:
        return FailureType.unknown;
    }
  }

  static String _defaultMessage(int? status) {
    if (status == null) return 'Request failed. Please try again.';
    if (status >= 500) return 'Server error. Please try again later.';
    switch (status) {
      case 400:
        return 'Invalid request. Please check and try again.';
      case 401:
        return 'Session expired. Please login again.';
      case 403:
        return "You don't have permission to do this.";
      case 404:
        return 'Requested data was not found.';
      case 409:
        return 'This record already exists or is in conflict.';
      case 422:
        return 'Please check the entered details.';
      case 429:
        return 'Too many requests. Please slow down.';
      default:
        return 'Something went wrong (code $status).';
    }
  }

  @override
  String toString() => 'ApiException(status: $statusCode, type: $type, message: $message)';
}