// import 'package:hive/hive.dart';
// import 'dart:typed_data';

// part 'order_model.g.dart';

// @HiveType(typeId: 5)
// class OrderModel extends HiveObject {

//   // ======================
//   // FIELDS
//   // ======================

//   @HiveField(0)
//   String id;

//   @HiveField(1)
//   String productName;

//   @HiveField(2)
//   double quantity;

//   @HiveField(3)
//   String customerName;

//   @HiveField(4)
//   double totalAmount;

//   @HiveField(5)
//   DateTime date;

//   @HiveField(6)
//   double? paidAmount;

//   @HiveField(7)
//   double? dueAmount;

//   @HiveField(8)
//   String? salesId;

//   @HiveField(9)
//   Uint8List? signatureBytes;

//   // ======================
//   // ✅ NEW GST FIELDS
//   // ======================

//   @HiveField(10)
//   bool isGstEnabled;

//   @HiveField(11)
//   double gstPercent;

//   // ======================
//   // CONSTRUCTOR
//   // ======================

//   OrderModel({
//     required this.id,
//     required this.productName,
//     required this.quantity,
//     required this.customerName,
//     required this.totalAmount,
//     required this.date,
//     this.paidAmount,
//     this.dueAmount,
//     this.salesId,
//     this.signatureBytes,

//     // ✅ GST defaults (important for old data)
//     this.isGstEnabled = false,
//     this.gstPercent = 0.0,
//   });

//   // ======================
//   // SAFE COMPUTED GETTERS
//   // ======================

//   double get paid => paidAmount ?? 0.0;

//   double get subtotal => totalAmount;

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

//   void linkToSales(String salesIdValue) {
//     salesId = salesIdValue;
//     save();
//   }

//   // ======================
//   // GST METHODS
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