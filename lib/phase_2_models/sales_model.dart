import 'package:hive/hive.dart';

part 'sales_model.g.dart';

@HiveType(typeId: 0)
class SalesModel extends HiveObject {

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  // ✅ NEW: customer name
  @HiveField(4)
  final String customerName;

  // ✅ NEW: linked order IDs
  @HiveField(5)
  final List<String>? orderIds;

  // ✅ NEW: payment tracking
  @HiveField(6)
  final double? paidAmount;

  @HiveField(7)
  final double? dueAmount;

  // ✅ NEW: status tracking
  @HiveField(8)
  final String status; // completed | partial | pending | cancelled

  SalesModel({
    required this.id,
    required this.productName,
    required this.amount,
    required this.date,
    required this.customerName,
    this.orderIds,
    this.paidAmount,
    this.dueAmount,
    this.status = "completed",
  });

  // ==========================
  // SAFE GETTERS
  // ==========================

  double get paid => paidAmount ?? 0.0;

  double get due => dueAmount ?? (amount - paid);

  bool get isPaid => due <= 0;

  bool get isPartial => paid > 0 && due > 0;

  bool get isPending => paid == 0;
}
