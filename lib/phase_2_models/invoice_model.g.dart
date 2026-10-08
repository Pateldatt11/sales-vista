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

    List<Map<String, dynamic>> readLineItems(Object? raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    List<String> readOrderIds(Object? raw, String fallback) {
      if (raw is List) {
        return raw.map((item) => item.toString()).where((id) => id.isNotEmpty).toList();
      }
      return fallback.isEmpty ? <String>[] : <String>[fallback];
    }

    final orderId = fields[10]?.toString() ?? '';

    return InvoiceModel(
      id: fields[0]?.toString() ?? '',
      saleId: fields[1]?.toString() ?? '',
      customerName: fields[2]?.toString() ?? 'Walk-in Customer',
      amount: (fields[3] as num?)?.toDouble() ?? 0.0,
      date: fields[4] as DateTime? ?? DateTime.now(),
      productName: fields[7] as String?,
      quantity: (fields[8] as num?)?.toDouble() ?? 0.0,
      unitPrice: (fields[9] as num?)?.toDouble() ?? 0.0,
      orderId: orderId,
      paidAmount: (fields[5] as num?)?.toDouble(),
      dueAmount: (fields[6] as num?)?.toDouble(),
      signatureBytes: fields[11] as Uint8List?,
      isGstEnabled: fields[12] as bool? ?? false,
      gstPercent: (fields[13] as num?)?.toDouble() ?? 0.0,
      buyerGstin: fields[14] as String?,
      placeOfSupply: fields[15] as String?,
      hsnCode: fields[16] as String?,
      invoiceType: fields[17]?.toString() ?? 'B2C',
      igst: (fields[18] as num?)?.toDouble() ?? 0.0,
      cgst: (fields[19] as num?)?.toDouble() ?? 0.0,
      sgst: (fields[20] as num?)?.toDouble() ?? 0.0,
      lineItems: readLineItems(fields[21]),
      discountAmount: (fields[22] as num?)?.toDouble() ?? 0.0,
      paymentMode: fields[23]?.toString() ?? 'Cash',
      customerId: fields[24] as String?,
      orderIds: readOrderIds(fields[25], orderId),
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(26)
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
      ..write(obj.sgst)
      ..writeByte(21)
      ..write(obj.lineItems)
      ..writeByte(22)
      ..write(obj.discountAmount)
      ..writeByte(23)
      ..write(obj.paymentMode)
      ..writeByte(24)
      ..write(obj.customerId)
      ..writeByte(25)
      ..write(obj.orderIds);
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
