import 'dart:typed_data';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive/hive.dart';

import '../phase_2_models/order_model.dart';
import '../phase_2_models/invoice_model.dart';

class PdfService {
  /// ================= FONT LOADER WITH CACHE =================
  static pw.Font? _cachedFont;

  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final fontData =
        await rootBundle.load("assets/fonts/NotoSans-VariableFont_wdth,wght.ttf");
    _cachedFont = pw.Font.ttf(fontData);
    return _cachedFont!;
  }

  /// ================= PUBLIC METHODS =================

  static Future<void> generateOrderInvoicePdf(
    OrderModel order, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');

    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ??
        order.signatureBytes ??
        companyBox.get('signatureBytes') as Uint8List?;

    final pdf = await _buildPdfFromOrder(
      order,
      font,
      storedLogo,
      storedSignature,
    );

    await _saveOrPrintPdf(pdf, "invoice_${order.id}.pdf");
  }

  static Future<void> generateInvoiceModelPdf(
    InvoiceModel invoice, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');

    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ??
        invoice.signatureBytes ??
        companyBox.get('signatureBytes') as Uint8List?;

    final pdf = await _buildPdfFromInvoice(
      invoice,
      font,
      storedLogo,
      storedSignature,
    );

    await _saveOrPrintPdf(pdf, "invoice_${invoice.id}.pdf");
  }

  static Future<pw.Document> buildOrderPdfForPreview(
    OrderModel order, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');

    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ??
        order.signatureBytes ??
        companyBox.get('signatureBytes') as Uint8List?;

    return _buildPdfFromOrder(
      order,
      font,
      storedLogo,
      storedSignature,
    );
  }

  static Future<pw.Document> buildInvoicePdfForPreview(
    InvoiceModel invoice, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');

    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ??
        invoice.signatureBytes ??
        companyBox.get('signatureBytes') as Uint8List?;

    return _buildPdfFromInvoice(
      invoice,
      font,
      storedLogo,
      storedSignature,
    );
  }

  /// ================= PDF BUILDERS =================

  static Future<pw.Document> _buildPdfFromOrder(
    OrderModel order,
    pw.Font font,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  ) async {
    final quantity = order.quantity;
    final subtotal = order.totalAmount;
    final unitPrice = quantity != 0 ? subtotal / quantity : 0.0;

    // ignore: dead_null_aware_expression
    final bool isGstEnabled = order.isGstEnabled ?? false;
    // ignore: dead_null_aware_expression
    final double gstPercent = order.gstPercent ?? 0.0;
    final double gstAmount = isGstEnabled ? (subtotal * gstPercent / 100) : 0.0;
    final double finalTotal = subtotal + gstAmount;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(font, logoBytes),
          pw.SizedBox(height: 20),
          _billInfo(order.customerName, order.id, order.date, font),
          pw.SizedBox(height: 20),
          _productTable(
            productName: order.productName,
            unitPrice: unitPrice,
            quantity: quantity.toDouble(),
            subtotal: subtotal,
            font: font,
          ),
          pw.SizedBox(height: 20),
          _totalBox(
            subtotal,
            order.paid,
            order.due,
            finalTotal,
            font,
            isGstEnabled: isGstEnabled,
            gstPercent: gstPercent,
            gstAmount: gstAmount,
          ),
          pw.SizedBox(height: 40),
          _signature(font, signatureBytes),
        ],
      ),
    );

    return pdf;
  }

  static Future<pw.Document> _buildPdfFromInvoice(
    InvoiceModel invoice,
    pw.Font font,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  ) async {
    final quantity = invoice.quantity;
    final subtotal = invoice.amount;
    final unitPrice = quantity != 0 ? subtotal / quantity : 0.0;

    // ignore: dead_null_aware_expression
    final bool isGstEnabled = invoice.isGstEnabled ?? false;
    // ignore: dead_null_aware_expression
    final double gstPercent = invoice.gstPercent ?? 0.0;
    final double gstAmount = isGstEnabled ? (subtotal * gstPercent / 100) : 0.0;
    final double finalTotal = subtotal + gstAmount;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(font, logoBytes),
          pw.SizedBox(height: 20),
          _billInfo(invoice.customerName, invoice.id, invoice.date, font),
          pw.SizedBox(height: 20),
          _productTable(
            productName: invoice.safeProductName,
            unitPrice: unitPrice,
            quantity: quantity.toDouble(),
            subtotal: subtotal,
            font: font,
          ),
          pw.SizedBox(height: 20),
          _totalBox(
            subtotal,
            invoice.paid,
            invoice.due,
            finalTotal,
            font,
            isGstEnabled: isGstEnabled,
            gstPercent: gstPercent,
            gstAmount: gstAmount,
          ),
          pw.SizedBox(height: 40),
          _signature(font, signatureBytes),
        ],
      ),
    );

    return pdf;
  }

  /// ================= HEADER =================

  static pw.Widget _header(pw.Font font, Uint8List? logoBytes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          logoBytes != null
              ? pw.Image(pw.MemoryImage(logoBytes), height: 50)
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "SalesVista",
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "support@salesvista.com",
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      "www.salesvista.com",
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
          pw.Text(
            "INVOICE",
            style: pw.TextStyle(
              font: font,
              color: PdfColors.white,
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// ================= BILL INFO =================

  static pw.Widget _billInfo(
      String customerName, dynamic invoiceId, DateTime date, pw.Font font) {
    final companyBox = Hive.box('companyBox');
    final gstNumber = companyBox.get('companyGst', defaultValue: '');

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        /// Invoice To Section
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Invoice To:",
                style: pw.TextStyle(
                    font: font, fontWeight: pw.FontWeight.bold)),
            pw.Text(customerName, style: pw.TextStyle(font: font)),
          ],
        ),

        /// Invoice Details Section
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Invoice #: $invoiceId",
                style: pw.TextStyle(font: font)),
            pw.Text("Date: ${DateFormat.yMMMd().format(date)}",
                style: pw.TextStyle(font: font)),

            /// GST Number under invoice details
            if (gstNumber.isNotEmpty)
              pw.Text(
                "GST No: $gstNumber",
                style: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// ================= PRODUCT TABLE =================

  static pw.Widget _productTable({
    required String productName,
    required double unitPrice,
    required double quantity,
    required double subtotal,
    required pw.Font font,
  }) {
    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headers: ['SL', 'Description', 'Unit Price', 'Qty', 'Total'],
      data: [
        [
          '1',
          productName,
          unitPrice.toStringAsFixed(2),
          quantity.toStringAsFixed(2),
          subtotal.toStringAsFixed(2)
        ],
      ],
      headerStyle: pw.TextStyle(
          font: font,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: pw.TextStyle(font: font),
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
    );
  }

  /// ================= TOTAL BOX WITH GST =================

  static pw.Widget _totalBox(
    double subtotal,
    double paid,
    double due,
    double finalTotal,
    pw.Font font, {
    bool isGstEnabled = false,
    double gstPercent = 0.0,
    double gstAmount = 0.0,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration:
            pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _totalRow("Subtotal", subtotal.toStringAsFixed(2), font),
            if (isGstEnabled)
              _totalRow(
                "GST (${gstPercent.toStringAsFixed(0)}%)",
                gstAmount.toStringAsFixed(2),
                font,
              ),
            _totalRow("Paid", paid.toStringAsFixed(2), font),
            _totalRow("Due", due.toStringAsFixed(2), font),
            pw.Divider(),
            _totalRow(
              "Total",
              finalTotal.toStringAsFixed(2),
              font,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
      String title, String value, pw.Font font,
      {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                font: font,
                fontWeight:
                    isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text("₹$value",
            style: pw.TextStyle(
                font: font,
                fontWeight:
                    isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  /// ================= SIGNATURE =================

  static pw.Widget _signature(pw.Font font, Uint8List? signatureBytes) {
    const double lineWidth = 160;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          "Thank you for your business!",
          style: pw.TextStyle(font: font),
        ),
        pw.Container(
          width: lineWidth,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (signatureBytes != null)
                pw.Container(
                  width: lineWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Image(
                    pw.MemoryImage(signatureBytes),
                    height: 50,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              pw.SizedBox(height: 5),
              pw.Container(
                width: lineWidth,
                height: 1,
                color: PdfColors.grey,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                "Authorized Signature",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: font),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ================= SAVE / PRINT =================

  static Future<void> _saveOrPrintPdf(
      pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }
}