/// Order ka status. Naya status aaye to `unknown` banega aur original string
/// [PosOrder.statusName] mein rahegi (app crash nahi hogi).
enum OrderStatus {
  completed,
  pending,
  refunded,
  cancelled,
  unknown;

  static OrderStatus parse(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
        return OrderStatus.completed;
      case 'PENDING':
        return OrderStatus.pending;
      case 'REFUNDED':
      case 'PARTIALLY_REFUNDED':
      case 'RETURNED':
        return OrderStatus.refunded;
      case 'CANCELLED':
      case 'CANCELED':
      case 'VOID':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.unknown:
        return 'Unknown';
    }
  }
}

enum PayMethod {
  cash,
  upi,
  card,
  cod,
  other;

  static PayMethod parse(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v == 'CASH') return PayMethod.cash;
    if (v == 'UPI') return PayMethod.upi;
    if (v == 'COD') return PayMethod.cod;
    if (v.contains('CARD')) return PayMethod.card;
    return PayMethod.other;
  }

  String get label {
    switch (this) {
      case PayMethod.cash:
        return 'Cash';
      case PayMethod.upi:
        return 'UPI';
      case PayMethod.card:
        return 'Card';
      case PayMethod.cod:
        return 'COD';
      case PayMethod.other:
        return 'Other';
    }
  }
}

class OrderPayment {
  const OrderPayment({
    required this.method,
    required this.methodName,
    required this.amount,
  });

  final PayMethod method;

  /// Server se aayi original string, jaise "CASH".
  final String methodName;
  final double amount;

  /// Known method ka label, warna server wali string title-case mein.
  String get label =>
      method == PayMethod.other ? _titleCase(methodName) : method.label;

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    final String name = _str(json['method']) ?? '';
    return OrderPayment(
      method: PayMethod.parse(name),
      methodName: name,
      amount: _double(json['amount']),
    );
  }
}

/// History list ka ek order.
class PosOrder {
  const PosOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusName,
    required this.customerName,
    required this.cashierName,
    required this.itemCount,
    required this.payments,
    required this.total,
    this.createdAt,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String statusName;
  final String customerName;
  final String cashierName;
  final int itemCount;
  final List<OrderPayment> payments;
  final double total;
  final DateTime? createdAt;

  /// Ek order mein 2+ payment modes (jaise Cash + UPI).
  bool get isSplit => payments.length > 1;

  PayMethod? get primaryMethod =>
      payments.isEmpty ? null : payments.first.method;

  /// "UPI" ya split ho to "Cash + UPI".
  String get paymentLabel {
    if (payments.isEmpty) return '—';
    final List<String> labels = <String>[];
    for (final OrderPayment p in payments) {
      if (!labels.contains(p.label)) labels.add(p.label);
    }
    return labels.join(' + ');
  }

  /// Unknown status ho to server wali string dikhao.
  String get statusLabel =>
      status == OrderStatus.unknown && statusName.isNotEmpty
          ? _titleCase(statusName)
          : status.label;

  factory PosOrder.fromJson(Map<String, dynamic> json) {
    final dynamic rawPayments = json['payments'];
    final List<OrderPayment> payments = rawPayments is List
        ? rawPayments
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> m) =>
        OrderPayment.fromJson(Map<String, dynamic>.from(m)))
        .toList()
        : const <OrderPayment>[];

    final String statusName = _str(json['status']) ?? '';

    return PosOrder(
      id: _str(json['id']) ?? '',
      orderNumber: _str(json['orderNumber']) ?? '—',
      status: OrderStatus.parse(statusName),
      statusName: statusName,
      customerName: _str(json['customerName']) ?? 'Walk-in',
      cashierName: _str(json['cashierName']) ?? '—',
      itemCount: _double(json['itemCount']).toInt(),
      payments: payments,
      total: _double(json['total']),
      createdAt: DateTime.tryParse(_str(json['createdAt']) ?? ''),
    );
  }
}

class PageInfo {
  const PageInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory PageInfo.fromJson(Map<String, dynamic> json) {
    return PageInfo(
      page: _double(json['page']).toInt(),
      limit: _double(json['limit']).toInt(),
      total: _double(json['total']).toInt(),
      totalPages: _double(json['totalPages']).toInt(),
    );
  }
}

/// Poori response body: `{ "data": [...], "pagination": {...} }`
class PosOrderPage {
  const PosOrderPage({required this.items, required this.pageInfo});

  final List<PosOrder> items;
  final PageInfo pageInfo;

  factory PosOrderPage.fromJson(Map<String, dynamic> body) {
    final dynamic data = body['data'];
    if (data is! List) {
      throw const FormatException('Order history: "data" list missing');
    }

    final List<PosOrder> items = data
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> m) =>
        PosOrder.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final dynamic rawPagination = body['pagination'];
    final PageInfo info = rawPagination is Map
        ? PageInfo.fromJson(Map<String, dynamic>.from(rawPagination))
        : PageInfo(
      page: 1,
      limit: items.length,
      total: items.length,
      totalPages: 1,
    );

    return PosOrderPage(items: items, pageInfo: info);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

String? _str(dynamic value) {
  if (value == null) return null;
  final String s = value.toString();
  return s.isEmpty ? null : s;
}

/// int, double ya "599.00" string, sab chalta hai.
double _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _titleCase(String raw) {
  final String cleaned = raw.trim().replaceAll('_', ' ').toLowerCase();
  if (cleaned.isEmpty) return '—';
  return cleaned
      .split(' ')
      .where((String w) => w.isNotEmpty)
      .map((String w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}