/// App-level constants. Colors / sizes yahan nahi, wo theme files mein hain.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pulse POS';

  // ── Network timeouts ─────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Pagination / search ──────────────────────────────────────────────────
  static const int pageSize = 20;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // ── UI ───────────────────────────────────────────────────────────────────
  /// Message bubble kitni der screen par rahega.
  static const Duration messageDuration = Duration(seconds: 4);
}