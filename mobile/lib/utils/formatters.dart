import 'package:intl/intl.dart';

class Formatters {
  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(dateTime);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('d MMM yyyy, h:mm a').format(dateTime);
  }

  static List<String> parseSerials(String input) {
    return input
        .split(RegExp(r'[\n,\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
