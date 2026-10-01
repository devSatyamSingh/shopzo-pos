import 'package:flutter/material.dart';

/// Root navigator key.
///
/// Isse bina BuildContext ke bhi overlay (message bubble), dialog ya navigation
/// kar sakte hain, jaise API layer ya viewmodel se.
///
/// Setup:
///   MaterialApp(navigatorKey: navigatorKey, ...)
///   ya go_router: GoRouter(navigatorKey: navigatorKey, ...)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);