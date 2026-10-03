import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/connectivity_service.dart';
import 'app_colors.dart';
import 'app_textstyle.dart';

class ConnectivityWrapper extends ConsumerStatefulWidget {
  const ConnectivityWrapper({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends ConsumerState<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  static const Duration _backOnlineDuration = Duration(milliseconds: 2500);

  late final AnimationController _pulse;
  Timer? _hideTimer;
  bool _showBackOnline = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (ref.read(networkStatusProvider) == NetworkStatus.offline) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onStatusChanged(NetworkStatus? previous, NetworkStatus next) {
    if (next == NetworkStatus.offline) {
      _hideTimer?.cancel();
      HapticFeedback.mediumImpact();
      _pulse.repeat(reverse: true);
      setState(() => _showBackOnline = false);
    } else if (previous == NetworkStatus.offline) {
      _pulse.stop();
      HapticFeedback.lightImpact();
      setState(() => _showBackOnline = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(_backOnlineDuration, () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await Future.wait<void>(<Future<void>>[
      ref.read(connectivityServiceProvider).checkNow(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkStatus>(networkStatusProvider, _onStatusChanged);
    final bool offline =
        ref.watch(networkStatusProvider) == NetworkStatus.offline;
    final bool showBanner = offline || _showBackOnline;
    final double topInset = MediaQuery.of(context).padding.top;

    return Column(
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showBanner
              ? _StatusBanner(
                  offline: offline,
                  retrying: _retrying,
                  onRetry: _retry,
                  pulse: _pulse,
                  topInset: topInset,
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: showBanner,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.offline,
    required this.retrying,
    required this.onRetry,
    required this.pulse,
    required this.topInset,
  });

  final bool offline;
  final bool retrying;
  final VoidCallback onRetry;
  final Animation<double> pulse;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: offline ? 'No internet connection' : 'Back online',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        color: offline ? AppColors.coral : AppColors.mintDark,
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 12, 10),
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: offline
                ? _OfflineRow(
                    key: const ValueKey<String>('offline'),
                    pulse: pulse,
                    retrying: retrying,
                    onRetry: onRetry,
                  )
                : const _OnlineRow(key: ValueKey<String>('online')),
          ),
        ),
      ),
    );
  }
}

class _OfflineRow extends StatelessWidget {
  const _OfflineRow({
    super.key,
    required this.pulse,
    required this.retrying,
    required this.onRetry,
  });

  final Animation<double> pulse;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        FadeTransition(
          opacity: Tween<double>(begin: 0.4, end: 1).animate(pulse),
          child: const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'No internet connection',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Check Wi-Fi or mobile data. Billing needs internet.',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withAlpha(217),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _RetryButton(retrying: retrying, onTap: onRetry),
      ],
    );
  }
}

class _OnlineRow extends StatelessWidget {
  const _OnlineRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Back online',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.retrying, required this.onTap});

  final bool retrying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(46),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: retrying ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 68, minHeight: 34),
          child: Center(
            child: retrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      strokeCap: StrokeCap.round,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Retry',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
