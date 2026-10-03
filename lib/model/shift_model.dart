import 'package:shopzo_pos/model/pos_history_model.dart';

enum ShiftStatus {
  open,
  closed,
  unknown;

  static ShiftStatus parse(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'OPEN':
        return ShiftStatus.open;
      case 'CLOSED':
        return ShiftStatus.closed;
      default:
        return ShiftStatus.unknown;
    }
  }
}

class Shift {
  const Shift({
    required this.id,
    required this.cashierId,
    required this.status,
    required this.openingCash,
    this.openedAt,
    this.closingCash,
    this.expectedCash,
    this.discrepancy,
    this.closedAt,
  });

  final String id;
  final String cashierId;
  final ShiftStatus status;
  final double openingCash;
  final DateTime? openedAt;
  final double? closingCash;
  final double? expectedCash;

  /// closingCash - expectedCash. Positive = extra cash, negative = kam (shortfall).
  final double? discrepancy;
  final DateTime? closedAt;

  bool get isOpen => status == ShiftStatus.open;

  Duration get duration {
    final DateTime? start = openedAt;
    if (start == null) return Duration.zero;
    final DateTime end = closedAt ?? DateTime.now().toUtc();
    final Duration d = end.difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  double? get difference {
    if (discrepancy != null) return discrepancy;
    final double? c = closingCash;
    final double? e = expectedCash;
    if (c != null && e != null) return c - e;
    return null;
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: _str(json['id']) ?? '',
      cashierId: _str(json['cashierId']) ?? '',
      status: ShiftStatus.parse(_str(json['status'])),
      openingCash: _num(json['openingCash']) ?? 0,
      openedAt: DateTime.tryParse(_str(json['openedAt']) ?? ''),
      closingCash: _num(json['closingCash']),
      expectedCash: _num(json['expectedCash']),
      discrepancy: _num(json['discrepancy']),
      closedAt: DateTime.tryParse(_str(json['closedAt']) ?? ''),
    );
  }
}

class ShiftSummary {
  const ShiftSummary({
    this.orderCount = 0,
    this.totalSales = 0,
    this.cashSales = 0,
    this.upiSales = 0,
    this.cardSales = 0,
    this.codSales = 0,
    this.otherSales = 0,
    this.refundCount = 0,
    this.refundTotal = 0,
  });

  final int orderCount;
  final double totalSales;
  final double cashSales;
  final double upiSales;
  final double cardSales;
  final double codSales;
  final double otherSales;
  final int refundCount;
  final double refundTotal;

  double get avgOrderValue => orderCount == 0 ? 0 : totalSales / orderCount;
  double estimatedCash(Shift shift) => shift.openingCash + cashSales;
  factory ShiftSummary.fromOrders(Iterable<PosOrder> orders) {
    int count = 0;
    double total = 0;
    double cash = 0;
    double upi = 0;
    double card = 0;
    double cod = 0;
    double other = 0;
    int refunds = 0;
    double refundTotal = 0;

    for (final PosOrder o in orders) {
      if (o.status == OrderStatus.refunded) {
        refunds++;
        refundTotal += o.total;
        continue;
      }
      if (o.status != OrderStatus.completed) continue;

      count++;
      total += o.total;
      for (final OrderPayment p in o.payments) {
        switch (p.method) {
          case PayMethod.cash:
            cash += p.amount;
          case PayMethod.upi:
            upi += p.amount;
          case PayMethod.card:
            card += p.amount;
          case PayMethod.cod:
            cod += p.amount;
          case PayMethod.other:
            other += p.amount;
        }
      }
    }

    return ShiftSummary(
      orderCount: count,
      totalSales: total,
      cashSales: cash,
      upiSales: upi,
      cardSales: card,
      codSales: cod,
      otherSales: other,
      refundCount: refunds,
      refundTotal: refundTotal,
    );
  }
}

String? _str(dynamic value) {
  if (value == null) return null;
  final String s = value.toString();
  return s.isEmpty ? null : s;
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}