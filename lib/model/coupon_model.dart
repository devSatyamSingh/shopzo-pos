import 'package:flutter/foundation.dart';

enum CouponDiscountType { percentage, fixed }

enum CouponStatus { active, expired, usedUp, inactive }

@immutable
class CouponModel {
  const CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    required this.minOrderValue,
    required this.maxUses,
    required this.usedCount,
    required this.isActive,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String code;
  final CouponDiscountType discountType;

  /// PERCENTAGE ho to 12 = 12%, FIXED ho to 10 = ₹10.
  final double value;
  final double minOrderValue;

  /// 0 ya usse kam = unlimited uses.
  final int maxUses;
  final int usedCount;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString().trim().toUpperCase(),
      discountType: _parseType(json['discountType']),
      value: _toDouble(json['value']),
      minOrderValue: _toDouble(json['minOrderValue']),
      maxUses: _toInt(json['maxUses']),
      usedCount: _toInt(json['usedCount']),
      isActive: json['isActive'] == true,
      expiresAt: _toDate(json['expiresAt']),
      createdAt: _toDate(json['createdAt']),
    );
  }

  bool get isPercentage => discountType == CouponDiscountType.percentage;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  bool get isUsedUp => maxUses > 0 && usedCount >= maxUses;

  /// null = unlimited.
  int? get remainingUses {
    if (maxUses <= 0) return null;
    final int left = maxUses - usedCount;
    return left < 0 ? 0 : left;
  }

  bool get isUsable => status == CouponStatus.active;

  CouponStatus get status {
    if (!isActive) return CouponStatus.inactive;
    if (isExpired) return CouponStatus.expired;
    if (isUsedUp) return CouponStatus.usedUp;
    return CouponStatus.active;
  }

  static CouponDiscountType _parseType(dynamic raw) {
    return raw.toString().toUpperCase() == 'FIXED'
        ? CouponDiscountType.fixed
        : CouponDiscountType.percentage;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}