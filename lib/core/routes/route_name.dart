/// Saare route paths ek jagah. Kabhi '/login' jaisa string seedha mat likho,
/// hamesha `AppRoutes.login` use karo, taaki typo na ho.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';

// Aage ke example (path parameter wala):
// static const String product = '/product/:id';
// static String productPath(String id) => '/product/$id';
}