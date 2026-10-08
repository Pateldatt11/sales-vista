// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 6;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceModel(
      id: fields[0] as String,
      saleId: fields[1] as String,
      customerName: fields[2] as String,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      productName: fields[7] as String?,
      quantity: fields[8] as double,
      unitPrice: fields[9] as double,
      orderId: fields[10] as String,
      paidAmount: fields[5] as double?,
      dueAmount: fields[6] as double?,
      signatureBytes: fields[11] as Uint8List?,
      isGstEnabled: fields[12] as bool,
      gstPercent: fields[13] as double,
      buyerGstin: fields[14] as String?,
      placeOfSupply: fields[15] as String?,
      hsnCode: fields[16] as String?,
      invoiceType: fields[17] as String,
      igst: fields[18] as double,
      cgst: fields[19] as double,
      sgst: fields[20] as double,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.saleId)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.paidAmount)
      ..writeByte(6)
      ..write(obj.dueAmount)
      ..writeByte(7)
      ..write(obj.productName)
      ..writeByte(8)
      ..write(obj.quantity)
      ..writeByte(9)
      ..write(obj.unitPrice)
      ..writeByte(10)
      ..write(obj.orderId)
      ..writeByte(11)
      ..write(obj.signatureBytes)
      ..writeByte(12)
      ..write(obj.isGstEnabled)
      ..writeByte(13)
      ..write(obj.gstPercent)
      ..writeByte(14)
      ..write(obj.buyerGstin)
      ..writeByte(15)
      ..write(obj.placeOfSupply)
      ..writeByte(16)
      ..write(obj.hsnCode)
      ..writeByte(17)
      ..write(obj.invoiceType)
      ..writeByte(18)
      ..write(obj.igst)
      ..writeByte(19)
      ..write(obj.cgst)
      ..writeByte(20)
      ..write(obj.sgst);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
