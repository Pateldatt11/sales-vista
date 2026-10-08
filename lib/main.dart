import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Models
import 'package:salesvista/phase_2_models/sales_model.dart';
import 'package:salesvista/phase_2_models/user_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_2_models/country_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';

// ✅ Phase 3 Model
import 'package:salesvista/phase_2_models/expense_model.dart';

// Core
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await _initHive();

  // Run App
  runApp(const SalesVistaApp());
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  // ---------------- Register Adapters ---------------- //
  _registerAdapterIfNeeded<SalesModel>(0, SalesModelAdapter());
  _registerAdapterIfNeeded<UserModel>(1, UserModelAdapter());
  _registerAdapterIfNeeded<TransactionModel>(2, TransactionModelAdapter());
  _registerAdapterIfNeeded<CountryModel>(3, CountryModelAdapter());
  _registerAdapterIfNeeded<OrderModel>(5, OrderModelAdapter());
  _registerAdapterIfNeeded<InvoiceModel>(6, InvoiceModelAdapter());

  // ✅ Register ExpenseModel (NEW)
  _registerAdapterIfNeeded<ExpenseModel>(7, ExpenseModelAdapter());

  // ---------------- Open Boxes ---------------- //
  await Future.wait([
    Hive.openBox<SalesModel>('sales_box'),
    Hive.openBox<TransactionModel>('transactions_box'),
    Hive.openBox<UserModel>('users_box'),
    Hive.openBox<CountryModel>('countries_box'),
    Hive.openBox<OrderModel>('orders_box'),
    Hive.openBox<InvoiceModel>('invoice_box'),

    // ✅ Open Expense Box (NEW)
    Hive.openBox<ExpenseModel>('expenses_box'),
    Hive.openBox('settingsBox'),
    Hive.openBox('inventory_meta_box'),
    Hive.openBox('customers_box'),
    Hive.openBox('app_audit_box'),
    Hive.openBox('return_orders_box'),
  ]);

  await PosRepository().seedIfEmpty();
}

// Helper to safely register Hive adapters
void _registerAdapterIfNeeded<T>(int typeId, TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(typeId)) {
    Hive.registerAdapter(adapter);
  }
}

// ---------------- Main App ---------------- //
class SalesVistaApp extends StatelessWidget {
  const SalesVistaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SalesVista',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.dashboard,
      routes: AppRoutes.routes,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
