import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:salesvista/phase_2_models/expense_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/sales_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_2_models/user_model.dart';

class PosRepository {
  static final _uuid = Uuid();

  Box<SalesModel> get productsBox => Hive.box<SalesModel>('sales_box');
  Box<OrderModel> get ordersBox => Hive.box<OrderModel>('orders_box');
  Box<InvoiceModel> get invoicesBox => Hive.box<InvoiceModel>('invoice_box');
  Box<TransactionModel> get transactionsBox => Hive.box<TransactionModel>('transactions_box');
  Box<UserModel> get usersBox => Hive.box<UserModel>('users_box');
  Box<ExpenseModel> get expensesBox => Hive.box<ExpenseModel>('expenses_box');
  Box get inventoryMetaBox => Hive.box('inventory_meta_box');
  Box get customersBox => Hive.box('customers_box');
  Box get settingsBox => Hive.box('settingsBox');
  Box get auditBox => Hive.box('app_audit_box');
  Box get returnsBox => Hive.box('return_orders_box');

  String get invoicePrefix {
    final value = settingsBox.get('invoicePrefix', defaultValue: 'INV').toString().trim().toUpperCase();
    return value.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String previewNextInvoiceNumber({DateTime? date}) {
    return invoiceNumberFor(date ?? DateTime.now());
  }

  String invoiceNumberFor(DateTime date, {int? sequence}) {
    final dateKey = _invoiceDateKey(date);
    final seq = (sequence ?? nextDailyInvoiceSequence(date)).toString().padLeft(3, '0');
    final prefix = invoicePrefix;
    return prefix.isEmpty ? '$dateKey-$seq' : '$prefix-$dateKey-$seq';
  }

  int nextDailyInvoiceSequence(DateTime date) {
    final dateKey = _invoiceDateKey(date);
    final pattern = RegExp('^(?:[A-Z0-9]+-)?$dateKey-(\\d+)\$');
    var maxSequence = 0;

    for (final key in invoicesBox.keys) {
      final sequence = _sequenceFromInvoiceNumber(key.toString(), pattern);
      if (sequence > maxSequence) maxSequence = sequence;
    }

    for (final invoice in invoicesBox.values) {
      final sequence = _sequenceFromInvoiceNumber(invoice.id, pattern);
      if (sequence > maxSequence) maxSequence = sequence;
    }

    return maxSequence + 1;
  }


  String returnNumberFor(DateTime date, {int? sequence}) {
    final dateKey = _invoiceDateKey(date);
    final seq = (sequence ?? nextDailyReturnSequence(date)).toString().padLeft(3, '0');
    return 'RTN-$dateKey-$seq';
  }

  int nextDailyReturnSequence(DateTime date) {
    final dateKey = _invoiceDateKey(date);
    final pattern = RegExp('^RTN-$dateKey-(\\d+)\$');
    var maxSequence = 0;

    for (final key in returnsBox.keys) {
      final sequence = _sequenceFromInvoiceNumber(key.toString(), pattern);
      if (sequence > maxSequence) maxSequence = sequence;
    }

    for (final raw in returnsBox.values) {
      final data = _readMap(raw);
      final sequence = _sequenceFromInvoiceNumber(data['id']?.toString() ?? '', pattern);
      if (sequence > maxSequence) maxSequence = sequence;
    }

    return maxSequence + 1;
  }

  List<ReturnOrderRecord> returnRecords() {
    final records = returnsBox.values
        .map((raw) => ReturnOrderRecord.fromMap(_readMap(raw)))
        .where((record) => record.id.isNotEmpty)
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  String previewNextRefillBatchNumber({DateTime? date}) {
    return refillBatchNumberFor(date ?? DateTime.now());
  }

  String refillBatchNumberFor(DateTime date, {int? sequence}) {
    final dateKey = _invoiceDateKey(date);
    final seq = (sequence ?? nextDailyRefillSequence(date)).toString().padLeft(3, '0');
    return 'BATCH-$dateKey-$seq';
  }

  int nextDailyRefillSequence(DateTime date) {
    final counterValue = _asInt(settingsBox.get(_refillBatchCounterKey(date)));
    final existingMax = _maxDailyRefillSequence(date);
    return (counterValue > existingMax ? counterValue : existingMax) + 1;
  }

  Future<String> _reserveNextRefillBatchNumber(DateTime date) async {
    final sequence = nextDailyRefillSequence(date);
    await settingsBox.put(_refillBatchCounterKey(date), sequence);
    return refillBatchNumberFor(date, sequence: sequence);
  }

  int _maxDailyRefillSequence(DateTime date) {
    final dateKey = _invoiceDateKey(date);
    final pattern = RegExp('^(?:BATCH|BAT|BCH|REF|RF)-$dateKey-(\\d+)\$');
    var maxSequence = 0;
    for (final expense in expensesBox.values) {
      final sequence = _sequenceFromInvoiceNumber(expense.batchNumber, pattern);
      if (sequence > maxSequence) maxSequence = sequence;
    }
    return maxSequence;
  }

  String _refillBatchCounterKey(DateTime date) => 'refill_batch_sequence_${_invoiceDateKey(date)}';

  List<PosProduct> products() {
    final items = productsBox.values.map((product) {
      final meta = _readMap(inventoryMetaBox.get(product.id));
      return PosProduct(product: product, meta: meta);
    }).toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  List<PosCustomer> customers() {
    final items = customersBox.keys.map((key) {
      final data = _readMap(customersBox.get(key));
      return PosCustomer(id: key.toString(), data: data);
    }).toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<String> saveProduct({
    String? id,
    required String name,
    required double sellingPrice,
    required double openingStock,
    String sku = '',
    String barcode = '',
    String hsn = '',
    String unit = 'PCS',
    double purchasePrice = 0,
    double gstPercent = 0,
    double lowStock = 5,
    bool replaceStock = false,
  }) async {
    final productId = id ?? _uuid.v4();
    final existing = productsBox.get(productId);
    final currentMeta = _readMap(inventoryMetaBox.get(productId));
    final currentStock = _asDouble(currentMeta['stock']);
    final stock = existing == null || replaceStock || !currentMeta.containsKey('stock') ? openingStock : currentStock;

    final product = SalesModel(
      id: productId,
      productName: name.trim(),
      amount: sellingPrice,
      date: existing?.date ?? DateTime.now(),
      customerName: existing?.customerName ?? '',
      orderIds: existing?.orderIds,
      paidAmount: existing?.paidAmount,
      dueAmount: existing?.dueAmount,
      status: existing?.status ?? 'active',
    );

    await productsBox.put(productId, product);
    await inventoryMetaBox.put(productId, {
      'sku': sku.trim(),
      'barcode': barcode.trim(),
      'hsn': hsn.trim(),
      'unit': unit.trim().isEmpty ? 'PCS' : unit.trim().toUpperCase(),
      'stock': stock,
      'purchasePrice': purchasePrice,
      'gstPercent': gstPercent,
      'lowStock': lowStock,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _audit(id == null ? 'PRODUCT_CREATED' : 'PRODUCT_UPDATED', 'Product: ${name.trim()}');
    return productId;
  }

  Future<void> adjustStock(String productId, double delta, String note) async {
    final meta = _readMap(inventoryMetaBox.get(productId));
    final stock = _asDouble(meta['stock']) + delta;
    meta['stock'] = stock < 0 ? 0.0 : stock;
    meta['updatedAt'] = DateTime.now().toIso8601String();
    await inventoryMetaBox.put(productId, meta);
    await _audit('STOCK_ADJUSTED', '$productId: ${delta.toStringAsFixed(2)} ${note.trim()}');
  }

  Future<void> deleteProduct(String productId) async {
    final product = productsBox.get(productId);
    await productsBox.delete(productId);
    await inventoryMetaBox.delete(productId);
    await _audit('PRODUCT_DELETED', product?.productName ?? productId);
  }

  Future<String> saveCustomer({
    String? id,
    required String name,
    String phone = '',
    String email = '',
    String gstin = '',
    String address = '',
    String stateCode = '',
  }) async {
    final customerId = id ?? _uuid.v4();
    await customersBox.put(customerId, {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'gstin': gstin.trim().toUpperCase(),
      'address': address.trim(),
      'stateCode': stateCode.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _audit(id == null ? 'CUSTOMER_CREATED' : 'CUSTOMER_UPDATED', 'Customer: ${name.trim()}');
    return customerId;
  }

  Future<void> deleteCustomer(String id) async {
    final customer = PosCustomer(id: id, data: _readMap(customersBox.get(id)));
    await customersBox.delete(id);
    await _audit('CUSTOMER_DELETED', customer.name);
  }

  Future<CheckoutResult> checkout({
    required List<CartLine> lines,
    required String customerName,
    String customerId = '',
    String customerGstin = '',
    String placeOfSupply = '',
    required double paidAmount,
    String paymentMode = 'Cash',
    double discountAmount = 0,
  }) async {
    if (lines.isEmpty) {
      throw StateError('Cart is empty');
    }

    final DateTime now = DateTime.now();
    final billId = invoiceNumberFor(now);
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineSubtotal);
    final gstTotal = lines.fold<double>(0, (sum, line) => sum + line.gstAmount);
    final safeDiscount = discountAmount.clamp(0, subtotal + gstTotal).toDouble();
    final grandTotal = (subtotal + gstTotal - safeDiscount).clamp(0, double.infinity).toDouble();
    final safePaid = paidAmount.clamp(0, grandTotal).toDouble();
    final due = grandTotal - safePaid;
    final cleanCustomerName = customerName.trim().isEmpty ? 'Walk-in Customer' : customerName.trim();

    for (final line in lines) {
      final product = productsBox.get(line.productId);
      if (product == null) {
        throw StateError('${line.productName} is no longer available in inventory');
      }
      final meta = _readMap(inventoryMetaBox.get(line.productId));
      final currentStock = _asDouble(meta['stock']);
      if (currentStock < line.quantity) {
        throw StateError('${product.productName} has only ${currentStock.toStringAsFixed(2)} stock');
      }
    }

    final orderIds = <String>[];
    for (final line in lines) {
      final product = productsBox.get(line.productId);
      if (product == null) continue;
      final meta = _readMap(inventoryMetaBox.get(line.productId));
      final itemSubtotal = line.lineSubtotal;
      final itemGst = line.gstAmount;
      final ratioBase = subtotal + gstTotal;
      final ratio = ratioBase <= 0 ? 0 : ((itemSubtotal + itemGst) / ratioBase);
      final itemDiscount = safeDiscount * ratio;
      final itemTotalAfterDiscount = (itemSubtotal + itemGst - itemDiscount).clamp(0, double.infinity).toDouble();
      final itemPaid = safePaid * ratio;
      final itemDue = itemTotalAfterDiscount - itemPaid;
      final orderId = _uuid.v4();
      orderIds.add(orderId);

      final order = OrderModel(
        id: orderId,
        salesId: product.id,
        productName: product.productName,
        quantity: line.quantity,
        customerName: cleanCustomerName,
        totalAmount: itemSubtotal,
        paidAmount: itemPaid,
        dueAmount: itemDue < 0 ? 0 : itemDue,
        date: now,
        isGstEnabled: line.gstPercent > 0,
        gstPercent: line.gstPercent,
      );
      await ordersBox.put(orderId, order);

      meta['stock'] = (_asDouble(meta['stock']) - line.quantity).clamp(0, double.infinity).toDouble();
      meta['updatedAt'] = now.toIso8601String();
      await inventoryMetaBox.put(product.id, meta);
    }

    final invoiceLines = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      invoiceLines.add({
        'orderId': i < orderIds.length ? orderIds[i] : '',
        'productId': line.productId,
        'productName': line.productName,
        'hsn': line.hsn,
        'quantity': line.quantity,
        'unitPrice': line.unitPrice,
        'gstPercent': line.gstPercent,
      });
    }

    final invoice = InvoiceModel(
      id: billId,
      orderId: orderIds.isNotEmpty ? orderIds.first : billId,
      orderIds: orderIds,
      saleId: lines.first.productId,
      customerId: customerId,
      customerName: cleanCustomerName,
      amount: subtotal,
      productName: lines.length == 1 ? lines.first.productName : '${lines.length} products',
      quantity: lines.fold<double>(0, (sum, line) => sum + line.quantity),
      unitPrice: lines.length == 1 ? lines.first.unitPrice : 0,
      paidAmount: safePaid,
      dueAmount: due < 0 ? 0 : due,
      date: now,
      isGstEnabled: gstTotal > 0,
      gstPercent: lines.map((line) => line.gstPercent).toSet().length == 1 ? lines.first.gstPercent : 0,
      buyerGstin: customerGstin.trim().isEmpty ? null : customerGstin.trim().toUpperCase(),
      placeOfSupply: placeOfSupply.trim().isEmpty ? null : placeOfSupply.trim(),
      hsnCode: lines.length == 1 ? lines.first.hsn : null,
      lineItems: invoiceLines,
      discountAmount: safeDiscount,
      paymentMode: paymentMode,
    );
    invoice.calculateTax(settingsBox.get('companyStateCode', defaultValue: '24').toString());
    await invoicesBox.put(billId, invoice);

    if (safePaid > 0) {
      await transactionsBox.put(billId, TransactionModel(
        id: billId,
        title: 'POS Bill $billId - $cleanCustomerName',
        amount: safePaid,
        type: 'income',
        date: now,
        orderId: orderIds.isNotEmpty ? orderIds.first : null,
        salesId: lines.first.productId,
      ));
    }

    await auditBox.put(billId, {
      'action': 'POS_CHECKOUT',
      'details': jsonEncode({
        'billId': billId,
        'customerId': customerId,
        'customerName': cleanCustomerName,
        'paymentMode': paymentMode,
        'subtotal': subtotal,
        'gstTotal': gstTotal,
        'discountAmount': safeDiscount,
        'grandTotal': grandTotal,
        'paidAmount': safePaid,
        'due': due,
        'orderIds': orderIds,
        'lines': lines.map((e) => e.toJson()).toList(),
      }),
      'date': now.toIso8601String(),
    });

    return CheckoutResult(
      billId: billId,
      orderIds: orderIds,
      subtotal: subtotal,
      gstTotal: gstTotal,
      discountAmount: safeDiscount,
      grandTotal: grandTotal,
      paidAmount: safePaid,
      dueAmount: due,
    );
  }

  Future<void> updateOrderPayment(OrderModel order, double newPaidAmount) async {
    final safePaid = newPaidAmount.clamp(0.0, order.grandTotal).toDouble();
    order.paidAmount = safePaid;
    final orderDue = order.grandTotal - safePaid;
    order.dueAmount = orderDue < 0 ? 0.0 : orderDue;
    await ordersBox.put(order.id, order);

    final linkedInvoices = invoicesBox.values.where((invoice) {
      return invoice.orderId == order.id || invoice.orderIds.contains(order.id);
    }).toList();

    for (final invoice in linkedInvoices) {
      await _syncInvoiceFromOrders(invoice);
      await _updateInvoiceTransaction(invoice);
    }

    await _audit('PAYMENT_UPDATED', '${order.customerName} • ${order.productName} • Paid ₹${safePaid.toStringAsFixed(2)}');
  }

  Future<void> voidOrder(OrderModel order, {String reason = 'Void sale'}) async {
    final productId = order.salesId;
    if (productId != null && productId.isNotEmpty) {
      await adjustStock(productId, order.quantity, 'Return/Void: $reason');
    }

    final linkedInvoices = invoicesBox.values
        .where((invoice) => invoice.orderId == order.id || invoice.orderIds.contains(order.id))
        .toList();

    var returnRecorded = false;
    for (final invoice in linkedInvoices) {
      if (!returnRecorded) {
        await _recordReturnFromOrder(order, invoice: invoice, reason: reason, source: 'order');
        returnRecorded = true;
      }
      final remainingOrderIds = invoice.orderIds.where((id) => id != order.id).toList();

      if (remainingOrderIds.isEmpty || invoice.orderIds.length <= 1) {
        await transactionsBox.delete(invoice.id);
        await invoicesBox.delete(invoice.id);
      } else {
        final removedLine = invoice.items.firstWhere(
          (line) => line.orderId == order.id,
          orElse: () => InvoiceLineItem(
            orderId: order.id,
            productId: productId ?? '',
            productName: order.productName,
            hsn: '',
            quantity: order.quantity,
            unitPrice: order.quantity == 0 ? 0 : order.totalAmount / order.quantity,
            gstPercent: order.gstPercent,
          ),
        );
        final invoiceBase = invoice.subtotal + invoice.gstAmount;
        final removedBase = removedLine.taxableValue + removedLine.gstAmount;
        final discountShare = invoiceBase <= 0 ? 0.0 : invoice.discountAmount * (removedBase / invoiceBase);

        invoice.orderIds = remainingOrderIds;
        invoice.orderId = remainingOrderIds.first;
        invoice.lineItems = invoice.lineItems.where((line) => line['orderId']?.toString() != order.id).toList();
        invoice.discountAmount = (invoice.discountAmount - discountShare).clamp(0.0, double.infinity).toDouble();
        invoice.amount = invoice.subtotal;
        invoice.quantity = invoice.totalQuantity;
        invoice.productName = invoice.items.length == 1 ? invoice.items.first.productName : '${invoice.items.length} products';
        invoice.unitPrice = invoice.items.length == 1 ? invoice.items.first.unitPrice : 0.0;
        await _syncInvoiceFromOrders(invoice);
        await _updateInvoiceTransaction(invoice);
      }
    }

    if (!returnRecorded) {
      await _recordReturnFromOrder(order, reason: reason, source: 'order');
    }

    await ordersBox.delete(order.id);
    final linkedTransactions = transactionsBox.values.where((t) => t.orderId == order.id).toList();
    for (final t in linkedTransactions) {
      await t.delete();
    }
    await _audit('ORDER_VOIDED', '${order.productName} - ${order.customerName} - $reason');
  }

  Future<void> voidInvoice(InvoiceModel invoice, {String reason = 'Invoice deleted'}) async {
    final items = invoice.items;
    for (final item in items) {
      await _recordReturnFromInvoiceLine(invoice, item, reason: reason, source: 'invoice');
      if (item.productId.isNotEmpty && item.quantity > 0) {
        await adjustStock(item.productId, item.quantity, 'Invoice void: $reason');
      }
    }

    for (final orderId in invoice.orderIds) {
      await ordersBox.delete(orderId);
    }

    await transactionsBox.delete(invoice.id);
    final linkedTransactions = transactionsBox.values.where((t) => invoice.orderIds.contains(t.orderId)).toList();
    for (final t in linkedTransactions) {
      await t.delete();
    }
    await invoicesBox.delete(invoice.id);
    await _audit('INVOICE_VOIDED', '${invoice.id} • ${invoice.customerName} • $reason');
  }

  Future<void> cancelPaymentTransaction(TransactionModel transaction) async {
    final invoice = invoicesBox.get(transaction.id);
    if (invoice != null) {
      for (final orderId in invoice.orderIds) {
        final order = ordersBox.get(orderId);
        if (order == null) continue;
        order.paidAmount = 0.0;
        order.dueAmount = order.grandTotal;
        await ordersBox.put(order.id, order);
      }
      invoice.paidAmount = 0.0;
      invoice.dueAmount = invoice.grandTotal;
      await invoicesBox.put(invoice.id, invoice);
    } else if (transaction.orderId != null) {
      final order = ordersBox.get(transaction.orderId);
      if (order != null) {
        order.paidAmount = 0.0;
        order.dueAmount = order.grandTotal;
        await ordersBox.put(order.id, order);
      }
    }

    if (transactionsBox.containsKey(transaction.id)) {
      await transactionsBox.delete(transaction.id);
    } else {
      await transaction.delete();
    }
    await _audit('PAYMENT_CANCELLED', transaction.title);
  }

  Future<void> _recordReturnFromOrder(
    OrderModel order, {
    InvoiceModel? invoice,
    required String reason,
    required String source,
  }) async {
    final productId = order.salesId ?? invoice?.saleId ?? '';
    final productMeta = productId.isEmpty ? <String, dynamic>{} : _readMap(inventoryMetaBox.get(productId));
    final totalAfterDiscount = (order.paid + order.due) > 0 ? (order.paid + order.due) : order.grandTotal;
    final now = DateTime.now();
    final returnId = returnNumberFor(now);

    await returnsBox.put(returnId, {
      'id': returnId,
      'date': now.toIso8601String(),
      'originalDate': order.date.toIso8601String(),
      'invoiceId': invoice?.id ?? '',
      'orderId': order.id,
      'customerId': invoice?.customerId ?? '',
      'customerName': order.customerName,
      'productId': productId,
      'productName': order.productName,
      'hsn': productMeta['hsn']?.toString() ?? invoice?.hsnCode ?? '',
      'quantity': order.quantity,
      'unitPrice': order.quantity <= 0 ? 0.0 : order.totalAmount / order.quantity,
      'taxableValue': order.totalAmount,
      'gstPercent': order.gstPercent,
      'gstAmount': order.gstAmount,
      'returnAmount': totalAfterDiscount,
      'refundAmount': order.paid,
      'paymentMode': invoice?.paymentMode ?? '',
      'reason': reason.trim().isEmpty ? 'Customer return' : reason.trim(),
      'source': source,
      'stockReturned': order.quantity,
      'createdAt': now.toIso8601String(),
    });

    await _audit('RETURN_RECORDED', '$returnId • ${order.productName} • ${order.customerName}');
  }

  Future<void> _recordReturnFromInvoiceLine(
    InvoiceModel invoice,
    InvoiceLineItem item, {
    required String reason,
    required String source,
  }) async {
    final order = item.orderId.isEmpty ? null : ordersBox.get(item.orderId);
    if (order != null) {
      await _recordReturnFromOrder(order, invoice: invoice, reason: reason, source: source);
      return;
    }

    final base = invoice.items.fold<double>(0.0, (sum, line) => sum + line.lineTotal);
    final ratio = base <= 0 ? 0.0 : item.lineTotal / base;
    final discountShare = invoice.discountAmount * ratio;
    final paymentShare = invoice.paid * ratio;
    final totalAfterDiscount = (item.lineTotal - discountShare).clamp(0.0, double.infinity).toDouble();
    final now = DateTime.now();
    final returnId = returnNumberFor(now);

    await returnsBox.put(returnId, {
      'id': returnId,
      'date': now.toIso8601String(),
      'originalDate': invoice.date.toIso8601String(),
      'invoiceId': invoice.id,
      'orderId': item.orderId,
      'customerId': invoice.customerId ?? '',
      'customerName': invoice.customerName,
      'productId': item.productId,
      'productName': item.productName,
      'hsn': item.hsn,
      'quantity': item.quantity,
      'unitPrice': item.unitPrice,
      'taxableValue': item.taxableValue,
      'gstPercent': item.gstPercent,
      'gstAmount': item.gstAmount,
      'returnAmount': totalAfterDiscount,
      'refundAmount': paymentShare.clamp(0.0, totalAfterDiscount).toDouble(),
      'paymentMode': invoice.paymentMode,
      'reason': reason.trim().isEmpty ? 'Invoice return' : reason.trim(),
      'source': source,
      'stockReturned': item.quantity,
      'createdAt': now.toIso8601String(),
    });

    await _audit('RETURN_RECORDED', '$returnId • ${item.productName} • ${invoice.customerName}');
  }

  Future<void> addExpense(
    String title,
    double amount, {
    String category = ExpenseModel.categoryOther,
    String productId = '',
    double refillQuantity = 0,
    double unitPurchasePrice = 0,
    bool updateSellingPrice = false,
    double newSellingPrice = 0,
    String note = '',
  }) async {
    final cleanCategory = category.trim().isEmpty ? ExpenseModel.categoryOther : category.trim();
    final cleanProductId = productId.trim();
    final now = DateTime.now();
    String productName = '';
    String unit = '';
    String cleanTitle = title.trim();
    String batchNumber = '';
    var finalAmount = amount;
    var finalUnitPurchasePrice = unitPurchasePrice;
    var finalSellingPrice = newSellingPrice;
    var finalUpdateSellingPrice = updateSellingPrice;

    if (cleanCategory == ExpenseModel.categoryInventoryRefill) {
      if (cleanProductId.isEmpty) {
        throw StateError('Select a product for inventory refill');
      }
      if (refillQuantity <= 0) {
        throw StateError('Refill quantity must be greater than zero');
      }
      if (finalUnitPurchasePrice <= 0) {
        throw StateError('Per-quantity refill price must be greater than zero');
      }
      final product = products().where((p) => p.id == cleanProductId).toList();
      if (product.isEmpty) {
        throw StateError('Selected product was not found');
      }
      productName = product.first.name;
      unit = product.first.unit;
      cleanTitle = cleanTitle.isEmpty ? 'Inventory Refill - $productName' : cleanTitle;
      finalAmount = refillQuantity * finalUnitPurchasePrice;
      if (finalUpdateSellingPrice && finalSellingPrice <= 0) {
        throw StateError('Enter a valid POS selling price or turn off the POS price toggle');
      }
      if (!finalUpdateSellingPrice) {
        finalSellingPrice = 0;
      }
      batchNumber = await _reserveNextRefillBatchNumber(now);
    } else {
      cleanTitle = cleanTitle.isEmpty ? cleanCategory : cleanTitle;
      finalUnitPurchasePrice = 0;
      finalUpdateSellingPrice = false;
      finalSellingPrice = 0;
    }

    final expense = ExpenseModel(
      title: cleanTitle,
      amount: finalAmount,
      date: now,
      category: cleanCategory,
      productId: cleanProductId,
      productName: productName,
      refillQuantity: cleanCategory == ExpenseModel.categoryInventoryRefill ? refillQuantity : 0,
      unit: unit,
      note: note.trim(),
      batchNumber: batchNumber,
      unitPurchasePrice: cleanCategory == ExpenseModel.categoryInventoryRefill ? finalUnitPurchasePrice : 0,
      posPriceUpdated: cleanCategory == ExpenseModel.categoryInventoryRefill && finalUpdateSellingPrice,
      sellingPriceAfterRefill: cleanCategory == ExpenseModel.categoryInventoryRefill ? finalSellingPrice : 0,
    );
    final key = await expensesBox.add(expense);

    if (expense.isInventoryRefill) {
      await adjustStock(cleanProductId, refillQuantity, 'Inventory refill expense: $cleanTitle');
      await _applyRefillPricing(
        productId: cleanProductId,
        unitPurchasePrice: finalUnitPurchasePrice,
        updateSellingPrice: finalUpdateSellingPrice,
        newSellingPrice: finalSellingPrice,
      );
    }

    await transactionsBox.put('expense_$key', TransactionModel(
      id: 'expense_$key',
      title: expense.isInventoryRefill ? '${expense.safeCategory}: ${expense.safeBatchNumber} • ${expense.displayTitle}' : '${expense.safeCategory}: ${expense.displayTitle}',
      amount: finalAmount,
      type: 'expense',
      date: expense.date,
      salesId: expense.isInventoryRefill ? cleanProductId : null,
    ));
    await _audit('EXPENSE_CREATED', '${expense.safeCategory} • ${expense.safeBatchNumber} • ${expense.displayTitle} • ₹${finalAmount.toStringAsFixed(2)}');
  }

  Future<void> _applyRefillPricing({
    required String productId,
    required double unitPurchasePrice,
    required bool updateSellingPrice,
    required double newSellingPrice,
  }) async {
    final meta = _readMap(inventoryMetaBox.get(productId));
    if (unitPurchasePrice > 0) {
      meta['purchasePrice'] = unitPurchasePrice;
      meta['lastRefillUnitPrice'] = unitPurchasePrice;
      meta['lastRefillAt'] = DateTime.now().toIso8601String();
      await inventoryMetaBox.put(productId, meta);
    }

    if (!updateSellingPrice || newSellingPrice <= 0) return;

    final product = productsBox.get(productId);
    if (product == null) return;
    final updatedProduct = SalesModel(
      id: product.id,
      productName: product.productName,
      amount: newSellingPrice,
      date: product.date,
      customerName: product.customerName,
      orderIds: product.orderIds,
      paidAmount: product.paidAmount,
      dueAmount: product.dueAmount,
      status: product.status,
    );
    await productsBox.put(productId, updatedProduct);
    await _audit('POS_PRICE_UPDATED_FROM_REFILL', '${product.productName} • ₹${newSellingPrice.toStringAsFixed(2)}');
  }

  Future<void> deleteExpense(ExpenseModel expense) async {
    final key = expense.key;
    if (expense.isInventoryRefill && expense.productId.isNotEmpty && expense.refillQuantity > 0) {
      await adjustStock(expense.productId, -expense.refillQuantity, 'Deleted inventory refill expense: ${expense.displayTitle}');
    }
    await expense.delete();
    if (key != null) {
      await transactionsBox.delete('expense_$key');
    }
    await _audit('EXPENSE_DELETED', '${expense.safeCategory} • ${expense.displayTitle}');
  }

  double receivableForCustomer(String customerName, {String? customerId}) {
    final normalizedName = customerName.trim().toLowerCase();
    return invoicesBox.values.where((invoice) {
      final sameId = customerId != null && customerId.isNotEmpty && invoice.customerId == customerId;
      final sameName = invoice.customerName.trim().toLowerCase() == normalizedName;
      return sameId || sameName;
    }).fold<double>(0, (sum, invoice) => sum + invoice.due);
  }

  Map<String, double> dashboardTotals() {
    final invoices = invoicesBox.values.toList();
    final orders = ordersBox.values.toList();
    final paid = invoices.isNotEmpty
        ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.paid)
        : orders.fold<double>(0, (sum, order) => sum + order.paid);
    final due = invoices.isNotEmpty
        ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.due)
        : orders.fold<double>(0, (sum, order) => sum + order.due);
    final subtotal = invoices.isNotEmpty
        ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.subtotal)
        : orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
    final gst = invoices.isNotEmpty
        ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.gstAmount)
        : orders.fold<double>(0, (sum, order) => sum + order.gstAmount);
    final grandSales = invoices.isNotEmpty
        ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.grandTotal)
        : subtotal + gst;
    final expenseRows = expensesBox.values.toList();
    final expense = expenseRows.fold<double>(0, (sum, e) => sum + e.amount);
    final inventoryRefillExpense = expenseRows
        .where((e) => e.isInventoryRefill)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final salaryExpense = expenseRows
        .where((e) => e.isSalary)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final otherExpense = expenseRows
        .where((e) => e.isOther)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final stockValue = products().fold<double>(0, (sum, p) => sum + (p.stock * p.purchasePrice));
    final salesAtMrp = products().fold<double>(0, (sum, p) => sum + (p.stock * p.price));
    final returns = returnRecords();
    final returnedValue = returns.fold<double>(0, (sum, r) => sum + r.returnAmount);
    final refunded = returns.fold<double>(0, (sum, r) => sum + r.refundAmount);
    return {
      'subtotal': subtotal,
      'gst': gst,
      'grossSales': grandSales,
      'paid': paid,
      'due': due,
      'expense': expense,
      'inventoryRefillExpense': inventoryRefillExpense,
      'salaryExpense': salaryExpense,
      'otherExpense': otherExpense,
      'netCash': paid - expense,
      'stockValue': stockValue,
      'salesStockValue': salesAtMrp,
      'products': productsBox.length.toDouble(),
      'orders': ordersBox.length.toDouble(),
      'invoices': invoicesBox.length.toDouble(),
      'customers': customersBox.length.toDouble(),
      'lowStock': products().where((p) => p.stock <= p.lowStock).length.toDouble(),
      'returns': returns.length.toDouble(),
      'returnedValue': returnedValue,
      'refunded': refunded,
    };
  }

  String exportCsv(String type) {
    final buffer = StringBuffer();
    if (type == 'inventory') {
      buffer.writeln('Product,SKU,Barcode,HSN,Unit,Stock,Low Stock,Purchase Price,Selling Price,GST %');
      for (final p in products()) {
        buffer.writeln(_csv([
          p.name, p.sku, p.barcode, p.hsn, p.unit, p.stock, p.lowStock, p.purchasePrice, p.price, p.gstPercent,
        ]));
      }
    } else if (type == 'customers') {
      buffer.writeln('Name,Phone,Email,GSTIN,State Code,Address,Receivable');
      for (final c in customers()) {
        buffer.writeln(_csv([c.name, c.phone, c.email, c.gstin, c.stateCode, c.address, receivableForCustomer(c.name, customerId: c.id)]));
      }
    } else if (type == 'gstr1') {
      buffer.writeln('Invoice ID,Date,Customer,GSTIN,Type,Product,HSN,Qty,Taxable Value,GST %,IGST,CGST,SGST,Line Total,Invoice Total');
      for (final inv in invoicesBox.values) {
        for (final item in inv.items) {
          final lineTax = item.gstAmount;
          final isInterState = inv.igst > 0;
          buffer.writeln(_csv([
            inv.id,
            inv.date.toIso8601String(),
            inv.customerName,
            inv.buyerGstin ?? '',
            inv.invoiceType,
            item.productName,
            item.hsn,
            item.quantity,
            item.taxableValue,
            item.gstPercent,
            isInterState ? lineTax : 0.0,
            isInterState ? 0.0 : lineTax / 2,
            isInterState ? 0.0 : lineTax / 2,
            item.lineTotal,
            inv.grandTotal,
          ]));
        }
      }
    } else if (type == 'returns') {
      buffer.writeln('Return ID,Return Date,Original Date,Invoice ID,Order ID,Customer,Product,HSN,Qty,Taxable Value,GST %,GST Amount,Return Amount,Refund Amount,Payment Mode,Reason,Source');
      for (final r in returnRecords()) {
        buffer.writeln(_csv([
          r.id, r.date.toIso8601String(), r.originalDate?.toIso8601String() ?? '', r.invoiceId, r.orderId, r.customerName, r.productName, r.hsn, r.quantity, r.taxableValue, r.gstPercent, r.gstAmount, r.returnAmount, r.refundAmount, r.paymentMode, r.reason, r.source,
        ]));
      }
    } else if (type == 'expenses') {
      buffer.writeln('Date,Category,Batch Number,Title,Product,Refill Qty,Unit,Unit Purchase Price,Total Amount,POS Price Updated,New POS Price,Note');
      for (final e in expensesBox.values) {
        buffer.writeln(_csv([e.date.toIso8601String(), e.safeCategory, e.safeBatchNumber, e.displayTitle, e.productName, e.refillQuantity, e.unit, e.safeUnitPurchasePrice, e.amount, e.posPriceUpdated ? 'Yes' : 'No', e.sellingPriceAfterRefill, e.note]));
      }
    } else if (type == 'inventory_refill') {
      buffer.writeln('Date,Batch Number,Product,Refill Qty,Unit,Unit Purchase Price,Total Amount,POS Price Updated,New POS Price,Note');
      for (final e in expensesBox.values.where((expense) => expense.isInventoryRefill)) {
        buffer.writeln(_csv([e.date.toIso8601String(), e.safeBatchNumber, e.productName, e.refillQuantity, e.unit, e.safeUnitPurchasePrice, e.amount, e.posPriceUpdated ? 'Yes' : 'No', e.sellingPriceAfterRefill, e.note]));
      }
    } else {
      buffer.writeln('Date,Customer,Product,Qty,Subtotal,GST,Grand Total,Paid,Due');
      for (final o in ordersBox.values) {
        buffer.writeln(_csv([
          o.date.toIso8601String(),
          o.customerName,
          o.productName,
          o.quantity,
          o.totalAmount,
          o.gstAmount,
          o.grandTotal,
          o.paid,
          o.due,
        ]));
      }
    }
    return buffer.toString();
  }

  String backupJson() {
    final data = {
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'products': products().map((p) => p.toJson()).toList(),
      'customers': customers().map((c) => c.toJson()).toList(),
      'invoices': invoicesBox.values.map((invoice) => invoice.toJson()).toList(),
      'orders': ordersBox.values.map((o) => {
        'id': o.id,
        'salesId': o.salesId,
        'productName': o.productName,
        'quantity': o.quantity,
        'customerName': o.customerName,
        'totalAmount': o.totalAmount,
        'paidAmount': o.paidAmount,
        'dueAmount': o.dueAmount,
        'date': o.date.toIso8601String(),
        'isGstEnabled': o.isGstEnabled,
        'gstPercent': o.gstPercent,
      }).toList(),
      'returns': returnRecords().map((r) => r.toJson()).toList(),
      'expenses': expensesBox.values.map((expense) => expense.toJson()).toList(),
      'transactions': transactionsBox.values.map((t) => {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'type': t.type,
        'date': t.date.toIso8601String(),
        'orderId': t.orderId,
        'salesId': t.salesId,
      }).toList(),
      'settings': Map<String, dynamic>.from(settingsBox.toMap().map((key, value) => MapEntry(key.toString(), _safeValue(value)))),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> seedIfEmpty() async {
    if (productsBox.isNotEmpty) return;
    final riceId = await saveProduct(
      name: 'Premium Rice 25kg',
      sellingPrice: 1450,
      openingStock: 30,
      sku: 'RICE-25',
      barcode: '890000001',
      hsn: '1006',
      unit: 'BAG',
      purchasePrice: 1180,
      gstPercent: 5,
      lowStock: 5,
    );
    await saveProduct(
      name: 'Groundnut Oil 15L',
      sellingPrice: 2350,
      openingStock: 16,
      sku: 'OIL-15',
      barcode: '890000002',
      hsn: '1516',
      unit: 'TIN',
      purchasePrice: 2100,
      gstPercent: 5,
      lowStock: 4,
    );
    await saveCustomer(name: 'Walk-in Customer', phone: '', email: '', gstin: '', address: 'Counter sale');
    await saveCustomer(name: 'B2B Demo Customer', phone: '9999999999', gstin: '24ABCDE1234F1Z5', stateCode: '24', address: 'Ahmedabad, Gujarat');
    await adjustStock(riceId, 0, 'Initial industrial POS seed');
  }

  Future<void> _syncInvoiceFromOrders(InvoiceModel invoice) async {
    final linkedOrders = invoice.orderIds.map((id) => ordersBox.get(id)).whereType<OrderModel>().toList();
    if (linkedOrders.isNotEmpty) {
      invoice.paidAmount = linkedOrders.fold<double>(0.0, (sum, order) => sum + order.paid).clamp(0.0, invoice.grandTotal).toDouble();
      final invoiceDue = invoice.grandTotal - invoice.paid;
      invoice.dueAmount = invoiceDue < 0 ? 0.0 : invoiceDue;
    } else {
      final invoiceDue = invoice.grandTotal - invoice.paid;
      invoice.dueAmount = invoiceDue < 0 ? 0.0 : invoiceDue;
    }
    invoice.amount = invoice.subtotal;
    invoice.quantity = invoice.totalQuantity;
    invoice.productName = invoice.items.length == 1 ? invoice.items.first.productName : '${invoice.items.length} products';
    invoice.calculateTax(settingsBox.get('companyStateCode', defaultValue: '24').toString());
    await invoicesBox.put(invoice.id, invoice);
  }

  Future<void> _updateInvoiceTransaction(InvoiceModel invoice) async {
    if (invoice.paid <= 0) {
      await transactionsBox.delete(invoice.id);
      return;
    }
    await transactionsBox.put(invoice.id, TransactionModel(
      id: invoice.id,
      title: 'POS Bill ${invoice.id} - ${invoice.customerName}',
      amount: invoice.paid,
      type: 'income',
      date: invoice.date,
      orderId: invoice.orderId,
      salesId: invoice.saleId,
    ));
  }

  Future<void> _audit(String action, String details) async {
    await auditBox.add({
      'action': action,
      'details': details,
      'date': DateTime.now().toIso8601String(),
    });
  }

  static Map<String, dynamic> _readMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _invoiceDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year.toString().padLeft(4, '0')}'
        '${normalized.month.toString().padLeft(2, '0')}'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  static int _sequenceFromInvoiceNumber(String invoiceNumber, RegExp pattern) {
    final match = pattern.firstMatch(invoiceNumber.trim().toUpperCase());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static Object? _safeValue(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) return Map<String, dynamic>.from(value.map((key, val) => MapEntry(key.toString(), _safeValue(val))));
    if (value is Iterable) return value.map(_safeValue).toList();
    if (value is num || value is String || value is bool || value == null) return value;
    return value.toString();
  }

  static String _csv(List<Object?> values) {
    return values.map((value) {
      final text = value?.toString() ?? '';
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }).join(',');
  }
}

class ReturnOrderRecord {
  final String id;
  final DateTime date;
  final DateTime? originalDate;
  final String invoiceId;
  final String orderId;
  final String customerId;
  final String customerName;
  final String productId;
  final String productName;
  final String hsn;
  final double quantity;
  final double unitPrice;
  final double taxableValue;
  final double gstPercent;
  final double gstAmount;
  final double returnAmount;
  final double refundAmount;
  final String paymentMode;
  final String reason;
  final String source;
  final double stockReturned;

  ReturnOrderRecord({
    required this.id,
    required this.date,
    this.originalDate,
    required this.invoiceId,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.hsn,
    required this.quantity,
    required this.unitPrice,
    required this.taxableValue,
    required this.gstPercent,
    required this.gstAmount,
    required this.returnAmount,
    required this.refundAmount,
    required this.paymentMode,
    required this.reason,
    required this.source,
    required this.stockReturned,
  });

  factory ReturnOrderRecord.fromMap(Map<String, dynamic> map) {
    return ReturnOrderRecord(
      id: map['id']?.toString() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      originalDate: DateTime.tryParse(map['originalDate']?.toString() ?? ''),
      invoiceId: map['invoiceId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? 'Customer',
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'Product',
      hsn: map['hsn']?.toString() ?? '',
      quantity: PosRepository._asDouble(map['quantity']),
      unitPrice: PosRepository._asDouble(map['unitPrice']),
      taxableValue: PosRepository._asDouble(map['taxableValue']),
      gstPercent: PosRepository._asDouble(map['gstPercent']),
      gstAmount: PosRepository._asDouble(map['gstAmount']),
      returnAmount: PosRepository._asDouble(map['returnAmount']),
      refundAmount: PosRepository._asDouble(map['refundAmount']),
      paymentMode: map['paymentMode']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      stockReturned: PosRepository._asDouble(map['stockReturned']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'originalDate': originalDate?.toIso8601String(),
        'invoiceId': invoiceId,
        'orderId': orderId,
        'customerId': customerId,
        'customerName': customerName,
        'productId': productId,
        'productName': productName,
        'hsn': hsn,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'taxableValue': taxableValue,
        'gstPercent': gstPercent,
        'gstAmount': gstAmount,
        'returnAmount': returnAmount,
        'refundAmount': refundAmount,
        'paymentMode': paymentMode,
        'reason': reason,
        'source': source,
        'stockReturned': stockReturned,
      };
}

class PosProduct {
  final SalesModel product;
  final Map<String, dynamic> meta;

  PosProduct({required this.product, required this.meta});

  String get id => product.id;
  String get name => product.productName;
  double get price => product.amount;
  String get sku => meta['sku']?.toString() ?? '';
  String get barcode => meta['barcode']?.toString() ?? '';
  String get hsn => meta['hsn']?.toString() ?? '';
  String get unit => meta['unit']?.toString() ?? 'PCS';
  double get stock => PosRepository._asDouble(meta['stock']);
  double get purchasePrice => PosRepository._asDouble(meta['purchasePrice']);
  double get gstPercent => PosRepository._asDouble(meta['gstPercent']);
  double get lowStock => PosRepository._asDouble(meta['lowStock']);
  bool get isLowStock => stock <= lowStock;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'sku': sku,
        'barcode': barcode,
        'hsn': hsn,
        'unit': unit,
        'stock': stock,
        'purchasePrice': purchasePrice,
        'gstPercent': gstPercent,
        'lowStock': lowStock,
      };
}

class PosCustomer {
  final String id;
  final Map<String, dynamic> data;

  PosCustomer({required this.id, required this.data});

  String get name => data['name']?.toString() ?? 'Customer';
  String get phone => data['phone']?.toString() ?? '';
  String get email => data['email']?.toString() ?? '';
  String get gstin => data['gstin']?.toString() ?? '';
  String get address => data['address']?.toString() ?? '';
  String get stateCode => data['stateCode']?.toString() ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'address': address,
        'stateCode': stateCode,
      };
}

class CartLine {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double gstPercent;
  final String hsn;

  CartLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.gstPercent,
    required this.hsn,
  });

  double get lineSubtotal => quantity * unitPrice;
  double get gstAmount => lineSubtotal * gstPercent / 100;
  double get lineTotal => lineSubtotal + gstAmount;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'gstPercent': gstPercent,
        'hsn': hsn,
        'lineSubtotal': lineSubtotal,
        'gstAmount': gstAmount,
        'lineTotal': lineTotal,
      };
}

class CheckoutResult {
  final String billId;
  final List<String> orderIds;
  final double subtotal;
  final double gstTotal;
  final double discountAmount;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;

  CheckoutResult({
    required this.billId,
    required this.orderIds,
    required this.subtotal,
    required this.gstTotal,
    required this.discountAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
  });
}
