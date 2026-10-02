import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../core/errors/failure.dart';
import '../model/user_model.dart';
import '../repo/auth_repo.dart';
import '../service/storage_service.dart';
import '../utils/app_utils.dart';

enum AuthStatus {
  /// Splash par session abhi check nahi hua.
  unknown,
  authenticated,
  unauthenticated,
}

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.failure,
  });

  final AuthStatus status;
  final UserModel? user;

  /// Login ya logout chal raha hai.
  final bool isLoading;

  /// Last login error (server ka exact message + status code + field errors).
  final Failure? failure;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Login, logout, session check aur session expiry yahin se.
///
/// UI mein:
///   final auth = ref.watch(authViewModelProvider);
///   ref.read(authViewModelProvider.notifier).login(...);
class AuthViewModel extends Notifier<AuthState> {
  bool _loggingOut = false;

  AuthRepo get _repo => ref.read(authRepoProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  AuthState build() {
    // Refresh token fail hone par ApiClient ye event bhejta hai.
    final StreamSubscription<void> sub = ref
        .read(apiServiceProvider)
        .onSessionExpired
        .listen((_) => _handleSessionExpired());
    ref.onDispose(sub.cancel);

    return const AuthState();
  }

  // ── Splash: session check ────────────────────────────────────────────────

  /// Device par token + user hai to seedha authenticated (net ki zarurat nahi).
  /// Token purana hua to pehli API call pe refresh ho jayega ya login pe bhej dega.
  Future<void> checkSession() async {
    try {
      final bool hasToken = await _storage.hasSession();
      final UserModel? user = UserModel.tryParse(await _storage.getUserJson());

      if (hasToken && user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
        return;
      }
      // Adhura session (sirf token ya sirf user) to saaf kar do.
      if (hasToken || user != null) await _storage.clearSession();
    } catch (e) {
      debugPrint('AuthViewModel.checkSession error: $e');
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Login ────────────────────────────────────────────────────────────────

  /// [rememberMe] true ho to sirf phone number yaad rahega (password kabhi nahi).
  /// Result wapas aata hai taaki UI server ka message / code bubble mein dikha sake.
  Future<ApiResult<UserModel>> login({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    if (state.isLoading) {
      return const ApiFailure<UserModel>(
        Failure(message: 'Login is already in progress.'),
      );
    }

    state = state.copyWith(isLoading: true, clearFailure: true);

    final String cleanPhone = phone.trim();
    final ApiResult<UserModel> result =
    await _repo.login(phone: cleanPhone, password: password);

    if (result is ApiSuccess<UserModel>) {
      await _saveRememberedPhone(rememberMe, cleanPhone);
      state = AuthState(status: AuthStatus.authenticated, user: result.data);
    } else if (result is ApiFailure<UserModel>) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    }
    return result;
  }

  /// User dobara type kare to purana error hata do.
  void clearError() {
    if (state.failure != null) state = state.copyWith(clearFailure: true);
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    state = state.copyWith(isLoading: true);
    try {
      await _repo.logout();
    } finally {
      _loggingOut = false;
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Session expiry (refresh token fail) ──────────────────────────────────

  Future<void> _handleSessionExpired() async {
    if (_loggingOut || state.status != AuthStatus.authenticated) return;
    try {
      await _storage.clearSession();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
    AppUtils.showWarning(
      'Your session has expired. Please login again.',
      title: 'Session expired',
    );
  }

  // ── Remember me ──────────────────────────────────────────────────────────

  Future<String?> rememberedPhone() async {
    try {
      return await _storage.getRememberedPhone();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRememberedPhone(bool remember, String phone) async {
    try {
      if (remember) {
        await _storage.saveRememberedPhone(phone);
      } else {
        await _storage.clearRememberedPhone();
      }
    } catch (_) {}
  }
}

final NotifierProvider<AuthViewModel, AuthState> authViewModelProvider =
NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);

/// Sirf logged-in user chahiye to (role ke hisaab se UI):
///   final user = ref.watch(currentUserProvider);
final Provider<UserModel?> currentUserProvider = Provider<UserModel?>(
      (Ref ref) => ref.watch(authViewModelProvider.select((AuthState s) => s.user)),
);