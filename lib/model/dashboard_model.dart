/// GET /pos/reports/sales/daily?from=YYYY-MM-DD&to=YYYY-MM-DD
///
/// `ApiService` ke `parser` se sirf `data` wala hissa milta hai, wahi
/// [DailySalesReport.fromJson] ko dena hai.
///
/// Sample:
/// ```json
/// {
///   "dateRange": {"from": "...", "to": "..."},
///   "totalOrders": 25,
///   "grossSales": 145508.35,
///   "totalRefunds": 1228.96,
///   "netSales": 144279.39,
///   "paymentBreakdown": {"COD": 144640.45, "CASH": 618.95, "UPI": 218.95},
///   "channelBreakdown": {"POS": {"count": 2, "total": 837.9}},
///   "cashierBreakdown": [{"cashierId": "..", "cashierName": "..", "totalSales": 837.9, "orderCount": 2}]
/// }
/// ```
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

  /// {'CASH': 618.95, 'UPI': 218.95, 'COD': 144640.45}
  final Map<String, double> paymentBreakdown;

  /// {'POS': ChannelSales(2, 837.9), 'ONLINE': ChannelSales(23, 144670.45)}
  final Map<String, ChannelSales> channelBreakdown;

  final List<CashierSales> cashierBreakdown;

  /// Server avg order nahi bhejta, isliye net sales / orders.
  double get avgOrderValue => totalOrders == 0 ? 0 : netSales / totalOrders;

  double get paymentTotal =>
      paymentBreakdown.values.fold<double>(0, (double s, double v) => s + v);

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

// ── Safe converters (server kabhi int, kabhi double, kabhi string bhejta hai) ──

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