import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 2)
class TransactionModel extends HiveObject {

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  final String type; // "income" or "expense"

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String? orderId; // link to OrderModel

  // ✅ NEW FIELD
  @HiveField(6)
  final String? salesId; // link to SalesModel

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.orderId,
    this.salesId, // added
  });
}
