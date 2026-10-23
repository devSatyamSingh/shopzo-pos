import 'package:flutter/foundation.dart';
import 'package:shopzo_pos/model/billing_model.dart';

/// priceDiff > 0  -> customer se paisa lena hai (naya item mehenga)
/// priceDiff < 0  -> customer ko wapas dena hai (naya item sasta)
/// priceDiff == 0 -> kuch nahi
enum ExchangeAction { collect, refund, even }

ExchangeAction exchangeActionOf(double diff) {
  if (diff > 0.005) return ExchangeAction.collect;
  if (diff < -0.005) return ExchangeAction.refund;
  return ExchangeAction.even;
}

/// POST /orders/pos/exchange/preview ka response (data).
@immutable
class ExchangePreview {
  const ExchangePreview({
    required this.originalValue,
    required this.newItemName,
    required this.newItemTotal,
    required this.priceDiff,
    required this.inStock,
  });

  /// Return hone wale item ki asli value (coupon discount ke baad ki).
  final double originalValue;
  final String newItemName;
  final double newItemTotal;
  final double priceDiff;
  final bool inStock;

  ExchangeAction get action => exchangeActionOf(priceDiff);

  /// Hamesha positive amount (collect ya refund).
  double get amount => _round2(priceDiff.abs());

  factory ExchangePreview.fromJson(Map<String, dynamic> json) {
    final dynamic rawItem = json['newItem'];
    final Map<String, dynamic> item = rawItem is Map
        ? Map<String, dynamic>.from(rawItem)
        : <String, dynamic>{};

    return ExchangePreview(
      originalValue: _d(json['originalValue']),
      newItemName: _s(item['productName']) ?? 'New item',
      newItemTotal: _d(item['total']),
      priceDiff: _d(json['priceDiff']),
      inStock: json['inStock'] is bool ? json['inStock'] as bool : true,
    );
  }
}

/// Collect case me customer se liya gaya ek payment.
@immutable
class ExchangePayment {
  const ExchangePayment(this.method, this.amount, {this.transactionRef});

  final PaymentMethod method;
  final double amount;
  final String? transactionRef;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'method': method.api,
    'amount': _amountJson(amount),
    if (transactionRef != null && transactionRef!.trim().isNotEmpty)
      'transactionRef': transactionRef!.trim(),
  };
}

@immutable
class ExchangeRequest {
  const ExchangeRequest({
    required this.orderItemId,
    required this.quantity,
    required this.newProductId,
    this.newVariantId,
    this.payments = const <ExchangePayment>[],
    this.refundMethod,
    this.reason,
  });

  final String orderItemId;
  final int quantity;
  final String newProductId;
  final String? newVariantId;

  /// Sirf tab bhejo jab naya item mehenga ho (sum == priceDiff).
  final List<ExchangePayment> payments;

  /// Sirf tab bhejo jab naya item sasta ho. Nahi diya to server CASH maanta hai.
  final PaymentMethod? refundMethod;
  final String? reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'orderItemId': orderItemId,
    'quantity': quantity,
    'newProductId': newProductId,
    if (newVariantId != null) 'newVariantId': newVariantId,
    if (payments.isNotEmpty)
      'payments': <Map<String, dynamic>>[
        for (final ExchangePayment p in payments) p.toJson(),
      ],
    if (refundMethod != null) 'refundMethod': refundMethod!.api,
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

/// POST /orders/pos/exchange ka response (data).
@immutable
class ExchangeResult {
  const ExchangeResult({
    required this.orderId,
    required this.orderNumber,
    required this.total,
    required this.priceDiff,
    this.refundAmount,
    this.refundMethod,
  });

  /// Naya (exchange) order. Receipt isi id se aati hai.
  final String orderId;
  final String orderNumber;
  final double total;
  final double priceDiff;
  final double? refundAmount;
  final String? refundMethod;

  ExchangeAction get action => exchangeActionOf(priceDiff);

  factory ExchangeResult.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;

    final Map<String, dynamic> order =
        map(json['exchangeOrder']) ?? <String, dynamic>{};
    final Map<String, dynamic>? refund = map(json['refund']);

    return ExchangeResult(
      orderId: _s(order['id']) ?? '',
      orderNumber: _s(order['orderNumber']) ?? '',
      total: _d(order['total']),
      priceDiff: _d(json['priceDiff']),
      refundAmount: refund == null ? null : _d(refund['amount']),
      refundMethod: refund == null ? null : _s(refund['method']),
    );
  }
}

double _round2(double v) => double.parse(v.toStringAsFixed(2));

Object _amountJson(double a) => a % 1 == 0 ? a.toInt() : _round2(a);

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