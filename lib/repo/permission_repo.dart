import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/permission_model.dart';

class PermissionRepo {
  const PermissionRepo(this._api);

  final ApiService _api;

  static const int _chunk = 4;


  List<PermissionModel> _parseMine(dynamic data) {
    if (data is! List) return const <PermissionModel>[];
    return <PermissionModel>[
      for (final dynamic e in data)
        if (e is String)
          PermissionModel(id: e, key: e.trim(), description: '')
        else if (e is Map)
          PermissionModel.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Saari POS permissions (extra permissions yahin filter ho jaati hain).
  List<PermissionModel> _parsePermissions(dynamic data) {
    if (data is! List) return const <PermissionModel>[];
    return <PermissionModel>[
      for (final dynamic e in data)
        if (e is Map) PermissionModel.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<ApiResult<List<PermissionModel>>> getAll({CancelToken? cancelToken}) {
    return _api.get<List<PermissionModel>>(
      ApiUrls.allPermissions,
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
  }

  Future<ApiResult<List<PermissionModel>>> getByRole(
      String role, {
        CancelToken? cancelToken,
      }) {
    return _api.get<List<PermissionModel>>(
      ApiUrls.permissionsByRole(role.trim().toUpperCase()),
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
  }

  Future<ApiResult<bool>> assign({required String role, required String key}) {
    return _api.post<bool>(
      ApiUrls.assignPermission,
      body: <String, dynamic>{'role': role, 'permissionKey': key},
      parser: (dynamic _) => true,
    );
  }

  Future<ApiResult<bool>> revoke({required String role, required String key}) {
    return _api.post<bool>(
      ApiUrls.revokePermission,
      body: <String, dynamic>{'role': role, 'permissionKey': key},
      parser: (dynamic _) => true,
    );
  }

  Future<ApiResult<List<PermissionModel>>> getMine({CancelToken? cancelToken}) {
    return _api.get<List<PermissionModel>>(
      ApiUrls.myPermissions,
      cancelToken: cancelToken,
      parser: _parseMine,
    );
  }

  Future<BulkPermissionResult> assignMany({
    required String role,
    required Iterable<String> keys,
  }) => _bulk(role, keys.toList(), grant: true);

  Future<BulkPermissionResult> revokeMany({
    required String role,
    required Iterable<String> keys,
  }) => _bulk(role, keys.toList(), grant: false);

  Future<BulkPermissionResult> _bulk(
      String role,
      List<String> keys, {
        required bool grant,
      }) async {
    final List<String> done = <String>[];
    final List<String> failed = <String>[];
    Failure? firstFailure;

    for (int i = 0; i < keys.length; i += _chunk) {
      final List<String> slice =
      keys.sublist(i, math.min(i + _chunk, keys.length));
      final List<ApiResult<bool>> results =
      await Future.wait<ApiResult<bool>>(<Future<ApiResult<bool>>>[
        for (final String k in slice)
          grant ? assign(role: role, key: k) : revoke(role: role, key: k),
      ]);
      for (int j = 0; j < slice.length; j++) {
        if (results[j].isSuccess) {
          done.add(slice[j]);
        } else {
          failed.add(slice[j]);
          firstFailure ??= results[j].failureOrNull;
        }
      }
    }
    return BulkPermissionResult(
      succeeded: done,
      failed: failed,
      firstFailure: firstFailure,
    );
  }
}

final Provider<PermissionRepo> permissionRepoProvider =
Provider<PermissionRepo>(
      (Ref ref) => PermissionRepo(ref.watch(apiServiceProvider)),
);