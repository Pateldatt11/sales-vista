import 'package:intl/intl.dart';

class AppUtils {
  AppUtils._();

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: "₹",
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat("dd MMM yyyy").format(date);
  }

  static String generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
