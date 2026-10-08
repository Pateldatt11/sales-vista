import 'package:hive/hive.dart';
import '../phase_2_models/order_model.dart';
import '../phase_2_models/invoice_model.dart';
import '../phase_2_models/transaction_model.dart';

class OrderService {

  final Box<OrderModel> orderBox = Hive.box<OrderModel>('orders_box');
  final Box<InvoiceModel> invoiceBox = Hive.box<InvoiceModel>('invoice_box');
  final Box<TransactionModel> transactionBox = Hive.box<TransactionModel>('transactions_box');

  // ================= CREATE =================
  Future<void> createOrder({
    required OrderModel order,
    required InvoiceModel invoice,
    required TransactionModel transaction,
  }) async {

    await orderBox.put(order.id, order);
    await invoiceBox.put(order.id, invoice);
    await transactionBox.put(order.id, transaction);
  }

  // ================= UPDATE =================
  Future<void> updateOrder({
    required OrderModel order,
    required InvoiceModel invoice,
    required TransactionModel transaction,
  }) async {

    await orderBox.put(order.id, order);
    await invoiceBox.put(order.id, invoice);
    await transactionBox.put(order.id, transaction);
  }

  // ================= DELETE (CASCADE) =================
  Future<void> deleteOrder(String orderId) async {

    await orderBox.delete(orderId);
    await invoiceBox.delete(orderId);
    await transactionBox.delete(orderId);
  }
}
