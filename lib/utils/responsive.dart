import 'package:flutter/widgets.dart';

/// Mobile / tablet breakpoints.
/// `shortestSide` use kiya hai, taaki phone landscape mein tablet na ban jaye.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;

  /// Form / card jaisi cheezon ki max width tablet pe.
  static const double formMaxWidth = 520;
  static const double contentMaxWidth = 1100;
}

extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);

  bool get isTablet => screen.shortestSide >= Breakpoints.tablet;
  bool get isMobile => !isTablet;
  bool get isLandscape => screen.width > screen.height;

  /// Mobile aur tablet ke liye alag value.
  /// `context.responsive(mobile: 16.0, tablet: 24.0)`
  T responsive<T>({required T mobile, T? tablet}) =>
      isTablet ? (tablet ?? mobile) : mobile;
}

/// Content ko tablet pe beech mein rakhta hai aur max width limit karta hai.
/// Login form, settings, dialogs sab isi mein wrap karna.
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