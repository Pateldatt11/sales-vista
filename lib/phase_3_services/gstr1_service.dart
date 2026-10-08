import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../phase_2_models/invoice_model.dart';

class Gstr1Service {
  static Future<void> exportMonthlyGstr1({
    required int month,
    required int year,
    required String companyStateCode,
  }) async {
    final invoiceBox = Hive.box<InvoiceModel>('invoice_box');

    // ==============================
    // FETCH CURRENT RECORDS PROPERLY
    // ==============================

    final invoices = invoiceBox.values
        .where((invoice) =>
            invoice.date.month == month &&
            invoice.date.year == year)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ignore: avoid_print
    print("Total invoices in Hive: ${invoiceBox.length}");
    // ignore: avoid_print
    print("Invoices for $month/$year: ${invoices.length}");

    // ==============================
    // ENSURE TAX IS UPDATED
    // ==============================

    for (final invoice in invoices) {
      invoice.calculateTax(companyStateCode);
    }

    List<List<dynamic>> rows = [];

    rows.add([
      "Section",
      "GSTIN",
      "Invoice No",
      "Invoice Date",
      "Invoice Value",
      "Place Of Supply",
      "Taxable Value",
      "IGST",
      "CGST",
      "SGST",
      "HSN"
    ]);

    // ==============================
    // B2B SECTION
    // ==============================

    final b2bInvoices =
        invoices.where((i) => i.invoiceType == "B2B").toList();

    for (final invoice in b2bInvoices) {
      rows.add(_buildRow("B2B", invoice));
    }

    // ==============================
    // B2C SECTION
    // ==============================

    final b2cInvoices =
        invoices.where((i) => i.invoiceType == "B2C").toList();

    for (final invoice in b2cInvoices) {
      final isLargeB2C =
          invoice.grandTotal > 250000 && invoice.igst > 0;

      rows.add(
          _buildRow(isLargeB2C ? "B2CL" : "B2CS", invoice));
    }

    // ==============================
    // HSN SUMMARY
    // ==============================

    final Map<String, _HsnSummary> hsnMap = {};

    for (final invoice in invoices) {
      final hsn = invoice.hsnCode ?? "NA";

      hsnMap.putIfAbsent(hsn, () => _HsnSummary());
      hsnMap[hsn]!.add(invoice);
    }

    for (final entry in hsnMap.entries) {
      rows.add([
        "HSN",
        "",
        "",
        "",
        "",
        "",
        entry.value.taxable.toStringAsFixed(2),
        entry.value.igst.toStringAsFixed(2),
        entry.value.cgst.toStringAsFixed(2),
        entry.value.sgst.toStringAsFixed(2),
        entry.key,
      ]);
    }

    // ==============================
    // CSV GENERATION
    // ==============================

    final csvData = const ListToCsvConverter().convert(rows);

    final fileName =
        "GSTR1_${year}_${month.toString().padLeft(2, '0')}.csv";

    if (kIsWeb) {
      // ==============================
      // WEB DOWNLOAD
      // ==============================

      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      // ignore: unused_local_variable
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(url);
    } else {
      // ==============================
      // MOBILE FILE SAVE
      // ==============================

      final directory =
          await getApplicationDocumentsDirectory();

      final path = "${directory.path}/$fileName";

      final file = File(path);
      await file.writeAsString(csvData);
    }
  }

  // ==============================
  // ROW BUILDER
  // ==============================

  static List<dynamic> _buildRow(
    String section,
    InvoiceModel invoice,
  ) {
    return [
      section,
      invoice.buyerGstin ?? "",
      invoice.id,
      invoice.date.toIso8601String().split('T')[0],
      invoice.grandTotal.toStringAsFixed(2),
      invoice.placeOfSupply ?? "",
      invoice.subtotal.toStringAsFixed(2),
      invoice.igst.toStringAsFixed(2),
      invoice.cgst.toStringAsFixed(2),
      invoice.sgst.toStringAsFixed(2),
      invoice.hsnCode ?? "",
    ];
  }
}

class _HsnSummary {
  double taxable = 0;
  double igst = 0;
  double cgst = 0;
  double sgst = 0;

  void add(InvoiceModel invoice) {
    taxable += invoice.subtotal;
    igst += invoice.igst;
    cgst += invoice.cgst;
    sgst += invoice.sgst;
  }
}