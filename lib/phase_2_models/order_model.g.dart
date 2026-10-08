// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderModelAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 5;

  @override
  OrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderModel(
      id: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as double,
      customerName: fields[3] as String,
      totalAmount: fields[4] as double,
      date: fields[5] as DateTime,
      paidAmount: fields[6] as double?,
      dueAmount: fields[7] as double?,
      salesId: fields[8] as String?,
      signatureBytes: fields[9] as Uint8List?,
      isGstEnabled: fields[10] as bool,
      gstPercent: fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.paidAmount)
      ..writeByte(7)
      ..write(obj.dueAmount)
      ..writeByte(8)
      ..write(obj.salesId)
      ..writeByte(9)
      ..write(obj.signatureBytes)
      ..writeByte(10)
      ..write(obj.isGstEnabled)
      ..writeByte(11)
      ..write(obj.gstPercent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
