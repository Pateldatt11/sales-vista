import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../phase_2_models/order_model.dart';
import '../phase_2_models/transaction_model.dart';
import '../phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderBox = Hive.box<OrderModel>('orders_box');
    final transactionBox = Hive.box<TransactionModel>('transactions_box');

    Widget salesBody = ValueListenableBuilder(
      valueListenable: orderBox.listenable(),
      builder: (context, Box<OrderModel> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("No sales/orders available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final order = box.getAt(index)!;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  "${order.productName} x${order.quantity}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Customer: ${order.customerName}\n"
                  "Amount: ₹${(order.totalAmount).toStringAsFixed(2)}\n"
                  "Paid: ₹${(order.paidAmount ?? 0.0).toStringAsFixed(2)}\n"
                  "Due: ₹${(order.dueAmount ?? 0.0).toStringAsFixed(2)}\n"
                  "Date: ${order.date.toLocal().toString().split(' ')[0]}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Delete all linked transactions first
                    final relatedTransactions = transactionBox.values
                        .where((t) => t.orderId == order.id)
                        .toList();
                    for (var t in relatedTransactions) {
                      t.delete();
                    }

                    // Delete the order itself
                    order.delete();
                  },
                ),
                onTap: () => _showUpdatePaymentDialog(context, order, transactionBox),
              ),
            );
          },
        );
      },
    );

    return BaseScaffold(
      title: "Sales",
      currentRoute: AppRoutes.sales,
      body: Stack(
        children: [
          salesBody,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showAddManualSaleDialog(context, orderBox, transactionBox),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddManualSaleDialog(
      BuildContext context, Box<OrderModel> orderBox, Box<TransactionModel> transactionBox) {
    final productController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Manual Sale"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: productController,
              decoration: const InputDecoration(labelText: "Product Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Amount"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final productName = productController.text.trim();
              final totalAmount = double.tryParse(amountController.text.trim()) ?? 0.0;

              if (productName.isEmpty || totalAmount <= 0) return;

              final paidAmount = totalAmount;
              final dueAmount = totalAmount - paidAmount;

              final newOrder = OrderModel(
                id: const Uuid().v4(),
                productName: productName,
                quantity: 1,
                customerName: "Manual",
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                dueAmount: dueAmount,
                date: DateTime.now(),
              );

              orderBox.add(newOrder);

              // Add linked transaction
              transactionBox.add(TransactionModel(
                id: const Uuid().v4(),
                title: "${newOrder.productName} x${newOrder.quantity}",
                amount: paidAmount,
                type: "income",
                date: DateTime.now(),
                orderId: newOrder.id,
              ));

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showUpdatePaymentDialog(
      BuildContext context, OrderModel order, Box<TransactionModel> transactionBox) {
    final paidController = TextEditingController(
      text: (order.paidAmount ?? 0.0).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Payment"),
        content: TextField(
          controller: paidController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Paid Amount"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final paidAmount = double.tryParse(paidController.text.trim()) ?? 0.0;
              final totalAmount = order.totalAmount;
              final dueAmount = totalAmount - paidAmount;

              // Update order
              order.paidAmount = paidAmount;
              order.dueAmount = dueAmount;
              order.save();

              // Update linked transaction if exists
              TransactionModel? relatedTransaction;
try {
  relatedTransaction = transactionBox.values
      .firstWhere((t) => t.orderId == order.id);
} catch (e) {
  relatedTransaction = null;
}


              if (relatedTransaction != null) {
                relatedTransaction.amount = paidAmount;
                relatedTransaction.save();
              }

              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
