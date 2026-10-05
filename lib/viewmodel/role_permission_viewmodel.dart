import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../model/permission_model.dart';
import '../repo/permission_repo.dart';
import '../utils/app_utils.dart';
import 'access_viewmodel.dart';
import 'auth_viewmodel.dart';

enum BulkOp { grant, revoke }

String _busyTag(ManagedRole role, String key) => '${role.api}:$key';

@immutable
class RolePermissionsState {
  const RolePermissionsState({
    this.role = ManagedRole.admin,
    this.sections = const <PermissionSection>[],
    this.granted = const <ManagedRole, Set<String>>{},
    this.loadingRoles = const <ManagedRole>{},
    this.roleFailures = const <ManagedRole, Failure>{},
    this.busy = const <String>{},
    this.bulkOp,
    this.isLoading = true,
    this.failure,
  });

  final ManagedRole role;
  final List<PermissionSection> sections;

  /// Role -> granted keys (lazily load hota hai, tab switch par cache).
  final Map<ManagedRole, Set<String>> granted;
  final Set<ManagedRole> loadingRoles;
  final Map<ManagedRole, Failure> roleFailures;

  /// Toggle in-flight ("ROLE:key").
  final Set<String> busy;
  final BulkOp? bulkOp;

  /// Pehli load (catalog + selected role).
  final bool isLoading;
  final Failure? failure;

  Set<String> get current => granted[role] ?? const <String>{};
  bool get hasRole => granted.containsKey(role);
  bool get isRoleLoading => loadingRoles.contains(role);
  Failure? get roleFailure => roleFailures[role];
  bool get isBulkBusy => bulkOp != null;
  bool isBusy(String key) => busy.contains(_busyTag(role, key));

  List<String> get allKeys => <String>[
    for (final PermissionSection s in sections)
      for (final PermissionModel p in s.items) p.key,
  ];

  int get total => allKeys.length;
  int get grantedCount => allKeys.where(current.contains).length;
  bool get allGranted => total > 0 && grantedCount == total;
  bool get noneGranted => grantedCount == 0;

  RolePermissionsState copyWith({
    ManagedRole? role,
    List<PermissionSection>? sections,
    Map<ManagedRole, Set<String>>? granted,
    Set<ManagedRole>? loadingRoles,
    Map<ManagedRole, Failure>? roleFailures,
    Set<String>? busy,
    BulkOp? bulkOp,
    bool clearBulk = false,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RolePermissionsState(
      role: role ?? this.role,
      sections: sections ?? this.sections,
      granted: granted ?? this.granted,
      loadingRoles: loadingRoles ?? this.loadingRoles,
      roleFailures: roleFailures ?? this.roleFailures,
      busy: busy ?? this.busy,
      bulkOp: clearBulk ? null : (bulkOp ?? this.bulkOp),
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class RolePermissionsViewModel extends Notifier<RolePermissionsState> {
  CancelToken _cancel = CancelToken();

  PermissionRepo get _repo => ref.read(permissionRepoProvider);

  @override
  RolePermissionsState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    ref.onDispose(() => token.cancel('disposed'));
    Future<void>.microtask(() => init());
    return const RolePermissionsState();
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Catalog + selected role ek saath. `silent` = skeleton nahi (pull-to-refresh).
  Future<void> init({bool silent = false}) async {
    final CancelToken token = _cancel;
    final ManagedRole role = state.role;
    if (!silent) state = state.copyWith(isLoading: true, clearFailure: true);

    final List<ApiResult<List<PermissionModel>>> results =
    await Future.wait<ApiResult<List<PermissionModel>>>(
      <Future<ApiResult<List<PermissionModel>>>>[
        _repo.getAll(cancelToken: token),
        _repo.getByRole(role.api, cancelToken: token),
      ],
    );
    if (!ref.mounted || token.isCancelled) return;

    final List<PermissionModel>? catalog = results[0].dataOrNull;
    if (catalog == null) {
      if (silent && state.sections.isNotEmpty) {
        AppUtils.showFailure(results[0].failureOrNull!);
        return;
      }
      state = state.copyWith(isLoading: false, failure: results[0].failureOrNull);
      return;
    }

    final List<PermissionModel>? mine = results[1].dataOrNull;
    state = state.copyWith(
      isLoading: false,
      clearFailure: true,
      sections: PosPermissions.sectionsOf(catalog),
      // Baaki roles ka cache hata do (stale ho sakta hai).
      granted: mine == null
          ? const <ManagedRole, Set<String>>{}
          : <ManagedRole, Set<String>>{
        role: <String>{for (final PermissionModel p in mine) p.key},
      },
      roleFailures: mine == null
          ? <ManagedRole, Failure>{role: results[1].failureOrNull!}
          : const <ManagedRole, Failure>{},
    );

    // Load ke dauran user ne tab badla ho to us role ko bhi laao.
    final ManagedRole now = state.role;
    if (!state.granted.containsKey(now) &&
        !state.loadingRoles.contains(now) &&
        !state.roleFailures.containsKey(now)) {
      unawaited(_loadRole(now));
    }
  }

  Future<void> selectRole(ManagedRole role) async {
    if (role == state.role) return;
    state = state.copyWith(role: role);
    if (!state.granted.containsKey(role)) await _loadRole(role);
  }

  Future<void> reloadRole() => _loadRole(state.role);

  Future<void> _loadRole(ManagedRole role, {bool silent = false}) async {
    final CancelToken token = _cancel;
    if (!silent) {
      _setLoading(role, true);
      _setRoleFailure(role, null);
    }

    final ApiResult<List<PermissionModel>> result =
    await _repo.getByRole(role.api, cancelToken: token);
    if (!ref.mounted || token.isCancelled) return;

    final List<PermissionModel>? data = result.dataOrNull;
    if (data != null) {
      state = state.copyWith(
        granted: _granted(role, <String>{for (final PermissionModel p in data) p.key}),
      );
      _setRoleFailure(role, null);
    } else if (!silent) {
      _setRoleFailure(role, result.failureOrNull);
    }
    if (!silent) _setLoading(role, false);
  }

  // ── Toggle (optimistic + rollback) ───────────────────────────────────────

  Future<void> toggle(String key) async {
    final ManagedRole role = state.role;
    final Set<String>? current = state.granted[role];
    final String tag = _busyTag(role, key);
    if (current == null || state.isBulkBusy || state.busy.contains(tag)) return;

    final bool grant = !current.contains(key);
    _setBusy(tag, true);
    _applyLocal(role, key, grant);

    final ApiResult<bool> result = grant
        ? await _repo.assign(role: role.api, key: key)
        : await _repo.revoke(role: role.api, key: key);
    if (!ref.mounted) return;

    if (result.isFailure) {
      _applyLocal(role, key, !grant);
      final Failure f = result.failureOrNull!;
      AppUtils.showFailure(f);
      // Kisi aur ne bhi badla ho sakta hai: sach server se le lo.
      if (f.type == FailureType.conflict || f.type == FailureType.notFound) {
        unawaited(_loadRole(role, silent: true));
      }
    } else {
      _afterChange(role);
    }
    _setBusy(tag, false);
  }

  // ── Bulk ─────────────────────────────────────────────────────────────────

  Future<void> grantAll() => _bulk(BulkOp.grant);
  Future<void> revokeAll() => _bulk(BulkOp.revoke);

  Future<void> _bulk(BulkOp op) async {
    final ManagedRole role = state.role;
    final Set<String>? current = state.granted[role];
    if (current == null || state.isBulkBusy) return;

    final bool grant = op == BulkOp.grant;
    final List<String> targets = <String>[
      for (final String k in state.allKeys)
        if (current.contains(k) != grant) k,
    ];
    if (targets.isEmpty) return;

    state = state.copyWith(bulkOp: op);
    final BulkPermissionResult r = grant
        ? await _repo.assignMany(role: role.api, keys: targets)
        : await _repo.revokeMany(role: role.api, keys: targets);
    if (!ref.mounted) return;

    final Set<String> next = Set<String>.of(state.granted[role] ?? current);
    grant ? next.addAll(r.succeeded) : next.removeAll(r.succeeded);
    state = state.copyWith(clearBulk: true, granted: _granted(role, next));

    if (r.hasFailures) {
      AppUtils.showWarning(
        '${r.failed.length} of ${targets.length} permissions could not be updated. Please try again.',
      );
    } else {
      AppUtils.showSuccess(
        grant
            ? '${role.label}: full POS access granted'
            : '${role.label}: all POS access revoked',
      );
    }
    if (r.succeeded.isNotEmpty) _afterChange(role);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Admin apna hi role edit kare to apni access turant refresh ho.
  void _afterChange(ManagedRole role) {
    final String mine =
    (ref.read(currentUserProvider)?.roleName ?? '').trim().toUpperCase();
    if (mine == role.api) {
      unawaited(ref.read(accessViewModelProvider.notifier).refresh());
    }
  }

  Map<ManagedRole, Set<String>> _granted(ManagedRole role, Set<String> keys) =>
      Map<ManagedRole, Set<String>>.of(state.granted)..[role] = keys;

  void _applyLocal(ManagedRole role, String key, bool on) {
    final Set<String> next =
    Set<String>.of(state.granted[role] ?? const <String>{});
    on ? next.add(key) : next.remove(key);
    state = state.copyWith(granted: _granted(role, next));
  }

  void _setBusy(String tag, bool on) {
    if (!ref.mounted) return;
    final Set<String> next = Set<String>.of(state.busy);
    on ? next.add(tag) : next.remove(tag);
    state = state.copyWith(busy: next);
  }

  void _setLoading(ManagedRole role, bool on) {
    final Set<ManagedRole> next = Set<ManagedRole>.of(state.loadingRoles);
    on ? next.add(role) : next.remove(role);
    state = state.copyWith(loadingRoles: next);
  }

  void _setRoleFailure(ManagedRole role, Failure? f) {
    final Map<ManagedRole, Failure> next =
    Map<ManagedRole, Failure>.of(state.roleFailures);
    f == null ? next.remove(role) : next[role] = f;
    state = state.copyWith(roleFailures: next);
  }
}

/// autoDispose: screen band hote hi state saaf, dobara kholne par fresh data.
final rolePermissionsViewModelProvider = NotifierProvider.autoDispose<
    RolePermissionsViewModel, RolePermissionsState>(
  RolePermissionsViewModel.new,
);