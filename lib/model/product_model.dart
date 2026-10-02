/// GET /products/pos/search
///
/// Response: `{ "data": [ProductModel...], "pagination": {...} }`
/// Poori body chahiye (list + pagination), isliye repository mein `bodyParser`
/// use hota hai aur [ProductPage.fromJson] ko poori body milti hai.

enum StockLevel { inStock, low, out }

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.image,
    required this.hasVariants,
    required this.inStock,
    required this.variants,
  });

  /// Itne ya isse kam stock = "Low stock".
  static const int lowStockLimit = 10;

  final String id;
  final String name;
  final String sku;
  final double price;
  final int stock;
  final String? image;
  final bool hasVariants;
  final bool inStock;
  final List<ProductVariant> variants;

  int get variantCount => variants.length;

  /// Variants wale product ka asli stock unke variants ka jod hota hai
  /// (top-level `stock` unse match nahi karta).
  int get effectiveStock => hasVariants && variants.isNotEmpty
      ? variants.fold<int>(0, (int s, ProductVariant v) => s + v.stock)
      : stock;

  StockLevel get stockLevel {
    if (!inStock || effectiveStock <= 0) return StockLevel.out;
    if (effectiveStock <= lowStockLimit) return StockLevel.low;
    return StockLevel.inStock;
  }

  double get minPrice => variants.isEmpty
      ? price
      : variants.map((ProductVariant v) => v.price).reduce((double a, double b) => a < b ? a : b);

  double get maxPrice => variants.isEmpty
      ? price
      : variants.map((ProductVariant v) => v.price).reduce((double a, double b) => a > b ? a : b);

  bool get hasPriceRange => minPrice != maxPrice;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawVariants = json['variants'];
    return ProductModel(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? 'Unnamed product',
      sku: _string(json['sku']) ?? '',
      price: _double(json['price']),
      stock: _int(json['stock']),
      image: _string(json['image']),
      hasVariants: json['hasVariants'] == true,
      inStock: json['inStock'] is bool ? json['inStock'] as bool : true,
      variants: <ProductVariant>[
        if (rawVariants is List)
          for (final dynamic v in rawVariants)
            if (v is Map) ProductVariant.fromJson(Map<String, dynamic>.from(v)),
      ],
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.inStock,
    required this.image,
  });

  final String id;
  final String name;
  final String sku;
  final double price;
  final int stock;
  final bool inStock;
  final String? image;

  /// Kuch variants ka naam khali aata hai, tab SKU dikhao.
  String get displayName => name.trim().isNotEmpty ? name.trim() : sku;

  StockLevel get stockLevel {
    if (!inStock || stock <= 0) return StockLevel.out;
    if (stock <= ProductModel.lowStockLimit) return StockLevel.low;
    return StockLevel.inStock;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? '',
      sku: _string(json['sku']) ?? '',
      price: _double(json['price']),
      stock: _int(json['stock']),
      inStock: json['inStock'] is bool ? json['inStock'] as bool : true,
      image: _string(json['image']),
    );
  }
}

/// Ek page ka result + pagination.
class ProductPage {
  const ProductPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<ProductModel> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory ProductPage.fromJson(Map<String, dynamic> body) {
    final dynamic data = body['data'];
    final dynamic pg = body['pagination'];
    final Map<dynamic, dynamic> pagination = pg is Map ? pg : const <dynamic, dynamic>{};

    final List<ProductModel> items = <ProductModel>[
      if (data is List)
        for (final dynamic p in data)
          if (p is Map) ProductModel.fromJson(Map<String, dynamic>.from(p)),
    ];

    return ProductPage(
      items: items,
      page: _int(pagination['page'], fallback: 1),
      limit: _int(pagination['limit'], fallback: items.length),
      total: _int(pagination['total'], fallback: items.length),
      totalPages: _int(pagination['totalPages'], fallback: 1),
    );
  }
}

// ── Safe converters ────────────────────────────────────────────────────────

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v, {int fallback = 0}) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String? _string(dynamic v) {
  if (v == null) return null;
  final String s = v.toString();
  return s.isEmpty ? null : s;
}