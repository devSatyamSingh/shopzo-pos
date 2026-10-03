
class Receipt {
  const Receipt({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.email,
    required this.orderId,
    required this.orderNumber,
    required this.channel,
    required this.createdAt,
    required this.cashierName,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.payments,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final String businessName;
  final String address;
  final String phone;
  final String email;
  final String orderId;
  final String orderNumber;
  final String channel;
  final DateTime? createdAt;
  final String cashierName;
  final String? customerName;
  final String? customerPhone;
  final List<ReceiptItem> items;
  final List<ReceiptPayment> payments;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  int get totalQty => items.fold<int>(0, (int s, ReceiptItem i) => s + i.quantity);
  bool get hasCustomer => (customerName ?? '').isNotEmpty || (customerPhone ?? '').isNotEmpty;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final Map<String, dynamic> store = map(json['store']);
    final Map<String, dynamic> order = map(json['order']);
    final Map<String, dynamic> customer = map(json['customer']);
    final dynamic rawItems = json['items'];
    final dynamic rawPayments = json['payments'];

    return Receipt(
      businessName: _s(store['businessName']) ?? 'Store',
      address: _s(store['address']) ?? '',
      phone: _s(store['phone']) ?? '',
      email: _s(store['email']) ?? '',
      orderId: _s(order['id']) ?? '',
      orderNumber: _s(order['orderNumber']) ?? '',
      channel: _s(order['channel']) ?? '',
      createdAt: DateTime.tryParse(_s(order['createdAt']) ?? ''),
      cashierName: _s(order['cashierName']) ?? '',
      customerName: _s(customer['name']),
      customerPhone: _s(customer['phone']),
      items: <ReceiptItem>[
        if (rawItems is List)
          for (final dynamic i in rawItems)
            if (i is Map) ReceiptItem.fromJson(Map<String, dynamic>.from(i)),
      ],
      payments: <ReceiptPayment>[
        if (rawPayments is List)
          for (final dynamic p in rawPayments)
            if (p is Map) ReceiptPayment.fromJson(Map<String, dynamic>.from(p)),
      ],
      subtotal: _d(json['subtotal']),
      discount: _d(json['discount']),
      tax: _d(json['tax']),
      total: _d(json['total']),
    );
  }
}

class ReceiptItem {
  const ReceiptItem({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.price,
    required this.taxAmount,
    required this.subtotal,
    required this.lineTotal,
  });

  final String productName;
  final String sku;
  final int quantity;
  final double price;
  final double taxAmount;
  final double subtotal;
  final double lineTotal;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      productName: _s(json['productName']) ?? 'Item',
      sku: _s(json['sku']) ?? '',
      quantity: _d(json['quantity']).toInt(),
      price: _d(json['price']),
      taxAmount: _d(json['taxAmount']),
      subtotal: _d(json['subtotal']),
      lineTotal: _d(json['lineTotal']),
    );
  }
}

class ReceiptPayment {
  const ReceiptPayment({required this.method, required this.amount});

  final String method;
  final double amount;

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      method: _s(json['method']) ?? '',
      amount: _d(json['amount']),
    );
  }
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String? _s(dynamic v) {
  if (v == null) return null;
  final String t = v.toString();
  return t.isEmpty ? null : t;
}