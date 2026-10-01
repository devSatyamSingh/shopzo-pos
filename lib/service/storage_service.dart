import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/storage_keys.dart';

/// Tokens secure storage mein jate hain (Keystore / Keychain).
/// Har API call pe disk read na ho isliye memory cache bhi hai.
class StorageService {
  StorageService({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  String? _accessCache;
  String? _refreshCache;
  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    return _loading ??= () async {
      _accessCache = await _secure.read(key: StorageKeys.accessToken);
      _refreshCache = await _secure.read(key: StorageKeys.refreshToken);
    }();
  }

  // ── Tokens ───────────────────────────────────────────────────────────────

  Future<String?> getAccessToken() async {
    await _ensureLoaded();
    return _accessCache;
  }

  Future<String?> getRefreshToken() async {
    await _ensureLoaded();
    return _refreshCache;
  }

  Future<bool> hasSession() async {
    final String? token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _ensureLoaded();
    _accessCache = accessToken;
    await _secure.write(key: StorageKeys.accessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshCache = refreshToken;
      await _secure.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
  }

  Future<void> clearTokens() async {
    await _ensureLoaded();
    _accessCache = null;
    _refreshCache = null;
    await _secure.delete(key: StorageKeys.accessToken);
    await _secure.delete(key: StorageKeys.refreshToken);
  }

  // ── Generic key-value ────────────────────────────────────────────────────

  Future<void> write(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<String?> read(String key) => _secure.read(key: key);

  Future<void> delete(String key) => _secure.delete(key: key);

  /// Logout pe sab kuch saaf.
  Future<void> clearAll() async {
    _accessCache = null;
    _refreshCache = null;
    _loading = Future<void>.value();
    await _secure.deleteAll();
  }
}

final Provider<StorageService> storageServiceProvider =
Provider<StorageService>((Ref ref) => StorageService());