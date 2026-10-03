class AppConstants {
  AppConstants._();

  static const String appName = 'Shopzo POS';
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int pageSize = 20;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  static const Duration messageDuration = Duration(seconds: 3);
}