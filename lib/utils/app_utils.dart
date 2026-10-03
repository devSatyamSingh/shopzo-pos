import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/navigator_key.dart';
import '../core/errors/failure.dart';
import '../widget/app_colors.dart';

enum MessageType { success, error, warning, info }

class AppUtils {
  AppUtils._();

  static OverlayEntry? _entry;
  static String? _lastKey;
  static DateTime? _lastShownAt;

  static void hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static void showSuccess(
    String message, {
    String? title,
    int? statusCode,
    Duration? duration,
  }) {
    showMessage(
      message,
      type: MessageType.success,
      title: title,
      statusCode: statusCode,
      duration: duration,
    );
  }

  static void showError(
    String message, {
    String? title,
    int? statusCode,
    Duration? duration,
  }) {
    showMessage(
      message,
      type: MessageType.error,
      title: title,
      statusCode: statusCode,
      duration: duration,
    );
  }

  static void showWarning(
    String message, {
    String? title,
    int? statusCode,
    Duration? duration,
  }) {
    showMessage(
      message,
      type: MessageType.warning,
      title: title,
      statusCode: statusCode,
      duration: duration,
    );
  }

  static void showInfo(
    String message, {
    String? title,
    int? statusCode,
    Duration? duration,
  }) {
    showMessage(
      message,
      type: MessageType.info,
      title: title,
      statusCode: statusCode,
      duration: duration,
    );
  }

  static void showFailure(Failure failure, {String? title}) {
    final bool soft =
        failure.type == FailureType.noInternet ||
        failure.type == FailureType.timeout;
    showMessage(
      failure.message,
      type: soft ? MessageType.warning : MessageType.error,
      title: title ?? _titleFor(failure.type),
      statusCode: failure.statusCode,
    );
  }

  static void showResult<T>(
    ApiResult<T> result, {
    bool showOnSuccess = true,
    String? successFallback,
  }) {
    if (result is ApiSuccess<T>) {
      if (!showOnSuccess) return;
      final String? msg = (result.message != null && result.message!.isNotEmpty)
          ? result.message
          : successFallback;
      if (msg != null && msg.isNotEmpty) {
        showSuccess(msg, statusCode: result.statusCode);
      }
    } else if (result is ApiFailure<T>) {
      showFailure(result.failure);
    }
  }

  static void showMessage(
    String message, {
    MessageType type = MessageType.info,
    String? title,
    int? statusCode,
    Duration? duration,
  }) {
    final String text = message.trim();
    if (text.isEmpty) return;

    final String key = '${type.name}|$statusCode|$text';
    final DateTime now = DateTime.now();
    if (_entry != null &&
        _lastKey == key &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastKey = key;
    _lastShownAt = now;

    void insert() {
      final OverlayState? overlay = navigatorKey.currentState?.overlay;
      if (overlay == null) {
        debugPrint('[AppUtils] Overlay not ready, message: $text');
        return;
      }
      _removeNow();

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (BuildContext context) => _MessageBubble(
          type: type,
          title: title,
          message: text,
          statusCode: statusCode,
          duration: duration ?? AppConstants.messageDuration,
          onDismissed: () => _remove(entry),
        ),
      );
      _entry = entry;
      overlay.insert(entry);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => insert());
    } else {
      insert();
    }
  }

  static void dismissMessage() => _removeNow();

  static void _removeNow() {
    final OverlayEntry? e = _entry;
    if (e != null) _remove(e);
  }

  static void _remove(OverlayEntry entry) {
    if (identical(_entry, entry)) _entry = null;
    if (!entry.mounted) return;
    entry.remove();
    entry.dispose();
  }

  static String _titleFor(FailureType type) {
    switch (type) {
      case FailureType.noInternet:
        return 'No connection';
      case FailureType.timeout:
        return 'Request timed out';
      case FailureType.unauthorized:
        return 'Unauthorized';
      case FailureType.forbidden:
        return 'Access denied';
      case FailureType.notFound:
        return 'Not found';
      case FailureType.badRequest:
      case FailureType.validation:
        return 'Invalid request';
      case FailureType.conflict:
        return 'Conflict';
      case FailureType.tooManyRequests:
        return 'Too many requests';
      case FailureType.server:
        return 'Server error';
      case FailureType.parsing:
        return 'Unexpected response';
      case FailureType.cancelled:
      case FailureType.unknown:
        return 'Something went wrong';
    }
  }
}

class _BubbleStyle {
  const _BubbleStyle({
    required this.color,
    required this.soft,
    required this.icon,
    required this.title,
  });

  final Color color;
  final Color soft;
  final IconData icon;
  final String title;
}

_BubbleStyle _styleOf(MessageType type, bool isDark) {
  switch (type) {
    case MessageType.success:
      return _BubbleStyle(
        color: isDark ? AppColors.mint : AppColors.mintDark,
        soft: isDark ? AppColors.mint.withAlpha(36) : AppColors.mintSoft,
        icon: Icons.check_rounded,
        title: 'Success',
      );
    case MessageType.error:
      return _BubbleStyle(
        color: AppColors.coral,
        soft: isDark ? AppColors.coral.withAlpha(36) : AppColors.coralSoft,
        icon: Icons.close_rounded,
        title: 'Error',
      );
    case MessageType.warning:
      return _BubbleStyle(
        color: AppColors.amber,
        soft: isDark ? AppColors.amber.withAlpha(36) : AppColors.amberSoft,
        icon: Icons.priority_high_rounded,
        title: 'Warning',
      );
    case MessageType.info:
      return _BubbleStyle(
        color: isDark ? AppColors.sky : AppColors.primary,
        soft: isDark ? AppColors.sky.withAlpha(36) : AppColors.primarySoft,
        icon: Icons.info_outline_rounded,
        title: 'Info',
      );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.type,
    required this.title,
    required this.message,
    required this.statusCode,
    required this.duration,
    required this.onDismissed,
  });

  final MessageType type;
  final String? title;
  final String message;
  final int? statusCode;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _progress;
  late final AnimationController _shake;

  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _iconPop;

  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _progress = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) _dismiss();
      });
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 490),
    );

    _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _enter,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _iconPop = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    );

    if (widget.type == MessageType.error) {
      HapticFeedback.mediumImpact();
    } else if (widget.type == MessageType.success) {
      HapticFeedback.lightImpact();
    }

    _start();
  }

  Future<void> _start() async {
    await _enter.forward();
    if (!mounted || _dismissing) return;
    if (widget.type == MessageType.error) _shake.forward();
    _progress.forward();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _progress.stop();
    if (!mounted) return;
    await _enter.reverse();
    widget.onDismissed();
  }

  void _pause() {
    if (!_dismissing) _progress.stop();
  }

  void _resume() {
    if (!_dismissing && _enter.isCompleted) _progress.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _progress.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final _BubbleStyle style = _styleOf(widget.type, palette.isDark);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String title = widget.title ?? style.title;

    final Widget card = Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withAlpha(64)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.color.withAlpha(46),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ScaleTransition(
                    scale: _iconPop,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.soft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(style.icon, color: style.color, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall,
                              ),
                            ),
                            if (widget.statusCode != null) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: style.color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.statusCode}',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: style.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkResponse(
                    onTap: _dismiss,
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Countdown bar
            SizedBox(
              height: 3,
              width: double.infinity,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ColoredBox(color: style.color.withAlpha(30)),
                  ),
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (BuildContext context, Widget? child) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 1 - _progress.value,
                          child: ColoredBox(
                            color: style.color,
                            child: const SizedBox(height: 3),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // Tablet par bubble phail na jaye.
              constraints: const BoxConstraints(maxWidth: 520),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (BuildContext context, Widget? child) {
                        final double t = _shake.value;
                        final double dx =
                            math.sin(t * math.pi * 6) * (1 - t) * 8;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: Material(
                        type: MaterialType.transparency,
                        child: Semantics(
                          liveRegion: true,
                          container: true,
                          label: '$title. ${widget.message}',
                          child: Listener(
                            onPointerDown: (_) => _pause(),
                            onPointerUp: (_) => _resume(),
                            onPointerCancel: (_) => _resume(),
                            child: Dismissible(
                              key: ObjectKey(this),
                              direction: DismissDirection.up,
                              onDismissed: (_) {
                                _dismissing = true;
                                widget.onDismissed();
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _dismiss,
                                child: card,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
