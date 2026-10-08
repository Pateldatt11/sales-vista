import 'package:hive/hive.dart';

import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_2_models/expense_model.dart';

class AnalyticsService {
  final Box<OrderModel> orderBox;
  final Box<InvoiceModel> invoiceBox;
  final Box<TransactionModel> transactionBox;
  final Box<ExpenseModel> expenseBox;

  AnalyticsService({
    required this.orderBox,
    required this.invoiceBox,
    required this.transactionBox,
    required this.expenseBox,
  });

  // ===============================
  // BASIC TOTAL CALCULATIONS
  // ===============================

  double getTotalRevenue() {
    return orderBox.values.fold<double>(
      0.0,
      (double sum, OrderModel order) => sum + order.totalAmount,
    );
  }

  double getTotalExpenses() {
    return expenseBox.values.fold<double>(
      0.0,
      (double sum, ExpenseModel expense) => sum + expense.amount,
    );
  }

  double getNetProfit() {
    return getTotalRevenue() - getTotalExpenses();
  }

  int getTotalOrders() {
    return orderBox.length;
  }

  int getTotalInvoices() {
    return invoiceBox.length;
  }

  int getTotalTransactions() {
    return transactionBox.length;
  }

  // ===============================
  // DATE FILTERED CALCULATIONS
  // ===============================

  double getRevenueByDateRange(DateTime start, DateTime end) {
    return orderBox.values
        .where((OrderModel order) =>
            !order.date.isBefore(start) &&
            !order.date.isAfter(end))
        .fold<double>(
          0.0,
          (double sum, OrderModel order) => sum + order.totalAmount,
        );
  }

  double getExpensesByDateRange(DateTime start, DateTime end) {
    return expenseBox.values
        .where((ExpenseModel expense) =>
            !expense.date.isBefore(start) &&
            !expense.date.isAfter(end))
        .fold<double>(
          0.0,
          (double sum, ExpenseModel expense) => sum + expense.amount,
        );
  }

  double getProfitByDateRange(DateTime start, DateTime end) {
    return getRevenueByDateRange(start, end) -
        getExpensesByDateRange(start, end);
  }

  // ===============================
  // MONTHLY ANALYTICS
  // ===============================

  double getMonthlyRevenue(int year, int month) {
    return orderBox.values
        .where((OrderModel order) =>
            order.date.year == year &&
            order.date.month == month)
        .fold<double>(
          0.0,
          (double sum, OrderModel order) => sum + order.totalAmount,
        );
  }

  double getMonthlyExpenses(int year, int month) {
    return expenseBox.values
        .where((ExpenseModel expense) =>
            expense.date.year == year &&
            expense.date.month == month)
        .fold<double>(
          0.0,
          (double sum, ExpenseModel expense) => sum + expense.amount,
        );
  }

  double getMonthlyProfit(int year, int month) {
    return getMonthlyRevenue(year, month) -
        getMonthlyExpenses(year, month);
  }

  // ===============================
  // PRODUCT ANALYTICS
  // ===============================

 Map<String, double> getProductSalesCount() {
  final Map<String, double> productSales = <String, double>{};

  for (final OrderModel order in orderBox.values) {
    final String productName = order.productName.trim();

    if (productName.isEmpty) continue;

    productSales.update(
      productName,
      (double existing) => existing + order.quantity,
      ifAbsent: () => order.quantity,
    );
  }

  return productSales;
}


List<MapEntry<String, double>> getTopSellingProducts({int limit = 3}) {
  final Map<String, double> salesMap = getProductSalesCount();

  final List<MapEntry<String, double>> sortedList =
      salesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  return sortedList.take(limit).toList();
}


  // ===============================
  // DAILY REVENUE SUMMARY
  // ===============================

  Map<DateTime, double> getDailyRevenue() {
    final Map<DateTime, double> dailyRevenue = <DateTime, double>{};

    for (final OrderModel order in orderBox.values) {
      final DateTime dateOnly =
          DateTime(order.date.year, order.date.month, order.date.day);

      dailyRevenue.update(
        dateOnly,
        (double value) => value + order.totalAmount,
        ifAbsent: () => order.totalAmount,
      );
    }

    return dailyRevenue;
  }
}
