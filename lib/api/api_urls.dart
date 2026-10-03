
class ApiUrls {
  ApiUrls._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://madhu.fctesting.shop/api/v1',
  );

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // ── POS: customers ───────────────────────────────────────────────────────
  static const String searchCustomer = '/pos/customers/search';
  static const String quickCreateCustomer = '/pos/customers/quick-create';

  // ── POS: products & orders ───────────────────────────────────────────────
  static const String posProducts = '/products/pos/search';
  static const String createPosOrder = '/orders/pos';
  static const String posOrderHistory = '/orders/pos/history';
  static String orderReceipt(String orderId) => '/orders/$orderId/receipt';

  // ── POS: held orders ─────────────────────────────────────────────────────
  static const String holdOrder = '/pos/held-orders';
  static const String heldOrders = '/pos/held-orders';
  static String heldOrderById(String id) => '/pos/held-orders/$id';
  static String resumeHeldOrder(String id) => '/pos/held-orders/$id/resume';
  static String cancelHeldOrder(String id) => '/pos/held-orders/$id';

  // ── POS: shifts ──────────────────────────────────────────────────────────
  static const String openShift = '/pos/shifts/open';
  static const String activeShift = '/pos/shifts/active';
  static const String listShifts = '/pos/shifts';
  static String closeShift(String id) => '/pos/shifts/$id/close';

  // ── Reports ──────────────────────────────────────────────────────────────
  static const String dailySalesReport = '/pos/reports/sales/daily';
  static const String allPermissions = '/permissions';
  static String permissionsByRole(String role) => '/permissions/role/$role';
  static const String assignPermission = '/permissions/assign';
  static const String revokePermission = '/permissions/revoke';
}