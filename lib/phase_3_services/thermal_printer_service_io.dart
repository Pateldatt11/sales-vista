import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';

class ThermalPrinterConfig {
  final String ipAddress;
  final int port;
  final int widthChars;
  final Duration timeout;

  const ThermalPrinterConfig({
    required this.ipAddress,
    this.port = 9100,
    this.widthChars = 48,
    this.timeout = const Duration(seconds: 4),
  });

  bool get isConfigured => ipAddress.trim().isNotEmpty;

  static Future<ThermalPrinterConfig> load() async {
    final box = Hive.isBoxOpen('settingsBox')
        ? Hive.box('settingsBox')
        : await Hive.openBox('settingsBox');

    return ThermalPrinterConfig(
      ipAddress: box.get('thermalPrinterIp', defaultValue: '').toString().trim(),
      port: int.tryParse(box.get('thermalPrinterPort', defaultValue: '9100').toString()) ?? 9100,
      widthChars: int.tryParse(box.get('thermalPrinterWidthChars', defaultValue: '48').toString()) ?? 48,
    );
  }

  Future<void> save() async {
    final box = Hive.isBoxOpen('settingsBox')
        ? Hive.box('settingsBox')
        : await Hive.openBox('settingsBox');
    await box.put('thermalPrinterIp', ipAddress.trim());
    await box.put('thermalPrinterPort', port.toString());
    await box.put('thermalPrinterWidthChars', widthChars.toString());
  }
}

class ThermalPrintResult {
  final bool success;
  final String message;

  const ThermalPrintResult({required this.success, required this.message});
}

class ThermalPrinterService {
  static const List<int> _init = [0x1B, 0x40];
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _normalSize = [0x1D, 0x21, 0x00];
  static const List<int> _doubleHeight = [0x1D, 0x21, 0x01];
  static const List<int> _feedAndCut = [0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x42, 0x00];

  static bool get isDirectPrintSupported => true;

  static Future<ThermalPrintResult> testConnection(ThermalPrinterConfig config) async {
    if (!config.isConfigured) {
      return const ThermalPrintResult(success: false, message: 'Printer IP is empty.');
    }

    try {
      final socket = await Socket.connect(
        config.ipAddress.trim(),
        config.port,
        timeout: config.timeout,
      );
      await socket.close();
      return ThermalPrintResult(
        success: true,
        message: 'Connected to ${config.ipAddress}:${config.port}',
      );
    } on TimeoutException {
      return ThermalPrintResult(
        success: false,
        message: 'Printer connection timed out. Check IP, Wi-Fi/LAN and port ${config.port}.',
      );
    } catch (e) {
      return ThermalPrintResult(
        success: false,
        message: 'Printer connection failed: ${e.toString()}',
      );
    }
  }

  static Future<ThermalPrintResult> printWalkInInvoice(
    InvoiceModel invoice, {
    required ThermalPrinterConfig config,
  }) async {
    if (!config.isConfigured) {
      return const ThermalPrintResult(success: false, message: 'Printer IP is empty.');
    }

    try {
      final socket = await Socket.connect(
        config.ipAddress.trim(),
        config.port,
        timeout: config.timeout,
      );

      final bytes = await _buildWalkInReceiptBytes(invoice, config.widthChars.clamp(32, 64).toInt());
      socket.add(bytes);
      await socket.flush();
      await socket.close();

      return ThermalPrintResult(
        success: true,
        message: 'Receipt sent to ${config.ipAddress}:${config.port}',
      );
    } on TimeoutException {
      return ThermalPrintResult(
        success: false,
        message: 'Printer timed out. Check thermal printer IP, Wi-Fi/LAN and port ${config.port}.',
      );
    } catch (e) {
      return ThermalPrintResult(
        success: false,
        message: 'Direct print failed: ${e.toString()}',
      );
    }
  }

  static Future<List<int>> _buildWalkInReceiptBytes(InvoiceModel invoice, int width) async {
    final out = <int>[];
    final company = await _companyInfo();
    final date = DateFormat('dd/MM/yyyy').format(invoice.date);
    final time = DateFormat('hh:mm a').format(invoice.date);
    final customer = invoice.customerName.trim().isEmpty ? 'Walk-in Customer' : invoice.customerName.trim();

    void cmd(List<int> values) => out.addAll(values);
    void line(String value) => out.addAll(_encode('$value\n'));
    void center(String value, {bool bold = false, bool doubleHeight = false}) {
      cmd(_alignCenter);
      if (bold) cmd(_boldOn);
      if (doubleHeight) cmd(_doubleHeight);
      for (final wrapped in _wrap(_safe(value), width)) {
        line(wrapped.padLeft(((width - wrapped.length) ~/ 2) + wrapped.length));
      }
      cmd(_normalSize);
      cmd(_boldOff);
      cmd(_alignLeft);
    }

    cmd(_init);
    cmd([0x1B, 0x74, 0x00]); // Default code page for widest ESC/POS compatibility.
    center(company.name.toUpperCase(), bold: true, doubleHeight: true);
    if (company.address.isNotEmpty) center(company.address);
    if (company.phone.isNotEmpty || company.email.isNotEmpty) {
      center([company.phone, company.email].where((e) => e.trim().isNotEmpty).join(' | '));
    }
    if (company.gstin.isNotEmpty) center('GSTIN: ${company.gstin}', bold: true);
    line(_rule(width));
    center(invoice.isGstEnabled ? 'TAX INVOICE / RETAIL RECEIPT' : 'RETAIL RECEIPT', bold: true);
    line(_rule(width));

    line(_pair('Bill No', invoice.id, width));
    line(_pair('Date', '$date  $time', width));
    line(_pair('Customer', customer, width));
    if (invoice.paymentMode.trim().isNotEmpty) {
      line(_pair('Payment', invoice.paymentMode.trim(), width));
    }
    if (company.stateCode.isNotEmpty) {
      line(_pair('State Code', company.stateCode, width));
    }
    line(_rule(width));

    line(_cols(['ITEM', 'QTY', 'RATE', 'AMOUNT'], [width - 25, 5, 8, 12], [false, true, true, true]));
    line(_rule(width));

    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final name = '${i + 1}. ${item.productName}';
      final nameLines = _wrap(_safe(name), width - 25);
      for (var lineIndex = 0; lineIndex < nameLines.length; lineIndex++) {
        if (lineIndex == 0) {
          line(_cols(
            [nameLines[lineIndex], _qtyText(item.quantity), item.unitPrice.toStringAsFixed(2), item.lineTotal.toStringAsFixed(2)],
            [width - 25, 5, 8, 12],
            [false, true, true, true],
          ));
        } else {
          line(nameLines[lineIndex]);
        }
      }
      final itemMeta = [
        if (item.hsn.trim().isNotEmpty) 'HSN ${item.hsn.trim()}',
        'GST ${item.gstPercent.toStringAsFixed(0)}%',
      ].join(' | ');
      line(_safe(itemMeta));
    }

    line(_rule(width));
    line(_amount('Total Qty', invoice.totalQuantity, width, decimals: 2));
    line(_amount('Taxable Value', invoice.subtotal, width));
    if (invoice.discountAmount > 0) line(_amount('Discount', -invoice.discountAmount, width));
    if (invoice.igst > 0) line(_amount('IGST', invoice.igst, width));
    if (invoice.cgst > 0) line(_amount('CGST', invoice.cgst, width));
    if (invoice.sgst > 0) line(_amount('SGST', invoice.sgst, width));
    if (invoice.gstAmount > 0 && invoice.igst == 0 && invoice.cgst == 0 && invoice.sgst == 0) {
      line(_amount('GST', invoice.gstAmount, width));
    }
    line(_rule(width));
    cmd(_boldOn);
    line(_amount('GRAND TOTAL', invoice.grandTotal, width));
    cmd(_boldOff);
    line(_amount('Paid', invoice.paid, width));
    line(_amount('Balance Due', invoice.due, width));

    if (invoice.gstAmount > 0) {
      line(_rule(width));
      line('GST SUMMARY');
      final byRate = <double, _TaxBucket>{};
      for (final item in invoice.items) {
        final bucket = byRate.putIfAbsent(item.gstPercent, () => _TaxBucket());
        bucket.taxable += item.taxableValue;
        bucket.tax += item.gstAmount;
      }
      line(_cols(['RATE', 'TAXABLE', 'TAX'], [8, width - 20, 12], [false, true, true]));
      for (final entry in byRate.entries) {
        line(_cols(
          ['${entry.key.toStringAsFixed(0)}%', entry.value.taxable.toStringAsFixed(2), entry.value.tax.toStringAsFixed(2)],
          [8, width - 20, 12],
          [false, true, true],
        ));
      }
    }

    line(_rule(width));
    center('Items sold: ${invoice.itemCount}');
    center('THANK YOU FOR SHOPPING WITH US', bold: true);
    center('Please retain this bill for exchange / warranty / accounting.');
    center('Powered by SalesVista POS');
    cmd(_feedAndCut);

    return out;
  }

  static Future<_EscPosCompanyInfo> _companyInfo() async {
    Box? companyBox;
    try {
      companyBox = Hive.isBoxOpen('companyBox') ? Hive.box('companyBox') : await Hive.openBox('companyBox');
    } catch (_) {
      companyBox = null;
    }

    Box? settingsBox;
    try {
      settingsBox = Hive.isBoxOpen('settingsBox') ? Hive.box('settingsBox') : await Hive.openBox('settingsBox');
    } catch (_) {
      settingsBox = null;
    }

    String read(Box? box, String key, String fallback) {
      try {
        return box?.get(key, defaultValue: fallback)?.toString().trim() ?? fallback;
      } catch (_) {
        return fallback;
      }
    }

    final gstin = read(companyBox, 'companyGst', read(settingsBox, 'companyGst', ''));
    return _EscPosCompanyInfo(
      name: read(companyBox, 'companyName', read(settingsBox, 'companyName', 'SalesVista')),
      address: read(companyBox, 'companyAddress', read(settingsBox, 'companyAddress', '')),
      phone: read(companyBox, 'companyPhone', read(settingsBox, 'companyPhone', '')),
      email: read(companyBox, 'companyEmail', read(settingsBox, 'companyEmail', '')),
      gstin: gstin,
      stateCode: _stateCodeFromGstin(gstin) ?? read(settingsBox, 'companyStateCode', '24'),
    );
  }

  static String? _stateCodeFromGstin(String gstin) {
    final clean = gstin.trim();
    if (clean.length >= 2 && RegExp(r'^\d{2}').hasMatch(clean)) {
      return clean.substring(0, 2);
    }
    return null;
  }

  static List<int> _encode(String value) {
    final sanitized = value
        .replaceAll('₹', 'Rs.')
        .replaceAll('•', '|')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
    return const Latin1Codec(allowInvalid: true).encode(sanitized);
  }

  static String _safe(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('₹', 'Rs.')
        .replaceAll('•', '|')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('×', 'x')
        .trim();
  }

  static List<String> _wrap(String value, int width) {
    final clean = _safe(value);
    if (clean.isEmpty) return [''];
    final words = clean.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (word.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        for (var i = 0; i < word.length; i += width) {
          lines.add(word.substring(i, (i + width).clamp(0, word.length).toInt()));
        }
      } else if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [''] : lines;
  }

  static String _rule(int width) => List.filled(width, '-').join();

  static String _pair(String left, String right, int width) {
    final l = _safe(left);
    final r = _safe(right);
    final space = width - l.length - r.length;
    if (space <= 1) return '${l}: $r';
    return '$l${List.filled(space, ' ').join()}$r';
  }

  static String _amount(String label, double amount, int width, {int decimals = 2}) {
    final value = decimals == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return _pair(label, value, width);
  }

  static String _cols(List<String> values, List<int> widths, List<bool> rightAlign) {
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      final width = widths[i];
      final value = _safe(values[i]);
      final clipped = value.length > width ? value.substring(0, width) : value;
      buffer.write(rightAlign[i] ? clipped.padLeft(width) : clipped.padRight(width));
    }
    return buffer.toString();
  }

  static String _qtyText(double quantity) {
    if (quantity == quantity.roundToDouble()) return quantity.toStringAsFixed(0);
    return quantity.toStringAsFixed(2);
  }
}

class _EscPosCompanyInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String gstin;
  final String stateCode;

  const _EscPosCompanyInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.stateCode,
  });
}

class _TaxBucket {
  double taxable = 0.0;
  double tax = 0.0;
}
