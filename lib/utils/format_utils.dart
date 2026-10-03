import 'package:intl/intl.dart';

/// Rupee, date, time aur duration ka formatting ek jagah.
/// Saare date / time device ke local timezone me dikhte hain (server UTC bhejta hai).
class FormatUtils {
  FormatUtils._();

  static final NumberFormat _inr2 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _inr0 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _weekday = DateFormat('EEE, dd MMM');

  /// 1000 -> ₹1,000 | 62655.48 -> ₹62,655.48 | 124500 -> ₹1,24,500
  /// [decimals] null ho to poora number ho to decimals nahi dikhte.
  static String inr(num? value, {bool? decimals}) {
    final num v = value ?? 0;
    final bool showDecimals = decimals ?? (v % 1 != 0);
    return (showDecimals ? _inr2 : _inr0).format(v);
  }

  /// +₹1,200 / −₹300 / ₹0
  static String signedInr(num? value) {
    final num v = value ?? 0;
    if (v == 0) return inr(0);
    return '${v > 0 ? '+' : '−'}${inr(v.abs())}';
  }

  /// 03 Oct 2026
  static String date(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());

  /// 11:05 AM
  static String time(DateTime? d) => d == null ? '—' : _time.format(d.toLocal());

  /// 03 Oct 2026, 11:05 AM
  static String dateTime(DateTime? d) =>
      d == null ? '—' : _dateTime.format(d.toLocal());

  /// Sat, 03 Oct
  static String weekday(DateTime d) => _weekday.format(d.toLocal());

  /// Aaj ka ho to "11:05 AM", warna "02 Oct, 11:05 AM".
  static String since(DateTime? d) {
    if (d == null) return '—';
    final DateTime local = d.toLocal();
    final DateTime now = DateTime.now();
    final bool today = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return today
        ? _time.format(local)
        : '${_shortDate.format(local)}, ${_time.format(local)}';
  }

  /// 2h 15m | 45m | Just now
  static String duration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just now';
  }
}