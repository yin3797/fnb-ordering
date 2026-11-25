import 'package:intl/intl.dart';

final _amount = NumberFormat('#,##0.00', 'en_MY');

/// 199999 becomes "RM1,999.99". A negative amount, such as a discount,
/// becomes "-RM5.00".
String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  return '${sign}RM${_amount.format(cents.abs() / 100)}';
}

/// "1 item" or "3 items".
String formatItemCount(int count) => count == 1 ? '1 item' : '$count items';
