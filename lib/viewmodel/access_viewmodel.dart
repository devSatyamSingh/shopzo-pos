import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../model/permission_model.dart';
import '../repo/permission_repo.dart';
import 'auth_viewmodel.dart';

enum AccessStatus { loading, ready, error }

@immutable
class AccessState {
  const AccessState({
    this.status = AccessStatus.loading,
    this.keys = const <String>{},
    this.items = const <PermissionModel>[],
    this.failure,
  });

  final AccessStatus status;
  final Set<String> keys;
  final List<PermissionModel> items;
  final Failure? failure;

  bool get isReady => status == AccessStatus.ready;
  bool has(String key) => keys.contains(key);
  bool hasAny(Iterable<String> list) => list.any(keys.contains);

  List<PermissionModel> get posItems => PosPermissions.orderedPos(items);

  AccessState copyWith({
    AccessStatus? status,
    Set<String>? keys,
    List<PermissionModel>? items,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AccessState(
      status: status ?? this.status,
      keys: keys ?? this.keys,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}


class AccessViewModel extends Notifier<AccessState> {
  static const Duration _minGap = Duration(seconds: 20);

  CancelToken _cancel = CancelToken();
  int _requestId = 0;
  DateTime? _lastLoadedAt;

  PermissionRepo get _repo => ref.read(permissionRepoProvider);

  @override
  AccessState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    ref.onDispose(() => token.cancel('disposed'));

    final _ResumeObserver observer = _ResumeObserver(_onResume);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

    final String? userId = ref.watch(
      authViewModelProvider.select((AuthState s) => s.user?.id),
    );
    final String role = ref.watch(
      authViewModelProvider.select(
            (AuthState s) => (s.user?.roleName ?? '').trim().toUpperCase(),
      ),
    );
    if (userId == null || role.isEmpty) {
      return const AccessState(status: AccessStatus.ready);
    }

    Future<void>.microtask(() => load());
    return const AccessState();
  }

  void _onResume() {
    if (!ref.mounted || state.status == AccessStatus.loading) return;
    final DateTime? last = _lastLoadedAt;
    if (last != null && DateTime.now().difference(last) < _minGap) return;
    unawaited(load(silent: state.isReady));
  }

  Future<void> refresh() => load(silent: true);

  Future<void> load({bool silent = false}) async {
    final AuthState auth = ref.read(authViewModelProvider);
    if (!auth.isAuthenticated || auth.isLoading) return;

    final String role =
    (ref.read(currentUserProvider)?.roleName ?? '').trim().toUpperCase();
    if (role.isEmpty) return;

    final int id = ++_requestId;
    final CancelToken token = _cancel;
    if (!silent) {
      state = state.copyWith(status: AccessStatus.loading, clearFailure: true);
    }

    final ApiResult<List<PermissionModel>> result =
    await _repo.getMine(cancelToken: token);
    if (!ref.mounted || token.isCancelled || id != _requestId) return;
    _lastLoadedAt = DateTime.now();

    final List<PermissionModel>? data = result.dataOrNull;
    if (data != null) {
      state = AccessState(
        status: AccessStatus.ready,
        keys: <String>{for (final PermissionModel p in data) p.key},
        items: data,
      );
      return;
    }

    if (silent && state.isReady) return;
    state = AccessState(
      status: AccessStatus.error,
      failure: result.failureOrNull,
    );
  }}

final NotifierProvider<AccessViewModel, AccessState> accessViewModelProvider =
NotifierProvider<AccessViewModel, AccessState>(AccessViewModel.new);

final canProvider = Provider.family<bool, String>(
      (Ref ref, String key) => ref.watch(
    accessViewModelProvider.select((AccessState s) => s.has(key)),
  ),
);

extension PermissionRef on WidgetRef {
  bool can(String key) => watch(canProvider(key));
  bool canNow(String key) => read(accessViewModelProvider).has(key);
}