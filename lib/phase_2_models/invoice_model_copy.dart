// import 'package:hive/hive.dart';
// import 'dart:typed_data';

// part 'invoice_model.g.dart';

// @HiveType(typeId: 6)
// class InvoiceModel extends HiveObject {
//   @HiveField(0)
//   String id;

//   @HiveField(1)
//   String saleId;

//   @HiveField(2)
//   String customerName;

//   @HiveField(3)
//   double amount;

//   @HiveField(4)
//   DateTime date;

//   @HiveField(5)
//   double? paidAmount;

//   @HiveField(6)
//   double? dueAmount;

//   @HiveField(7)
//   String? productName;

//   @HiveField(8)
//   double quantity;

//   @HiveField(9)
//   double unitPrice;

//   @HiveField(10)
//   String orderId;

//   @HiveField(11)
//   Uint8List? signatureBytes;

//   // ======================
//   // ✅ NEW GST FIELDS
//   // ======================

//   @HiveField(12)
//   bool isGstEnabled;

//   @HiveField(13)
//   double gstPercent;

//   InvoiceModel({
//     required this.id,
//     required this.saleId,
//     required this.customerName,
//     required this.amount,
//     required this.date,
//     required this.productName,
//     required this.quantity,
//     required this.unitPrice,
//     required this.orderId,
//     this.paidAmount,
//     this.dueAmount,
//     this.signatureBytes,

//     // ✅ Defaults for old stored invoices
//     this.isGstEnabled = false,
//     this.gstPercent = 0.0,
//   });

//   // ======================
//   // SAFE COMPUTED GETTERS
//   // ======================

//   String get safeProductName => productName ?? 'Unknown Product';

//   double get paid => paidAmount ?? 0.0;

//   double get subtotal => amount;

//   double get gstAmount {
//     if (!isGstEnabled) return 0.0;
//     return subtotal * gstPercent / 100;
//   }

//   double get grandTotal => subtotal + gstAmount;

//   double get due {
//     if (dueAmount != null) return dueAmount!;
//     final calculated = grandTotal - paid;
//     return calculated < 0 ? 0.0 : calculated;
//   }

//   // ======================
//   // UPDATE METHODS
//   // ======================

//   void updatePayment(double newPaidAmount) {
//     paidAmount = newPaidAmount;
//     final newDue = grandTotal - newPaidAmount;
//     dueAmount = newDue < 0 ? 0.0 : newDue;
//     save();
//   }

//   // ======================
//   // GST UPDATE METHOD
//   // ======================

//   void updateGst({
//     required bool enabled,
//     required double percent,
//   }) {
//     isGstEnabled = enabled;
//     gstPercent = percent;
//     save();
//   }

//   // ======================
//   // SIGNATURE METHODS
//   // ======================

//   void updateSignature(Uint8List newSignature) {
//     signatureBytes = newSignature;
//     save();
//   }

//   void removeSignature() {
//     signatureBytes = null;
//     save();
//   }
// }