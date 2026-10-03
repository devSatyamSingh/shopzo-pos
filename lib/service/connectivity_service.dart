import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_urls.dart';

enum NetworkStatus { online, offline }

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

  Future<NetworkStatus> checkNow() async {
    await _evaluate();
    return _current;
  }

  Future<bool> hasInternet() async {
    if (!await _hasInterface()) return false;
    return _reachable();
  }

  Future<void> _evaluate({bool fromPoll = false}) {
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

  Future<bool> _hasInterface() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((ConnectivityResult r) => r != ConnectivityResult.none);
  }

  Future<bool> _reachable() async {
    final List<bool> results = await Future.wait<bool>(<Future<bool>>[
      _probe(_serverUri.host, _serverUri.port),
      _probe('1.1.1.1', 443),
    ]);
    return results.any((bool ok) => ok);
  }

  Future<bool> _probe(String host, int port) async {
    try {
      final Socket socket = await Socket.connect(
        host,
        port,
        timeout: _probeTimeout,
      );
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
    final StreamSubscription<NetworkStatus> sub = service.onStatusChange.listen(
      (NetworkStatus s) => state = s,
    );
    ref.onDispose(sub.cancel);
    return service.current;
  }
}

final NotifierProvider<NetworkStatusNotifier, NetworkStatus>
networkStatusProvider = NotifierProvider<NetworkStatusNotifier, NetworkStatus>(
  NetworkStatusNotifier.new,
);

final Provider<bool> isOnlineProvider = Provider<bool>(
  (Ref ref) => ref.watch(networkStatusProvider) == NetworkStatus.online,
);
