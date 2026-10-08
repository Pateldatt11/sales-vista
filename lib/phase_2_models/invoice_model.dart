import 'dart:typed_data';

import 'package:hive/hive.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 6)
class InvoiceModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String saleId;

  @HiveField(2)
  String customerName;

  /// Taxable subtotal before GST and discount.
  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  double? paidAmount;

  @HiveField(6)
  double? dueAmount;

  /// Legacy single-product invoice field. New invoices use [lineItems].
  @HiveField(7)
  String? productName;

  /// Legacy single-product quantity field. New invoices use [lineItems].
  @HiveField(8)
  double quantity;

  /// Legacy single-product unit price field. New invoices use [lineItems].
  @HiveField(9)
  double unitPrice;

  @HiveField(10)
  String orderId;

  @HiveField(11)
  Uint8List? signatureBytes;

  @HiveField(12)
  bool isGstEnabled;

  /// For mixed-rate invoices this can be 0. Use item-level GST rates instead.
  @HiveField(13)
  double gstPercent;

  @HiveField(14)
  String? buyerGstin;

  /// GST place of supply state code, for example Gujarat = 24.
  @HiveField(15)
  String? placeOfSupply;

  /// Legacy single-product HSN field. New invoices use item-level HSN.
  @HiveField(16)
  String? hsnCode;

  /// B2B / B2C.
  @HiveField(17)
  String invoiceType;

  @HiveField(18)
  double igst;

  @HiveField(19)
  double cgst;

  @HiveField(20)
  double sgst;

  /// Multi-product invoice lines saved as primitive maps so old Hive data remains safe.
  @HiveField(21)
  List<Map<String, dynamic>> lineItems;

  @HiveField(22)
  double discountAmount;

  @HiveField(23)
  String paymentMode;

  @HiveField(24)
  String? customerId;

  @HiveField(25)
  List<String> orderIds;

  InvoiceModel({
    required this.id,
    required this.saleId,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.orderId,
    this.paidAmount,
    this.dueAmount,
    this.signatureBytes,
    this.isGstEnabled = false,
    this.gstPercent = 0.0,
    this.buyerGstin,
    this.placeOfSupply,
    this.hsnCode,
    this.invoiceType = 'B2C',
    this.igst = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    List<Map<String, dynamic>>? lineItems,
    this.discountAmount = 0.0,
    this.paymentMode = 'Cash',
    this.customerId,
    List<String>? orderIds,
  })  : lineItems = lineItems ?? <Map<String, dynamic>>[],
        orderIds = orderIds ?? (orderId.isEmpty ? <String>[] : <String>[orderId]);

  bool get hasMultipleItems => items.length > 1;

  List<InvoiceLineItem> get items {
    if (lineItems.isNotEmpty) {
      return lineItems.map(InvoiceLineItem.fromMap).toList(growable: false);
    }
    return <InvoiceLineItem>[
      InvoiceLineItem(
        orderId: orderId,
        productId: saleId,
        productName: productName ?? 'Unknown Product',
        hsn: hsnCode ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        gstPercent: gstPercent,
      ),
    ];
  }

  String get safeProductName {
    final invoiceItems = items;
    if (invoiceItems.length == 1) return invoiceItems.first.productName;
    final names = invoiceItems.take(2).map((e) => e.productName).join(', ');
    final remaining = invoiceItems.length - 2;
    return remaining > 0 ? '$names + $remaining more' : names;
  }

  int get itemCount => items.length;

  double get paid => paidAmount ?? 0.0;

  double get subtotal {
    if (lineItems.isNotEmpty) {
      return items.fold<double>(0.0, (sum, item) => sum + item.taxableValue);
    }
    return amount;
  }

  double get totalQuantity => items.fold<double>(0.0, (sum, item) => sum + item.quantity);

  double get gstAmount {
    if (!isGstEnabled) return 0.0;
    if (lineItems.isNotEmpty) {
      return items.fold<double>(0.0, (sum, item) => sum + item.gstAmount);
    }
    return subtotal * gstPercent / 100;
  }

  double get grandTotal {
    final total = subtotal + gstAmount - discountAmount;
    return total < 0 ? 0.0 : total;
  }

  double get due {
    if (dueAmount != null) return dueAmount!;
    final calculated = grandTotal - paid;
    return calculated < 0 ? 0.0 : calculated;
  }

  void calculateTax(String companyStateCode) {
    if (!isGstEnabled || gstAmount <= 0) {
      igst = 0.0;
      cgst = 0.0;
      sgst = 0.0;
      invoiceType = buyerGstin != null && buyerGstin!.trim().isNotEmpty ? 'B2B' : 'B2C';
      return;
    }

    invoiceType = buyerGstin != null && buyerGstin!.trim().isNotEmpty ? 'B2B' : 'B2C';
    final totalTax = gstAmount;
    final pos = placeOfSupply?.trim();

    if (pos != null && pos.isNotEmpty && pos != companyStateCode.trim()) {
      igst = totalTax;
      cgst = 0.0;
      sgst = 0.0;
    } else {
      igst = 0.0;
      cgst = totalTax / 2;
      sgst = totalTax / 2;
    }
  }

  void updatePayment(double newPaidAmount) {
    paidAmount = newPaidAmount.clamp(0.0, grandTotal).toDouble();
    final newDue = grandTotal - paidAmount!;
    dueAmount = newDue < 0 ? 0.0 : newDue;
    save();
  }

  void updateGst({
    required bool enabled,
    required double percent,
    String? gstin,
    String? pos,
    String? hsn,
    required String companyStateCode,
  }) {
    isGstEnabled = enabled;
    gstPercent = percent;
    buyerGstin = gstin;
    placeOfSupply = pos;
    hsnCode = hsn;
    calculateTax(companyStateCode);
    save();
  }

  void updateSignature(Uint8List newSignature) {
    signatureBytes = newSignature;
    save();
  }

  void removeSignature() {
    signatureBytes = null;
    save();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'saleId': saleId,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'subtotal': subtotal,
        'gstAmount': gstAmount,
        'discountAmount': discountAmount,
        'grandTotal': grandTotal,
        'paidAmount': paid,
        'dueAmount': due,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'buyerGstin': buyerGstin,
        'placeOfSupply': placeOfSupply,
        'invoiceType': invoiceType,
        'igst': igst,
        'cgst': cgst,
        'sgst': sgst,
        'orderIds': orderIds,
        'lineItems': items.map((e) => e.toJson()).toList(),
      };
}

class InvoiceLineItem {
  final String orderId;
  final String productId;
  final String productName;
  final String hsn;
  final double quantity;
  final double unitPrice;
  final double gstPercent;

  const InvoiceLineItem({
    this.orderId = '',
    required this.productId,
    required this.productName,
    required this.hsn,
    required this.quantity,
    required this.unitPrice,
    required this.gstPercent,
  });

  factory InvoiceLineItem.fromMap(Map<dynamic, dynamic> map) {
    return InvoiceLineItem(
      orderId: map['orderId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'Unknown Product',
      hsn: map['hsn']?.toString() ?? '',
      quantity: _asDouble(map['quantity']),
      unitPrice: _asDouble(map['unitPrice']),
      gstPercent: _asDouble(map['gstPercent']),
    );
  }

  double get taxableValue => quantity * unitPrice;
  double get gstAmount => taxableValue * gstPercent / 100;
  double get lineTotal => taxableValue + gstAmount;

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'productId': productId,
        'productName': productName,
        'hsn': hsn,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'gstPercent': gstPercent,
        'taxableValue': taxableValue,
        'gstAmount': gstAmount,
        'lineTotal': lineTotal,
      };

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
