import 'dart:convert';

enum UserRole {
  admin,
  manager,
  cashier,
  accountant,
  staff,
  unknown;

  static UserRole parse(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v == 'ADMIN') return UserRole.admin;
    if (v == 'MANAGER') return UserRole.manager;
    if (v == 'CASHIER') return UserRole.cashier;
    if (v.contains('ACCOUNT')) return UserRole.accountant;
    if (v.contains('STAFF')) return UserRole.staff;
    return UserRole.unknown;
  }
}

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.roleName,
    this.email,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final String roleName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isCashier => role == UserRole.cashier;

  String get roleLabel {
    if (roleName.isEmpty) return 'User';
    final String lower = roleName.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String get initials {
    final List<String> parts =
    name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final String rawRole = _string(json['role']) ?? '';
    return UserModel(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? '',
      phone: _string(json['phone']) ?? '',
      email: _string(json['email']),
      role: UserRole.parse(rawRole),
      roleName: rawRole,
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: DateTime.tryParse(_string(json['createdAt']) ?? ''),
      updatedAt: DateTime.tryParse(_string(json['updatedAt']) ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'role': roleName,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static UserModel? tryParse(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final UserModel user =
      UserModel.fromJson(Map<String, dynamic>.from(decoded));
      return user.id.isEmpty ? null : user;
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());

  static String? _string(dynamic value) {
    if (value == null) return null;
    final String s = value.toString();
    return s.isEmpty ? null : s;
  }

  @override
  String toString() => 'UserModel($id, $name, $roleName)';
}