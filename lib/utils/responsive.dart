import 'package:flutter/widgets.dart';

/// Mobile / tablet breakpoints.
/// `shortestSide` use kiya hai, taaki phone landscape mein tablet na ban jaye.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;

  static const double formMaxWidth = 520;
  static const double contentMaxWidth = 1100;
}

extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);

  bool get isTablet => screen.shortestSide >= Breakpoints.tablet;
  bool get isMobile => !isTablet;
  bool get isLandscape => screen.width > screen.height;

  T responsive<T>({required T mobile, T? tablet}) =>
      isTablet ? (tablet ?? mobile) : mobile;
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.formMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}