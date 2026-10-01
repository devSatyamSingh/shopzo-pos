import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopzo_pos/core/routes/route_name.dart';
import 'package:shopzo_pos/service/storage_service.dart';
import 'package:shopzo_pos/view/splash/spalsh_screen.dart';
import 'app_routes.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true, // console mein route changes dikhte hain
    routes: <RouteBase>[
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) {
          return SplashScreen(
            onFinished: () async {
              final bool loggedIn =
              await ref.read(storageServiceProvider).hasSession();
              if (!context.mounted) return;
              context.go(loggedIn ? AppRoutes.home : AppRoutes.login);
            },
          );
        },
      ),

      // ── Login ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (BuildContext context, GoRouterState state) {
          // TODO: LoginScreen aane par yahan laga dena.
          return _fadePage(state, const _ComingSoon(title: 'Login'));
        },
      ),

      // ── Home ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (BuildContext context, GoRouterState state) {
          // TODO: Dashboard / Home screen yahan.
          return _fadePage(state, const _ComingSoon(title: 'Home'));
        },
      ),
    ],

    // Galat / unknown route pe ye dikhega.
    errorBuilder: (BuildContext context, GoRouterState state) {
      return _ComingSoon(title: 'Page not found: ${state.uri}');
    },
  );
});

/// Fade transition, splash se login jaate waqt smooth lage.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondary, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Temporary placeholder. Real screens ban jaayein to hata dena.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(title)));
  }
}