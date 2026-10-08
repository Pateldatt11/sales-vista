import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 7)
class ExpenseModel extends HiveObject {
  static const String categoryInventoryRefill = 'Inventory Refill';
  static const String categorySalary = 'Salary';
  static const String categoryOther = 'Other';

  @HiveField(0)
  final String title;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String productId;

  @HiveField(5)
  final String productName;

  @HiveField(6)
  final double refillQuantity;

  @HiveField(7)
  final String unit;

  @HiveField(8)
  final String note;

  @HiveField(9)
  final String batchNumber;

  /// Per-quantity purchase/refill price. For inventory refill entries,
  /// [amount] is calculated as [refillQuantity] * [unitPurchasePrice].
  @HiveField(10)
  final double unitPurchasePrice;

  /// True when the refill entry also changed the product selling price used in POS.
  @HiveField(11)
  final bool posPriceUpdated;

  /// Selling price saved to the product when [posPriceUpdated] is true.
  @HiveField(12)
  final double sellingPriceAfterRefill;

  ExpenseModel({
    required this.title,
    required this.amount,
    required this.date,
    this.category = categoryOther,
    this.productId = '',
    this.productName = '',
    this.refillQuantity = 0,
    this.unit = '',
    this.note = '',
    this.batchNumber = '',
    this.unitPurchasePrice = 0,
    this.posPriceUpdated = false,
    this.sellingPriceAfterRefill = 0,
  });

  bool get isInventoryRefill => category == categoryInventoryRefill;
  bool get isSalary => category == categorySalary;
  bool get isOther => category == categoryOther;

  String get safeCategory => category.trim().isEmpty ? categoryOther : category.trim();
  String get displayTitle => title.trim().isEmpty ? safeCategory : title.trim();
  String get productLabel => productName.trim().isEmpty ? '-' : productName.trim();
  String get refillLabel => refillQuantity <= 0 ? '-' : '${refillQuantity.toStringAsFixed(2)} ${unit.trim().isEmpty ? '' : unit.trim()}'.trim();
  String get safeBatchNumber => batchNumber.trim().isEmpty ? '-' : batchNumber.trim().toUpperCase();
  double get safeUnitPurchasePrice => unitPurchasePrice > 0
      ? unitPurchasePrice
      : (isInventoryRefill && refillQuantity > 0 ? amount / refillQuantity : 0);
  double get calculatedRefillTotal => isInventoryRefill ? refillQuantity * safeUnitPurchasePrice : amount;
  String get unitPurchasePriceLabel => safeUnitPurchasePrice <= 0 ? '-' : safeUnitPurchasePrice.toStringAsFixed(2);
  String get sellingPriceUpdateLabel => posPriceUpdated && sellingPriceAfterRefill > 0 ? sellingPriceAfterRefill.toStringAsFixed(2) : '-';

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': date,
      'category': safeCategory,
      'productId': productId,
      'productName': productName,
      'refillQuantity': refillQuantity,
      'unit': unit,
      'note': note,
      'batchNumber': batchNumber,
      'unitPurchasePrice': safeUnitPurchasePrice,
      'posPriceUpdated': posPriceUpdated,
      'sellingPriceAfterRefill': sellingPriceAfterRefill,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': safeCategory,
      'productId': productId,
      'productName': productName,
      'refillQuantity': refillQuantity,
      'unit': unit,
      'note': note,
      'batchNumber': batchNumber,
      'unitPurchasePrice': safeUnitPurchasePrice,
      'posPriceUpdated': posPriceUpdated,
      'sellingPriceAfterRefill': sellingPriceAfterRefill,
    };
  }

  ExpenseModel copyWith({
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? productId,
    String? productName,
    double? refillQuantity,
    String? unit,
    String? note,
    String? batchNumber,
    double? unitPurchasePrice,
    bool? posPriceUpdated,
    double? sellingPriceAfterRefill,
  }) {
    return ExpenseModel(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      refillQuantity: refillQuantity ?? this.refillQuantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      batchNumber: batchNumber ?? this.batchNumber,
      unitPurchasePrice: unitPurchasePrice ?? this.unitPurchasePrice,
      posPriceUpdated: posPriceUpdated ?? this.posPriceUpdated,
      sellingPriceAfterRefill: sellingPriceAfterRefill ?? this.sellingPriceAfterRefill,
    );
  }
}
