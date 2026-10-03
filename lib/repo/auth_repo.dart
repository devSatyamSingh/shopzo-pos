import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/auth_model.dart';
import '../model/user_model.dart';
import '../service/storage_service.dart';

class AuthRepo {
  const AuthRepo(this._api, this._storage);

  final ApiService _api;
  final StorageService _storage;

  Future<ApiResult<UserModel>> login({
    required String phone,
    required String password,
  }) async {
    final ApiResult<LoginResponseModel> result = await _api
        .post<LoginResponseModel>(
          ApiUrls.login,
          body: <String, dynamic>{'phone': phone, 'password': password},
          requiresAuth: false,
          parser: (dynamic data) => LoginResponseModel.fromJson(
            Map<String, dynamic>.from(data as Map),
          ),
        );

    if (result is ApiSuccess<LoginResponseModel>) {
      final LoginResponseModel login = result.data;
      try {
        await _storage.saveSession(
          accessToken: login.accessToken,
          refreshToken: login.refreshToken,
          userJson: login.user.toJsonString(),
        );
      } catch (e, stack) {
        debugPrint('AuthRepo: session save failed: $e\n$stack');
        return const ApiFailure<UserModel>(
          Failure(
            message:
                'Could not save your session on this device. Please try again.',
          ),
        );
      }
      return ApiSuccess<UserModel>(
        data: login.user,
        message: result.message,
        statusCode: result.statusCode,
      );
    }

    return ApiFailure<UserModel>(
      (result as ApiFailure<LoginResponseModel>).failure,
    );
  }

  Future<void> logout() async {
    try {
      final String? refreshToken = await _storage.getRefreshToken();
      await _api
          .post<dynamic>(
            ApiUrls.logout,
            body: refreshToken == null
                ? null
                : <String, dynamic>{'refreshToken': refreshToken},
            parser: (dynamic data) => data,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('AuthRepo: logout API ignored: $e');
    }
    await _storage.clearSession();
  }
}

final Provider<AuthRepo> authRepoProvider = Provider<AuthRepo>(
  (Ref ref) => AuthRepo(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);
