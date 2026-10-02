import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/responsive.dart';
import '../../widget/app_colors.dart';
import '../../widget/app_dimens.dart';
import '../../widget/app_textstyle.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 3200),
  });

  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _bloom;
  late final Animation<double> _title;
  late final Animation<double> _tagline;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    Animation<double> interval(double begin, double end,
        [Curve curve = Curves.easeOut]) {
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );
    }

    _logoFade = interval(0.0, 0.25);
    _bloom = interval(0.15, 0.85, Curves.easeInOut);
    _title = interval(0.18, 0.45);
    _tagline = interval(0.28, 0.55);
    _progress = interval(0.10, 0.95, Curves.easeInOut);

    _logoScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1.12), weight: 20),
    ]).animate(_controller);

    _controller.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tablet = context.isTablet;
    final double logoSize = tablet ? 120 : 84;
    final double titleSize = tablet ? 42 : 30;
    final double taglineSize = tablet ? 15 : 13;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _Background(bloom: _bloom.value),
                SafeArea(
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: _BrandBlock(
                                logoSize: logoSize,
                                titleSize: titleSize,
                                taglineSize: taglineSize,
                                logoFade: _logoFade.value,
                                logoScale: _logoScale.value,
                                titleOpacity: _title.value,
                                taglineOpacity: _tagline.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _LoadingFooter(
                        progress: _progress.value,
                        maxWidth: tablet ? 440 : 320,
                      ),
                      SizedBox(height: tablet ? 56 : 40),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Background (gradient + bloom + dot grid) ───────────────────────────────

class _Background extends StatelessWidget {
  const _Background({required this.bloom});

  final double bloom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.lerp(const Color(0xFF1C1650), const Color(0xFF2A1F6B), bloom)!,
                AppColors.ink,
                AppColors.ink,
              ],
              stops: const <double>[0, 0.6, 1],
            ),
          ),
        ),
        const CustomPaint(painter: _DotGridPainter()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.1, 0.15),
              radius: 0.35 + 0.8 * bloom,
              colors: <Color>[
                AppColors.primary.withValues(alpha: 0.55 * bloom),
                AppColors.primary.withValues(alpha: 0.18 * bloom),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.5, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -0.15),
              radius: 0.2 + 0.7 * bloom,
              colors: <Color>[
                AppColors.mint.withValues(alpha: 0.30 * bloom),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double gap = 24;
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final List<Offset> points = <Offset>[];
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Logo + name + tagline ──────────────────────────────────────────────────

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({
    required this.logoSize,
    required this.titleSize,
    required this.taglineSize,
    required this.logoFade,
    required this.logoScale,
    required this.titleOpacity,
    required this.taglineOpacity,
  });

  final double logoSize;
  final double titleSize;
  final double taglineSize;
  final double logoFade;
  final double logoScale;
  final double titleOpacity;
  final double taglineOpacity;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = AppTextStyles.hero.copyWith(
      fontSize: titleSize,
      letterSpacing: -1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: logoFade,
          child: Transform.scale(
            scale: logoScale,
            child: _Logo(size: logoSize),
          ),
        ),
        SizedBox(height: logoSize * 0.3),
        Opacity(
          opacity: titleOpacity,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - titleOpacity)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Shopzo ', style: titleStyle.copyWith(color: Colors.white)),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: <Color>[AppColors.primaryLight, AppColors.mint],
                  ).createShader(bounds),
                  child: Text('POS', style: titleStyle.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: taglineSize * 0.6),
        Opacity(
          opacity: taglineOpacity,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - taglineOpacity)),
            child: Text(
              'Bill faster. Grow smarter.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: taglineSize,
                color: AppColors.darkTextSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2B2C4A), Color(0xFF12142A)],
        ),
        border: Border.all(color: AppColors.primary, width: 1.6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: size * 0.5,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.mint.withValues(alpha: 0.18),
            blurRadius: size * 0.7,
            offset: Offset(size * 0.15, size * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28 - 1.6),
        child: Image.asset(
          'assets/icons/shopzolo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// ── Bottom progress ────────────────────────────────────────────────────────

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter({required this.progress, required this.maxWidth});

  final double progress;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool almostDone = progress >= 0.6;
    final String status =
    almostDone ? 'Ready in a moment…' : 'Setting up your store';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 4,
                width: double.infinity,
                child: Stack(
                  children: <Widget>[
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.10),
                      child: const SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[AppColors.primary, AppColors.mint],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Row(
                key: ValueKey<String>(status),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.darkTextSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}