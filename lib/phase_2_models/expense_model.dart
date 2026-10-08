import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 7)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  ExpenseModel({
    required this.title,
    required this.amount,
    required this.date,
  });

  // Optional: Convert to readable map (useful for reports/export)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': date,
    };
  }

  // Optional: CopyWith (for future editing support)
  ExpenseModel copyWith({
    String? title,
    double? amount,
    DateTime? date,
  }) {
    return ExpenseModel(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}
