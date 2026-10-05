import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'app_colors.dart';

/// Skeleton ke liye shimmer wrapper (dashboard jaisa hi look).
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF262A4A) : const Color(0xFFE7E5F1),
      highlightColor: dark ? const Color(0xFF353A63) : const Color(0xFFF7F6FC),
      child: child,
    );
  }
}

/// Skeleton ka ek block. Hamesha AppShimmer ke andar use karo.
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}