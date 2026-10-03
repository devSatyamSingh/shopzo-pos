import 'customer_model.dart';

class HeldItem {
  const HeldItem({
    required this.productId,
    this.variantId,
    required this.quantity,
  });

  final String productId;
  final String? variantId;
  final int quantity;

  factory HeldItem.fromJson(Map<String, dynamic> json) {
    return HeldItem(
      productId: _s(json['productId']) ?? '',
      variantId: _s(json['variantId']),
      quantity: _i(json['quantity']),
    );
  }
}

class HeldOrder {
  const HeldOrder({
    required this.id,
    required this.customerId,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.cashierName,
    required this.customer,
    required this.items,
  });

  final String id;
  final String? customerId;
  final String note;
  final String status;
  final DateTime? createdAt;
  final String cashierName;

  final CustomerModel? customer;
  final List<HeldItem> items;

  bool get isHeld => status.toUpperCase() == 'HELD';
  int get itemCount => items.length;
  int get totalQty => items.fold<int>(0, (int s, HeldItem i) => s + i.quantity);

  factory HeldOrder.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final dynamic rawItems = json['items'];
    final Map<String, dynamic> cust = map(json['customer']);

    return HeldOrder(
      id: _s(json['id']) ?? '',
      customerId: _s(json['customerId']),
      note: _s(json['note']) ?? '',
      status: _s(json['status']) ?? 'HELD',
      createdAt: DateTime.tryParse(_s(json['createdAt']) ?? ''),
      cashierName: _s(map(json['cashier'])['name']) ?? '',
      customer: cust['id'] != null ? CustomerModel.fromJson(cust) : null,
      items: <HeldItem>[
        if (rawItems is List)
          for (final dynamic i in rawItems)
            if (i is Map) HeldItem.fromJson(Map<String, dynamic>.from(i)),
      ],
    );
  }
}

String? _s(dynamic v) {
  if (v == null) return null;
  final String t = v.toString();
  return t.isEmpty ? null : t;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}