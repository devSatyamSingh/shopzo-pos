import 'package:intl/intl.dart';

/// Indian rupee formatting: ₹1,24,500.50
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _withDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _noDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// format(62655.48) -> ₹62,655.48
  /// format(124500, showDecimals: false) -> ₹1,24,500
  static String format(num? value, {bool showDecimals = true}) {
    final num v = value ?? 0;
    return (showDecimals ? _withDecimals : _noDecimals).format(v);
  }

  /// compact(1250) -> ₹1.3K, compact(250000) -> ₹2.5L, compact(25000000) -> ₹2.5Cr
  static String compact(num? value) {
    final double v = (value ?? 0).toDouble();
    final double abs = v.abs();
    final String sign = v < 0 ? '-' : '';

    if (abs >= 10000000) return '$sign₹${_trim(abs / 10000000)}Cr';
    if (abs >= 100000) return '$sign₹${_trim(abs / 100000)}L';
    if (abs >= 1000) return '$sign₹${_trim(abs / 1000)}K';
    return '$sign₹${_trim(abs)}';
  }

  /// "₹1,234.50" ya "1234.5" dono ko double bana deta hai. Fail hone pe null.
  static double? parse(String? text) {
    if (text == null) return null;
    final String cleaned = text.replaceAll(RegExp(r'[₹,\s]'), '');
    return double.tryParse(cleaned);
  }

  static String _trim(double value) {
    final String s = value.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}