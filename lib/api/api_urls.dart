/// Saare API endpoints ek jagah.
///
/// Base URL flavor ke hisaab se badalta hai, code mein hardcode mat karo:
///   flutter run --dart-define=BASE_URL=https://client1.yourplatform.com/api/v1
///
/// ⚠️ IMPORTANT: Sirf `login` Postman screenshot se confirm hai.
/// Baaki sab paths mera andaza hain. Postman ke har request ka URL dekh kar
/// yahan match karo. Sirf is file mein badalna hai, baaki code same rahega.
class ApiUrls {
  ApiUrls._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://madhu.fctesting.shop/api/v1',
  );

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '/auth/login'; // ✅ confirmed
  static const String refreshToken = '/auth/refresh-token'; // ⚠️ verify
  static const String logout = '/auth/logout'; // ⚠️ verify

  // ── POS: customers ───────────────────────────────────────────────────────
  static const String searchCustomer = '/pos/customers/search'; // ⚠️ verify
  static const String quickCreateCustomer = '/pos/customers/quick'; // ⚠️ verify

  // ── POS: products & orders ───────────────────────────────────────────────
  static const String posProducts = '/products/pos/search'; // ⚠️ verify
  static const String createPosOrder = '/pos/orders'; // ⚠️ verify
  static const String posOrderHistory = '/orders/pos/history'; // ⚠️ verify
  static String orderReceipt(String orderId) => '/pos/orders/$orderId/receipt'; // ⚠️ verify

  // ── POS: held orders ─────────────────────────────────────────────────────
  static const String holdOrder = '/pos/orders/hold';
  static const String heldOrders = '/pos/orders/held';
  static String heldOrderById(String id) => '/pos/orders/held/$id'; // ⚠️ verify
  static String resumeHeldOrder(String id) => '/pos/orders/held/$id/resume'; // ⚠️ verify
  static String cancelHeldOrder(String id) => '/pos/orders/held/$id'; // ⚠️ verify (DELETE)

  // ── POS: shifts ──────────────────────────────────────────────────────────
  static const String openShift = '/pos/shifts/open'; // ⚠️ verify
  static const String activeShift = '/pos/shifts/active'; // ⚠️ verify
  static const String listShifts = '/pos/shifts'; // ⚠️ verify
  static String closeShift(String id) => '/pos/shifts/$id/close'; // ⚠️ verify (PATCH)

  // ── Reports ──────────────────────────────────────────────────────────────
  static const String dailySalesReport = '/pos/reports/sales/daily';
  static const String allPermissions = '/permissions'; // ⚠️ verify
  static String permissionsByRole(String role) => '/permissions/role/$role'; // ⚠️ verify
  static const String assignPermission = '/permissions/assign'; // ⚠️ verify
  static const String revokePermission = '/permissions/revoke'; // ⚠️ verify
}