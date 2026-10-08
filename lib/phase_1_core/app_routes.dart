import 'package:flutter/material.dart';
import 'package:salesvista/phase_3_screens/backup_screen.dart';
import 'package:salesvista/phase_3_screens/company_info.dart';
import 'package:salesvista/phase_3_screens/countries_screen.dart';
import 'package:salesvista/phase_3_screens/customers_screen.dart';
import 'package:salesvista/phase_3_screens/dashboard_screen.dart';
import 'package:salesvista/phase_3_screens/expenses_screen.dart';
import 'package:salesvista/phase_3_screens/gst_r1_statement_screen.dart';
import 'package:salesvista/phase_3_screens/inventory_screen.dart';
import 'package:salesvista/phase_3_screens/invoice_screen.dart';
import 'package:salesvista/phase_3_screens/order_screen.dart';
import 'package:salesvista/phase_3_screens/pos_checkout_screen.dart';
import 'package:salesvista/phase_3_screens/reports_screen.dart';
import 'package:salesvista/phase_3_screens/return_orders_screen.dart';
import 'package:salesvista/phase_3_screens/sales_screen.dart';
import 'package:salesvista/phase_3_screens/settings_screen.dart';
import 'package:salesvista/phase_3_screens/transactions_screen.dart';
import 'package:salesvista/phase_3_screens/users_screen.dart';

class AppRoutes {
  static const String dashboard = '/';
  static const String pos = '/pos';
  static const String inventory = '/inventory';
  static const String customers = '/customers';
  static const String sales = '/sales';
  static const String transactions = '/transactions';
  static const String expenses = '/expenses';
  static const String reports = '/reports';
  static const String returns = '/returns';
  static const String backup = '/backup';
  static const String users = '/users';
  static const String countries = '/countries';
  static const String invoice = '/invoice';
  static const String orders = '/orders';
  static const String settings = '/settings';
  static const String company = '/company';
  static const String gstr1 = '/gstr1';

  static Map<String, WidgetBuilder> routes = {
    dashboard: (context) => const DashboardScreen(),
    pos: (context) => const PosCheckoutScreen(),
    inventory: (context) => const InventoryScreen(),
    customers: (context) => const CustomersScreen(),
    sales: (context) => const SalesScreen(),
    transactions: (context) => const TransactionsScreen(),
    expenses: (context) => const ExpensesScreen(),
    reports: (context) => const ReportsScreen(),
    returns: (context) => const ReturnOrdersScreen(),
    backup: (context) => const BackupScreen(),
    users: (context) => const UsersScreen(),
    countries: (context) => const CountriesScreen(),
    invoice: (context) => const InvoiceScreen(),
    orders: (context) => const OrdersScreen(),
    settings: (context) => const SettingsScreen(),
    company: (context) => const CompanyInfoScreen(),
    gstr1: (context) => const GstR1StatementScreen(),
  };
}
