class DailySalesReport {
  const DailySalesReport({
    required this.from,
    required this.to,
    required this.totalOrders,
    required this.grossSales,
    required this.totalRefunds,
    required this.netSales,
    required this.paymentBreakdown,
    required this.channelBreakdown,
    required this.cashierBreakdown,
  });

  final DateTime? from;
  final DateTime? to;
  final int totalOrders;
  final double grossSales;
  final double totalRefunds;
  final double netSales;
  final Map<String, double> paymentBreakdown;
  final Map<String, ChannelSales> channelBreakdown;
  final List<CashierSales> cashierBreakdown;
  double get avgOrderValue => totalOrders == 0 ? 0 : netSales / totalOrders;
  double get paymentTotal => paymentBreakdown.values.fold<double>(0, (double s, double v) => s + v);

  factory DailySalesReport.fromJson(Map<String, dynamic> json) {
    final dynamic range = json['dateRange'];
    final Map<dynamic, dynamic> payments =
    json['paymentBreakdown'] is Map ? json['paymentBreakdown'] as Map : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> channels =
    json['channelBreakdown'] is Map ? json['channelBreakdown'] as Map : const <dynamic, dynamic>{};
    final List<dynamic> cashiers =
    json['cashierBreakdown'] is List ? json['cashierBreakdown'] as List : const <dynamic>[];

    return DailySalesReport(
      from: range is Map ? _date(range['from']) : null,
      to: range is Map ? _date(range['to']) : null,
      totalOrders: _int(json['totalOrders']),
      grossSales: _double(json['grossSales']),
      totalRefunds: _double(json['totalRefunds']),
      netSales: _double(json['netSales']),
      paymentBreakdown: <String, double>{
        for (final MapEntry<dynamic, dynamic> e in payments.entries)
          e.key.toString(): _double(e.value),
      },
      channelBreakdown: <String, ChannelSales>{
        for (final MapEntry<dynamic, dynamic> e in channels.entries)
          if (e.value is Map)
            e.key.toString(): ChannelSales.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      },
      cashierBreakdown: <CashierSales>[
        for (final dynamic c in cashiers)
          if (c is Map) CashierSales.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }
}

class ChannelSales {
  const ChannelSales({required this.count, required this.total});
  final int count;
  final double total;

  factory ChannelSales.fromJson(Map<String, dynamic> json) {
    return ChannelSales(
      count: _int(json['count']),
      total: _double(json['total']),
    );
  }
}

class CashierSales {
  const CashierSales({
    required this.id,
    required this.name,
    required this.totalSales,
    required this.orderCount,
  });

  final String id;
  final String name;
  final double totalSales;
  final int orderCount;

  factory CashierSales.fromJson(Map<String, dynamic> json) {
    return CashierSales(
      id: (json['cashierId'] ?? '').toString(),
      name: (json['cashierName'] ?? 'Unknown').toString(),
      totalSales: _double(json['totalSales']),
      orderCount: _int(json['orderCount']),
    );
  }
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;