class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final DateTime? createdAt;

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    String? s(dynamic v) {
      if (v == null) return null;
      final String t = v.toString();
      return t.isEmpty ? null : t;
    }

    return CustomerModel(
      id: s(json['id']) ?? '',
      name: s(json['name']) ?? 'Customer',
      phone: s(json['phone']) ?? '',
      email: s(json['email']),
      createdAt: DateTime.tryParse(s(json['createdAt']) ?? ''),
    );
  }
}