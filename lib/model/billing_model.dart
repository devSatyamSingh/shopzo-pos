
enum PaymentMethod {
  cash('CASH', 'Cash'),
  upi('UPI', 'UPI'),
  card('CARD', 'Card');

  const PaymentMethod(this.api, this.label);
  final String api;
  final String label;
}

class PaymentLine {
  const PaymentLine(this.method, this.amount);

  final PaymentMethod method;
  final double amount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'method': method.api,
    'amount': amount % 1 == 0
        ? amount.toInt()
        : double.parse(amount.toStringAsFixed(2)),
  };
}

class CartItem {
  const CartItem({
    required this.productId,
    this.variantId,
    required this.name,
    required this.sku,
    required this.price,
    required this.maxStock,
    required this.qty,
    this.image,
  });

  final String productId;
  final String? variantId;
  final String name;
  final String sku;
  final double price;
  final int maxStock;
  final int qty;
  final String? image;
  String get key => '$productId:${variantId ?? ''}';
  double get lineTotal => price * qty;

  CartItem withQty(int q) => CartItem(
    productId: productId,
    variantId: variantId,
    name: name,
    sku: sku,
    price: price,
    maxStock: maxStock,
    qty: q,
    image: image,
  );

  Map<String, dynamic> toOrderJson() => <String, dynamic>{
    'productId': productId,
    if (variantId != null) 'variantId': variantId,
    'quantity': qty,
  };
}

class CreatedOrder {
  const CreatedOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final DateTime? createdAt;

  factory CreatedOrder.fromJson(Map<String, dynamic> json) {
    double num0(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return CreatedOrder(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      total: num0(json['total']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}