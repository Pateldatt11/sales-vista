// import 'package:hive/hive.dart';
// import 'dart:typed_data'; // <-- For storing signature bytes

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

//   // ======================
//   // NEW FIELD FOR SIGNATURE
//   // ======================
//   @HiveField(9)
//   Uint8List? signatureBytes; // Store captured signature

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
//     this.signatureBytes, // optional for backward compatibility
//   });

//   // ======================
//   // SAFE COMPUTED GETTERS
//   // ======================

//   double get paid => paidAmount ?? 0.0;

//   double get due {
//     if (dueAmount != null) return dueAmount!;
//     final calculated = totalAmount - paid;
//     return calculated < 0 ? 0.0 : calculated;
//   }

//   // ======================
//   // UPDATE METHODS
//   // ======================

//   void updatePayment(double newPaidAmount) {
//     paidAmount = newPaidAmount;
//     final newDue = totalAmount - newPaidAmount;
//     dueAmount = newDue < 0 ? 0.0 : newDue;
//     save();
//   }

//   void linkToSales(String salesIdValue) {
//     salesId = salesIdValue;
//     save();
//   }

//   // ======================
//   // SIGNATURE METHODS
//   // ======================

//   void updateSignature(Uint8List newSignature) {
//     signatureBytes = newSignature;
//     save(); // persist in Hive
//   }

//   void removeSignature() {
//     signatureBytes = null;
//     save();
//   }
// }