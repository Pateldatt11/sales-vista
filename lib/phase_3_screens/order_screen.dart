import 'dart:ui';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:salesvista/phase_2_models/sales_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/user_model.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: selectedIndex == 0 ? "Products" : "Orders",
      currentRoute: AppRoutes.orders,
      body: Stack(
        children: [
          selectedIndex == 0 ? _buildProductsTab() : _buildOrdersTab(),

          /// ADD PRODUCT BUTTON
          if (selectedIndex == 0)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddProductDialog(context),
                child: const Icon(Icons.add),
              ),
            ),

          /// ADD ORDER BUTTON
          if (selectedIndex == 1)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.pos),
                child: const Icon(Icons.point_of_sale_rounded),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFloatingTabBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTabBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(24),
            // ignore: deprecated_member_use
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabButton("Products", Icons.storefront_rounded, 0),
              _buildTabButton("Orders", Icons.shopping_cart_rounded, 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    bool isSelected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              // ignore: deprecated_member_use
              ? Colors.white.withOpacity(0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.indigo : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.indigo : Colors.grey[600],
                fontSize: 16,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    final salesBox = Hive.box<SalesModel>('sales_box');

    return ValueListenableBuilder(
      valueListenable: salesBox.listenable(),
      builder: (context, Box<SalesModel> box, _) {
        if (box.isEmpty) {
          return const Center(
            child: Text(
              "No products available.\nTap + to add products.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final product = box.getAt(index)!;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(
                  product.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text("Price: ₹${product.amount.toStringAsFixed(2)}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => product.delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    final orderBox = Hive.box<OrderModel>('orders_box');

    return ValueListenableBuilder(
      valueListenable: orderBox.listenable(),
      builder: (context, Box<OrderModel> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("No orders available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final order = box.getAt(index)!;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.customerName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          const SizedBox(height: 10),
                          Text("Product: ${order.productName}"),
                          Text(
                              "Quantity: ${order.quantity.toStringAsFixed(2)}"),
                          Text(
                              "Date: ${order.date.toLocal().toString().split(' ')[0]}"),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹${order.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _deleteOrder(order),
                          child:
                              const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final salesBox = Hive.box<SalesModel>('sales_box');
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: "Product Name")),
            const SizedBox(height: 10),
            TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Price")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final amount =
                  double.tryParse(amountController.text.trim());
              if (nameController.text.trim().isEmpty ||
                  // ignore: curly_braces_in_flow_control_structures
                  amount == null) return;

              final product = SalesModel(
                id: const Uuid().v4(),
                productName: nameController.text.trim(),
                amount: amount,
                date: DateTime.now(),
                customerName: '',
              );

              salesBox.put(product.id, product);
              Navigator.pop(context);
            },
            child: const Text("Add Product"),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context) {
    final salesBox = Hive.box<SalesModel>('sales_box');
    final orderBox = Hive.box<OrderModel>('orders_box');
    final invoiceBox = Hive.box<InvoiceModel>('invoice_box');
    final transactionBox = Hive.box<TransactionModel>('transactions_box');
    final usersBox = Hive.box<UserModel>('users_box');
    final repo = PosRepository();

    SalesModel? selectedProduct;
    UserModel? selectedUser;

    final quantityController = TextEditingController(text: "1");
    final paidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // ignore: no_leading_underscores_for_local_identifiers
          void _autoFillPaidAmount() {
            if (selectedProduct != null) {
              final qty =
                  double.tryParse(quantityController.text.trim()) ?? 1;

              final total = selectedProduct!.amount * qty;
              paidController.text = total.toStringAsFixed(2);
            }
          }

          return AlertDialog(
            title: const Text("Add Order"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButton<SalesModel>(
                    hint: const Text("Select Product"),
                    value: selectedProduct,
                    isExpanded: true,
                    items: salesBox.values
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                "${e.productName} - ₹${e.amount.toStringAsFixed(2)}",
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedProduct = v;
                      });
                      _autoFillPaidAmount();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<UserModel>(
                    hint: const Text("Select Customer"),
                    value: selectedUser,
                    isExpanded: true,
                    items: usersBox.values
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedUser = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Quantity"),
                    onChanged: (_) => _autoFillPaidAmount(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: paidController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Paid Amount"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedProduct == null ||
                      selectedUser == null) {
                    _showError("Select product & customer");
                    return;
                  }

                  final qty =
                      double.tryParse(quantityController.text.trim()) ??
                          0;

                  final paid =
                      double.tryParse(paidController.text.trim()) ?? 0;

                  if (qty <= 0) {
                    _showError("Quantity must be greater than 0");
                    return;
                  }

                  final total = selectedProduct!.amount * qty;

                  if (paid > total) {
                    _showError("Paid amount cannot exceed total");
                    return;
                  }

                  final due = total - paid;
                  final now = DateTime.now();
                  final orderId = const Uuid().v4();
                  final invoiceId = repo.invoiceNumberFor(now);

                  final order = OrderModel(
                    id: orderId,
                    salesId: selectedProduct!.id,
                    productName:
                        selectedProduct!.productName,
                    quantity: qty,
                    customerName: selectedUser!.name,
                    totalAmount: total,
                    paidAmount: paid,
                    dueAmount: due,
                    date: now,
                  );

                  await orderBox.put(orderId, order);

                  final invoice = InvoiceModel(
                    id: invoiceId,
                    orderId: orderId,
                    saleId: selectedProduct!.id,
                    customerName: selectedUser!.name,
                    amount: total,
                    productName:
                        selectedProduct!.productName,
                    quantity: qty,
                    unitPrice: selectedProduct!.amount,
                    lineItems: [
                      {
                        'orderId': orderId,
                        'productId': selectedProduct!.id,
                        'productName': selectedProduct!.productName,
                        'hsn': '',
                        'quantity': qty,
                        'unitPrice': selectedProduct!.amount,
                        'gstPercent': 0.0,
                      },
                    ],
                    paidAmount: paid,
                    dueAmount: due,
                    date: now,
                  );

                  await invoiceBox.put(invoiceId, invoice);

                  final transaction = TransactionModel(
                    id: invoiceId,
                    orderId: orderId,
                    title: "POS Bill $invoiceId - ${selectedUser!.name}",
                    amount: paid,
                    type: "income",
                    date: now,
                  );

                  if (paid > 0) {
                    await transactionBox.put(invoiceId, transaction);
                  }

                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                },
                child: const Text("Add Order"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _deleteOrder(OrderModel order) async {
    final orderBox = Hive.box<OrderModel>('orders_box');
    final invoiceBox = Hive.box<InvoiceModel>('invoice_box');
    final transactionBox =
        Hive.box<TransactionModel>('transactions_box');

    await orderBox.delete(order.id);
    await invoiceBox.delete(order.id);
    await transactionBox.delete(order.id);

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order Deleted")));
  }
}