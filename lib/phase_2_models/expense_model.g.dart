// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseModelAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = 7;

  @override
  ExpenseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseModel(
      title: fields[0] as String? ?? '',
      amount: (fields[1] as num?)?.toDouble() ?? 0.0,
      date: fields[2] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
      category: fields[3] as String? ?? ExpenseModel.categoryOther,
      productId: fields[4] as String? ?? '',
      productName: fields[5] as String? ?? '',
      refillQuantity: (fields[6] as num?)?.toDouble() ?? 0.0,
      unit: fields[7] as String? ?? '',
      note: fields[8] as String? ?? '',
      batchNumber: fields[9] as String? ?? '',
      unitPurchasePrice: (fields[10] as num?)?.toDouble() ?? 0.0,
      posPriceUpdated: fields[11] as bool? ?? false,
      sellingPriceAfterRefill: (fields[12] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.productId)
      ..writeByte(5)
      ..write(obj.productName)
      ..writeByte(6)
      ..write(obj.refillQuantity)
      ..writeByte(7)
      ..write(obj.unit)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.batchNumber)
      ..writeByte(10)
      ..write(obj.unitPurchasePrice)
      ..writeByte(11)
      ..write(obj.posPriceUpdated)
      ..writeByte(12)
      ..write(obj.sellingPriceAfterRefill);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
