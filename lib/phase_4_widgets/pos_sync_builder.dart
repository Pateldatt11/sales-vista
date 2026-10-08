import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:salesvista/phase_2_models/expense_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/sales_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_2_models/user_model.dart';

/// Rebuilds the wrapped UI whenever any POS data box changes.
///
/// Hive boxes are the local source of truth for this offline POS app. Screens
/// that read from more than one box need a merged listener; otherwise a stock,
/// payment, invoice or expense change may be saved correctly but not be visible
/// until the user manually leaves and reopens the screen.
class PosSyncBuilder extends StatelessWidget {
  final WidgetBuilder builder;
  final List<Listenable>? listenables;

  const PosSyncBuilder({
    super.key,
    required this.builder,
    this.listenables,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(listenables ?? _defaultListenables()),
      builder: (context, _) => builder(context),
    );
  }

  List<Listenable> _defaultListenables() {
    return <Listenable>[
      Hive.box<SalesModel>('sales_box').listenable(),
      Hive.box<OrderModel>('orders_box').listenable(),
      Hive.box<InvoiceModel>('invoice_box').listenable(),
      Hive.box<TransactionModel>('transactions_box').listenable(),
      Hive.box<ExpenseModel>('expenses_box').listenable(),
      Hive.box<UserModel>('users_box').listenable(),
      Hive.box('inventory_meta_box').listenable(),
      Hive.box('customers_box').listenable(),
      Hive.box('settingsBox').listenable(),
      Hive.box('app_audit_box').listenable(),
      Hive.box('return_orders_box').listenable(),
    ];
  }
}
