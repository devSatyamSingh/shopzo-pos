import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_urls.dart';

enum NetworkStatus { online, offline }

/// Internet ka asli status batata hai.
///
/// Sirf connectivity_plus kaafi nahi hai: Wi-Fi connected ho par internet na ho
/// to wo "connected" hi bolta hai. Isliye interface check ke baad hum socket
/// se server (aur backup mein 1.1.1.1) tak actually pahunch ke dekhte hain.
///
/// - Network change event pe turant check
/// - Har 8 sec mein background check (chupchap net jaye to bhi pata chale)
/// - Flicker se bachne ke liye poll mein 2 baar fail hone par hi "offline"
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity, Uri? serverUri})
      : _connectivity = connectivity ?? Connectivity(),
        _serverUri = serverUri ?? Uri.parse(ApiUrls.baseUrl);

  static const Duration _pollInterval = Duration(seconds: 8);
  static const Duration _probeTimeout = Duration(seconds: 3);
  static const int _failThreshold = 2;

  final Connectivity _connectivity;
  final Uri _serverUri;

  final StreamController<NetworkStatus> _controller =
  StreamController<NetworkStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollTimer;
  Future<void>? _inFlight;
  NetworkStatus _current = NetworkStatus.online; // optimistic start
  int _failures = 0;
  bool _started = false;

  NetworkStatus get current => _current;
  bool get isOnline => _current == NetworkStatus.online;

  /// Status badalne par event (sirf change pe).
  Stream<NetworkStatus> get onStatusChange => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      _evaluate();
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _evaluate(fromPoll: true);
    });
    await _evaluate();
  }

  /// Abhi fresh check karke status deta hai (Retry button / Pay Now se pehle).
  Future<NetworkStatus> checkNow() async {
    await _evaluate();
    return _current;
  }

  /// Sirf check karta hai, status event emit nahi karta.
  Future<bool> hasInternet() async {
    if (!await _hasInterface()) return false;
    return _reachable();
  }

  // ── Internals ────────────────────────────────────────────────────────────

  Future<void> _evaluate({bool fromPoll = false}) {
    // Ek time pe sirf ek check chalega.
    return _inFlight ??= _doEvaluate(fromPoll).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _doEvaluate(bool fromPoll) async {
    if (!await _hasInterface()) {
      _failures = _failThreshold;
      _set(NetworkStatus.offline);
      return;
    }

    if (await _reachable()) {
      _failures = 0;
      _set(NetworkStatus.online);
      return;
    }

    _failures++;
    if (!fromPoll || _failures >= _failThreshold) {
      _set(NetworkStatus.offline);
    }
  }

  /// Wi-Fi / mobile / ethernet / vpn me se koi connected hai?
  Future<bool> _hasInterface() async {
    final List<ConnectivityResult> results =
    await _connectivity.checkConnectivity();
    return results.any((ConnectivityResult r) => r != ConnectivityResult.none);
  }

  /// Hamare server ya 1.1.1.1 me se kisi tak pahunch gaye to internet hai.
  /// (Server down ho par internet ho to "online" hi maanenge, tab API ka
  /// error message user ko dikhega, "No internet" nahi.)
  Future<bool> _reachable() async {
    final List<bool> results = await Future.wait<bool>(<Future<bool>>[
      _probe(_serverUri.host, _serverUri.port),
      _probe('1.1.1.1', 443),
    ]);
    return results.any((bool ok) => ok);
  }

  Future<bool> _probe(String host, int port) async {
    try {
      final Socket socket =
      await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _set(NetworkStatus status) {
    if (_current == status) return;
    _current = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  void dispose() {
    _pollTimer?.cancel();
    _subscription?.cancel();
    _controller.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Riverpod providers
// ═══════════════════════════════════════════════════════════════════════════

final Provider<ConnectivityService> connectivityServiceProvider =
Provider<ConnectivityService>((Ref ref) {
  final ConnectivityService service = ConnectivityService();
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  @override
  NetworkStatus build() {
    final ConnectivityService service = ref.watch(connectivityServiceProvider);
    final StreamSubscription<NetworkStatus> sub =
    service.onStatusChange.listen((NetworkStatus s) => state = s);
    ref.onDispose(sub.cancel);
    return service.current;
  }
}

/// UI isse watch karta hai: `ref.watch(networkStatusProvider)`
final NotifierProvider<NetworkStatusNotifier, NetworkStatus>
networkStatusProvider =
NotifierProvider<NetworkStatusNotifier, NetworkStatus>(
  NetworkStatusNotifier.new,
);

/// Button disable karne ke liye: `onPressed: ref.watch(isOnlineProvider) ? _pay : null`
final Provider<bool> isOnlineProvider = Provider<bool>(
      (Ref ref) => ref.watch(networkStatusProvider) == NetworkStatus.online,
);