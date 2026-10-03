import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }
}

class AppFullScreenLoader extends StatelessWidget {
  const AppFullScreenLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppLoader(size: 36, strokeWidth: 3.5),
          if (message != null) ...<Widget>[
            const SizedBox(height: 16),
            AppText.body(message!, secondary: true, align: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: !isLoading
                ? const SizedBox.shrink(key: ValueKey<String>('idle'))
                : SizedBox.expand(
              key: const ValueKey<String>('loading'),
              child: AbsorbPointer(
                child: ColoredBox(
                  color: AppColors.overlay,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: palette.shadow,
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const AppLoader(size: 34, strokeWidth: 3.5),
                          if (message != null) ...<Widget>[
                            const SizedBox(height: 16),
                            AppText.bodyBold(message!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 12,
  }) : isCircle = false;

  const AppSkeleton.circle({super.key, double size = 44})
      : width = size,
        height = size,
        radius = 0,
        isCircle = true;

  final double? width;
  final double height;
  final double radius;
  final bool isCircle;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.palette.isDark;
    final Color base = isDark ? AppColors.darkBorder : const Color(0xFFECEAF5);
    final Color highlight =
    isDark ? const Color(0xFF2F3256) : const Color(0xFFF8F7FD);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          // Highlight band left se right chalta hai.
          final double x = -2 + 4 * _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
              widget.isCircle ? null : BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: <Color>[base, highlight, base],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}