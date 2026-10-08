// import 'package:hive/hive.dart';
// import 'dart:typed_data';

// part 'invoice_model.g.dart';

// @HiveType(typeId: 6)
// class InvoiceModel extends HiveObject {

//   // ======================
//   // EXISTING FIELDS
//   // ======================

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

//   @HiveField(12)
//   bool isGstEnabled;

//   @HiveField(13)
//   double gstPercent;

//   // ======================
//   // 🔥 LEVEL 3 GST FIELDS
//   // ======================

//   @HiveField(14)
//   String? buyerGstin;

//   @HiveField(15)
//   String? placeOfSupply; // State code like "27"

//   @HiveField(16)
//   String? hsnCode;

//   @HiveField(17)
//   String invoiceType; // B2B / B2C

//   @HiveField(18)
//   double igst;

//   @HiveField(19)
//   double cgst;

//   @HiveField(20)
//   double sgst;

//   var taxRate;

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
//     this.isGstEnabled = false,
//     this.gstPercent = 0.0,

//     // New fields defaulted for old invoices
//     this.buyerGstin,
//     this.placeOfSupply,
//     this.hsnCode,
//     this.invoiceType = "B2C",
//     this.igst = 0.0,
//     this.cgst = 0.0,
//     this.sgst = 0.0,
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
//   // 🔥 GST SPLIT LOGIC
//   // ======================

//   void calculateTax(String companyStateCode) {

//     if (!isGstEnabled) {
//       igst = 0;
//       cgst = 0;
//       sgst = 0;
//       invoiceType = "B2C";
//       return;
//     }

//     final totalTax = gstAmount;

//     // B2B or B2C
//     if (buyerGstin != null && buyerGstin!.isNotEmpty) {
//       invoiceType = "B2B";
//     } else {
//       invoiceType = "B2C";
//     }

//     // Inter-state → IGST
//     if (placeOfSupply != null &&
//         placeOfSupply != companyStateCode) {

//       igst = totalTax;
//       cgst = 0;
//       sgst = 0;

//     } else {
//       // Intra-state → CGST + SGST
//       igst = 0;
//       cgst = totalTax / 2;
//       sgst = totalTax / 2;
//     }
//   }

//   // ======================
//   // PAYMENT UPDATE
//   // ======================

//   void updatePayment(double newPaidAmount) {
//     paidAmount = newPaidAmount;
//     final newDue = grandTotal - newPaidAmount;
//     dueAmount = newDue < 0 ? 0.0 : newDue;
//     save();
//   }

//   // ======================
//   // GST UPDATE
//   // ======================

//   void updateGst({
//     required bool enabled,
//     required double percent,
//     String? gstin,
//     String? pos,
//     String? hsn,
//     required String companyStateCode,
//   }) {
//     isGstEnabled = enabled;
//     gstPercent = percent;
//     buyerGstin = gstin;
//     placeOfSupply = pos;
//     hsnCode = hsn;

//     calculateTax(companyStateCode);

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

//   Object? toJson() {}
// }