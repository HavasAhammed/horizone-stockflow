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

  static String formatWattage(int wattage) {
    switch (wattage) {
      case 540:
        return '540W Mono PERC';
      case 450:
        return '450W Bifacial';
      case 400:
        return '400W High Efficiency';
      case 330:
        return '330W Polycrystalline';
      default:
        return '${wattage}W Solar Panel';
    }
  }
}
