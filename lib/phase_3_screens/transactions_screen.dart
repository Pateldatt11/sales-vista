import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../phase_2_models/transaction_model.dart';
import '../phase_2_models/order_model.dart';
import '../phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String selectedType = "income";

  @override
  Widget build(BuildContext context) {
    final transactionBox = Hive.box<TransactionModel>('transactions_box');
    final orderBox = Hive.box<OrderModel>('orders_box');

    Widget transactionsBody = ValueListenableBuilder(
      valueListenable: transactionBox.listenable(),
      builder: (context, Box<TransactionModel> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("No transactions available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final transaction = box.getAt(index)!;
            final isIncome = transaction.type == "income";

            // If this transaction is linked to an order, fetch order info
            // inside ListView.builder:
OrderModel? linkedOrder;
if (transaction.orderId != null) {
  try {
    linkedOrder = orderBox.values.firstWhere((o) => o.id == transaction.orderId);
  } catch (e) {
    linkedOrder = null;
  }
}


            final amount = linkedOrder != null ? linkedOrder.paid : transaction.amount;
            final due = linkedOrder != null ? linkedOrder.due : 0.0;
            final customerName = linkedOrder?.customerName ?? "";

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  transaction.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  linkedOrder != null
                      ? "Customer: $customerName\nPaid: ₹${amount.toStringAsFixed(2)}\nDue: ₹${due.toStringAsFixed(2)}\nDate: ${transaction.date.toLocal().toString().split(' ')[0]}"
                      : "Amount: ₹${amount.toStringAsFixed(2)}\nDate: ${transaction.date.toLocal().toString().split(' ')[0]}",
                ),
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    // Delete transaction
                    await transaction.delete();

                    // If linked to an order, optionally update order's paid/due
                    if (linkedOrder != null) {
                      linkedOrder.paidAmount = 0.0;
                      linkedOrder.dueAmount = linkedOrder.totalAmount;
                      linkedOrder.save();
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );

    return BaseScaffold(
      title: "Transactions",
      currentRoute: AppRoutes.transactions,
      body: Stack(
        children: [
          transactionsBody,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showAddTransactionDialog(context, transactionBox),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, Box<TransactionModel> transactionBox) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Transaction"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Amount"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: "income", child: Text("Income")),
                  DropdownMenuItem(value: "expense", child: Text("Expense")),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedType = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "Type"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty || amountController.text.isEmpty) return;

                final newTransaction = TransactionModel(
                  id: const Uuid().v4(),
                  title: titleController.text.trim(),
                  amount: double.tryParse(amountController.text.trim()) ?? 0.0,
                  type: selectedType,
                  date: DateTime.now(),
                  orderId: null, // can link to an order if needed
                );

                transactionBox.add(newTransaction);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
