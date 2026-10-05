import 'package:flutter/foundation.dart';

class PermKey {
  PermKey._();

  static const String couponCreate = 'coupon:create';
  static const String couponDelete = 'coupon:delete';
  static const String couponRead = 'coupon:read';
  static const String couponUpdate = 'coupon:update';
  static const String customerCreate = 'customer:create';
  static const String customerRead = 'customer:read';
  static const String customerSearch = 'customer:search';
  static const String dashboardView = 'dashboard:view';
  static const String orderCreatePos = 'order:create:pos';
  static const String orderExchangePos = 'order:exchange:pos';
  static const String orderHold = 'order:hold';
  static const String orderRead = 'order:read';
  static const String orderRefund = 'order:refund';
  static const String orderUpdate = 'order:update';
  static const String productViewPos = 'product:view:pos';
  static const String reportSalesView = 'report:sales:view';
  static const String settingsUpdate = 'settings:update';
  static const String shiftManage = 'shift:manage';
  static const String shiftViewAll = 'shift:view:all';
  static const String staffManage = 'staff:manage';
  static const String staffView = 'staff:view';
}

enum ManagedRole {
  admin('ADMIN', 'Admin'),
  manager('MANAGER', 'Manager'),
  cashier('CASHIER', 'Cashier');

  const ManagedRole(this.api, this.label);

  final String api;
  final String label;
}

@immutable
class PermissionModel {
  const PermissionModel({
    required this.id,
    required this.key,
    required this.description,
    this.posFlag,
  });

  final String id;
  final String key;
  final String description;
  final bool? posFlag;

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    bool? flag;
    final dynamic raw = json['isPos'] ?? json['is_pos'];
    if (raw is bool) {
      flag = raw;
    } else {
      final String tag = (json['module'] ?? json['scope'] ?? json['type'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (tag.isNotEmpty) flag = tag == 'POS';
    }
    return PermissionModel(
      id: json['id']?.toString() ?? '',
      key: (json['key']?.toString() ?? '').trim(),
      description: (json['description']?.toString() ?? '').trim(),
      posFlag: flag,
    );
  }

  String get resource => PosPermissions.resourceOf(key);

  bool get isPos => posFlag ?? PosPermissions.inferPos(key);

  String get label => PosPermissions.labelOf(key, description: description);
}

@immutable
class PermissionGroup {
  const PermissionGroup(this.id, this.title, this.keys);

  final String id;
  final String title;
  final List<String> keys;
}

@immutable
class PermissionSection {
  const PermissionSection(this.group, this.items);
  final PermissionGroup group;
  final List<PermissionModel> items;
}

@immutable
class BulkPermissionResult {
  const BulkPermissionResult({
    required this.succeeded,
    required this.failed,
    this.firstFailure,
  });

  final List<String> succeeded;
  final List<String> failed;
  final Object? firstFailure;
  bool get hasFailures => failed.isNotEmpty;
}

class PosPermissions {
  PosPermissions._();

  static const Set<String> posResources = <String>{
    'coupon',
    'customer',
    'dashboard',
    'order',
    'report',
    'settings',
    'shift',
    'staff',
  };

  static const Set<String> hiddenKeys = <String>{};
  static const List<String> _groupOrder = <String>[
    'coupon',
    'customer',
    'dashboard',
    'order',
    'product',
    'report',
    'settings',
    'shift',
    'staff',
  ];

  static const Map<String, String> _groupTitles = <String, String>{
    'coupon': 'Coupons & Discounts',
    'customer': 'Customers',
    'dashboard': 'Dashboard',
    'order': 'Orders & Sales',
    'product': 'Products',
    'report': 'Reports',
    'settings': 'Settings',
    'shift': 'Shifts & Register',
    'staff': 'Staff & Cashiers',
  };

  static const Map<String, String> _labels = <String, String>{
    PermKey.couponCreate: 'Create coupons',
    PermKey.couponDelete: 'Delete coupons',
    PermKey.couponRead: 'View coupons',
    PermKey.couponUpdate: 'Edit coupons',
    PermKey.customerCreate: 'Add customers',
    PermKey.customerRead: 'View customers',
    PermKey.customerSearch: 'Search customers',
    PermKey.dashboardView: 'View dashboard',
    PermKey.orderCreatePos: 'Create sales',
    PermKey.orderExchangePos: 'Process exchanges',
    PermKey.orderHold: 'Hold sales',
    PermKey.orderRead: 'View orders',
    PermKey.orderRefund: 'Refund orders',
    PermKey.orderUpdate: 'Update orders',
    PermKey.productViewPos: 'View products',
    PermKey.reportSalesView: 'Sales reports',
    PermKey.settingsUpdate: 'Store settings',
    PermKey.shiftManage: 'Manage shifts',
    PermKey.shiftViewAll: 'View all shifts',
    PermKey.staffManage: 'Manage staff',
    PermKey.staffView: 'View staff',
  };

  static String resourceOf(String key) => key.split(':').first;

  static bool inferPos(String key) {
    if (key.isEmpty || hiddenKeys.contains(key)) return false;
    final List<String> parts = key.split(':');
    if (parts.contains('pos')) return true;
    return posResources.contains(parts.first);
  }

  static String groupTitle(String resource) =>
      _groupTitles[resource] ?? _capitalize(resource);

  static String labelOf(String key, {String description = ''}) {
    final String? known = _labels[key];
    if (known != null) return known;
    if (description.isNotEmpty) return description;
    return _humanize(key);
  }

  static int _groupIndex(String resource) {
    final int i = _groupOrder.indexOf(resource);
    return i == -1 ? _groupOrder.length : i;
  }

  static List<PermissionModel> orderedPos(Iterable<PermissionModel> all) {
    final List<PermissionModel> list =
        all.where((PermissionModel p) => p.isPos).toList()
          ..sort((PermissionModel a, PermissionModel b) {
            final int g = _groupIndex(
              a.resource,
            ).compareTo(_groupIndex(b.resource));
            if (g != 0) return g;
            final int r = a.resource.compareTo(b.resource);
            return r != 0 ? r : a.key.compareTo(b.key);
          });
    return list;
  }

  static List<PermissionSection> sectionsOf(Iterable<PermissionModel> all) {
    final Map<String, List<PermissionModel>> byResource =
        <String, List<PermissionModel>>{};
    for (final PermissionModel p in orderedPos(all)) {
      byResource.putIfAbsent(p.resource, () => <PermissionModel>[]).add(p);
    }
    return <PermissionSection>[
      for (final MapEntry<String, List<PermissionModel>> e
          in byResource.entries)
        PermissionSection(
          PermissionGroup(e.key, groupTitle(e.key), <String>[
            for (final PermissionModel p in e.value) p.key,
          ]),
          e.value,
        ),
    ];
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _humanize(String key) {
    final List<String> parts = key
        .split(':')
        .where((String p) => p.isNotEmpty && p != 'pos')
        .toList();
    if (parts.isEmpty) return key;
    if (parts.length == 1) return _capitalize(parts.first);
    final String resource = parts.first;
    final String action = parts.sublist(1).join(' ');
    return '${_capitalize(action)} $resource';
  }
}
