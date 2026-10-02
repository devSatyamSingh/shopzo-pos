import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopzo_pos/core/constants/navigator_key.dart';
import 'package:shopzo_pos/core/routes/route_name.dart';
import 'package:shopzo_pos/view/splash/spalsh_screen.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';

import '../../view/auth/login_screen.dart';
import '../../view/bottombar/bottombar_screen.dart';
import 'app_routes.dart';

/// Auth ke hisaab se router:
///  - Splash: animation ke baad session check, phir home ya login
///  - Logout ya session expire hote hi (kahin se bhi) apne aap login par
///  - Login ho gaya to login screen par wapas nahi aa sakte
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // Auth status badalte hi router ko redirect dobara chalane ko bolta hai.
  final ValueNotifier<int> authRefresh = ValueNotifier<int>(0);
  ref.listen<AuthStatus>(
    authViewModelProvider.select((AuthState s) => s.status),
        (AuthStatus? previous, AuthStatus next) => authRefresh.value++,
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: navigatorKey, // AppUtils ka message bubble isi se dikhta hai
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthStatus status = ref.read(authViewModelProvider).status;
      final String location = state.matchedLocation;
      final bool onSplash = location == AppRoutes.splash;
      final bool onLogin = location == AppRoutes.login;

      // Session check hone tak splash par hi raho.
      if (status == AuthStatus.unknown) return onSplash ? null : AppRoutes.splash;

      // Splash apni animation ke baad khud navigate karega.
      if (onSplash) return null;

      if (status == AuthStatus.unauthenticated) {
        return onLogin ? null : AppRoutes.login;
      }
      // authenticated
      return onLogin ? AppRoutes.home : null;
    },
    routes: <RouteBase>[
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) {
          return SplashScreen(
            onFinished: () async {
              await ref.read(authViewModelProvider.notifier).checkSession();
              if (!context.mounted) return;
              final bool loggedIn =
                  ref.read(authViewModelProvider).status == AuthStatus.authenticated;
              context.go(loggedIn ? AppRoutes.home : AppRoutes.login);
            },
          );
        },
      ),

      // ── Login ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _fadePage(state, const LoginScreen());
        },
      ),

      // ── Home ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _fadePage(state, const MainShellScreen());
        },
      ),
    ],
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